<?php
// Start output buffering to catch any stray output
ob_start();

// Log errors to file but don't display them (prevents HTML in JSON)
ini_set('log_errors', 1);
ini_set('error_log', dirname(__FILE__) . '/material_save_errors.log');
ini_set('display_errors', 0);
error_reporting(E_ALL);

// Set headers before any output
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    ob_end_clean();
    exit(0);
}

try {
    require_once 'connection.php';
} catch (Exception $e) {
    ob_end_clean();
    echo json_encode([
        'success' => false,
        'error' => 'Database connection failed'
    ]);
    exit;
}

// Enhanced logging
$debug_log = 'learner_materials_debug.log';
$timestamp = date('Y-m-d H:i:s');
$input = file_get_contents('php://input');

file_put_contents($debug_log, "[$timestamp] REQUEST START\n", FILE_APPEND | LOCK_EX);
file_put_contents($debug_log, "Input: $input\n", FILE_APPEND | LOCK_EX);

try {
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON data received');
    }
    
    // Validate required fields
    if (!isset($data['classID']) || !isset($data['learnerName'])) {
        throw new Exception('Missing required fields: classID or learnerName');
    }
    
    // Check if at least one learner ID field is provided
    $has_id_number = isset($data['IDNumber']) && !empty($data['IDNumber']);
    $has_learner_id = isset($data['LearnerID']) && !empty($data['LearnerID']) || 
                      isset($data['learnerID']) && !empty($data['learnerID']);
    
    if (!$has_id_number && !$has_learner_id) {
        throw new Exception('Learner ID is required (provide IDNumber or LearnerID)');
    }
    
    if (!isset($data['selections']) || !is_array($data['selections'])) {
        throw new Exception('No selections provided');
    }
    
    // Sanitize data
    $classID = intval($data['classID']);
    
    // Get both LearnerID (internal) and IDNumber (actual ID)
    $internal_learner_id = isset($data['learnerID']) ? intval($data['learnerID']) : 0;
    $id_number = isset($data['IDNumber']) ? mysqli_real_escape_string($conn, $data['IDNumber']) : '';
    
    // Validate we have the internal LearnerID
    if (empty($internal_learner_id) || $internal_learner_id <= 0) {
        throw new Exception('Internal LearnerID is required');
    }
    
    // If IDNumber not provided, look it up from learnerdetails
    if (empty($id_number)) {
        $lookup_query = "SELECT IDNumber FROM learnerdetails WHERE LearnerID = ?";
        $lookup_stmt = $conn->prepare($lookup_query);
        $lookup_stmt->bind_param('i', $internal_learner_id);
        $lookup_stmt->execute();
        $lookup_result = $lookup_stmt->get_result()->fetch_assoc();
        $lookup_stmt->close();
        
        if ($lookup_result && !empty($lookup_result['IDNumber'])) {
            $id_number = $lookup_result['IDNumber'];
        } else {
            throw new Exception("Learner not found with LearnerID: $internal_learner_id");
        }
    }
    
    $student_id_number = $id_number; // For material_receipt_form table
    
    $learnerName = mysqli_real_escape_string($conn, $data['learnerName']);
    $selections = $data['selections']; // Array of usId => true/false
    $quantities = isset($data['quantities']) ? $data['quantities'] : []; // Array of usId => quantity
    
    // Validate and sanitize materialType
    $materialType = isset($data['materialType']) ? mysqli_real_escape_string($conn, $data['materialType']) : '';
    
    // If materialType is empty, 'Select', or invalid, default to 'Learning Material'
    if (empty($materialType) || $materialType === 'Select' || $materialType === '0') {
        $materialType = 'Learning Material';
    }
    
    $issuedBy = isset($data['issuedBy']) ? mysqli_real_escape_string($conn, $data['issuedBy']) : 'Facilitator';
    
    // Get class name from classID
    $class_query = "SELECT className FROM class WHERE classID = ?";
    $class_stmt = $conn->prepare($class_query);
    $class_stmt->bind_param('i', $classID);
    $class_stmt->execute();
    $class_result = $class_stmt->get_result()->fetch_assoc();
    $className = $class_result ? $class_result['className'] : 'Unknown Class';
    $class_stmt->close();
    
    file_put_contents($debug_log, "[$timestamp] Learner ID resolution:\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp]   - Internal LearnerID: $internal_learner_id\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp]   - IDNumber (looked up): $id_number\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp]   - student_id_number for material_receipt_form: $student_id_number\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp] Processing materials for learner: $learnerName (ID: $internal_learner_id)\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp] Class: $className (ID: $classID)\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp] Material Type: $materialType, Issued By: $issuedBy\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp] Selections: " . json_encode($selections) . "\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp] Quantities: " . json_encode($quantities) . "\n", FILE_APPEND | LOCK_EX);
    
    $inserted_count = 0;
    
    // Begin transaction
    $conn->begin_transaction();
    
    foreach ($selections as $usId => $isSelected) {
        if (!$isSelected) {
            continue; // Skip unselected items
        }
        
        // Get quantity for this item (default to 1)
        $quantity = isset($quantities[$usId]) ? intval($quantities[$usId]) : 1;
        
        // ⚠️ VALIDATION: Skip if quantity is 0 or negative
        if ($quantity <= 0) {
            file_put_contents($debug_log, "[$timestamp] SKIPPED: $usId (quantity is $quantity)\n", FILE_APPEND | LOCK_EX);
            continue;
        }
        
        // Parse the usId to determine item type
        // Facilitator format: 13958_LG, 13958_FORM, 13958_SUM
        // Logistics format: 13958_learner_guide, 13958_formative, 13958_summative
        $unit_standard_id = $usId;
        $item_type = 'Unit Standard';
        $sub_description = '';
        
        // Check for Learner Guide (both formats)
        if (strpos($usId, '_LG') !== false || strpos($usId, '_learner_guide') !== false) {
            $unit_standard_id = str_replace(['_LG', '_learner_guide'], '', $usId);
            $item_type = 'Learner Guide';
            $sub_description = $unit_standard_id . ' - Learner Guide';
        } 
        // Check for Formative (both formats)
        elseif (strpos($usId, '_FORM') !== false || strpos($usId, '_formative') !== false) {
            $unit_standard_id = str_replace(['_FORM', '_formative'], '', $usId);
            $item_type = 'Formative';
            $sub_description = $unit_standard_id . ' - Formative';
        } 
        // Check for Summative (both formats)
        elseif (strpos($usId, '_SUM') !== false || strpos($usId, '_summative') !== false) {
            $unit_standard_id = str_replace(['_SUM', '_summative'], '', $usId);
            $item_type = 'Summative';
            $sub_description = $unit_standard_id . ' - Summative';
        }
        // Check if this is a plain unit standard (no suffix)
        elseif (is_numeric($unit_standard_id)) {
            $item_type = 'Unit Standard';
            $sub_description = $unit_standard_id . ' - Unit Standard';
        }
        // Otherwise, it's a simple material type (ToolKit, PPE, Consumables)
        else {
            $sub_description = $materialType;
            $item_type = $materialType;
        }
        
        file_put_contents($debug_log, "[$timestamp] Processing: $sub_description (Qty: $quantity)\n", FILE_APPEND | LOCK_EX);
        
        // Check if record exists with same description and sub_description
        $duplicate_check_sql = "SELECT id, quantity FROM material_receipt_form 
                                WHERE student_id_number = ? 
                                AND description = ?
                                AND sub_description = ?";
        $dup_check_stmt = $conn->prepare($duplicate_check_sql);
        $dup_check_stmt->bind_param('sss', $student_id_number, $materialType, $sub_description);
        $dup_check_stmt->execute();
        $existing_record = $dup_check_stmt->get_result()->fetch_assoc();
        $dup_check_stmt->close();
        
        if ($existing_record) {
            // ADD to existing quantity (accumulative)
            $new_quantity = $existing_record['quantity'] + $quantity;
            $update_sql = "UPDATE material_receipt_form 
                           SET quantity = ?, 
                               date_received = CURDATE(),
                               representative_name = ?,
                               synced = 0
                           WHERE id = ?";
            $update_stmt = $conn->prepare($update_sql);
            $update_stmt->bind_param('isi', $new_quantity, $issuedBy, $existing_record['id']);
            
            if ($update_stmt->execute()) {
                $inserted_count++;
                file_put_contents($debug_log, "[$timestamp] UPDATED: $sub_description quantity from {$existing_record['quantity']} to $new_quantity\n", FILE_APPEND | LOCK_EX);
            } else {
                throw new Exception("Failed to update: " . $conn->error);
            }
            $update_stmt->close();
        } else {
            // Insert matching the working pattern from save_learner_issued_unit_standards.php
            $received = 'Yes'; // Must be a variable for PHP 8+ bind_param
            $insert_sql = "INSERT INTO material_receipt_form 
                           (student_id_number, student_full_name, class_name, received, quantity, 
                            description, sub_description, date_received, practitioner_full_name, 
                            representative_name, date_aor_created, synced, created_at)
                           VALUES (?, ?, ?, ?, ?, ?, ?, CURDATE(), ?, ?, CURDATE(), 0, CURRENT_TIMESTAMP)";
            
            $insert_stmt = $conn->prepare($insert_sql);
            $insert_stmt->bind_param('ssssissss',
                $student_id_number,      // student_id_number (ID number like "0307100332088")
                $learnerName,            // student_full_name
                $className,              // class_name
                $received,               // received ('Yes')
                $quantity,               // quantity
                $materialType,           // description (Material Type: ToolKit, Learning Material, etc.)
                $sub_description,        // sub_description (Unit Standard details: "13958 - Learner Guide")
                $issuedBy,               // practitioner_full_name (Facilitator name)
                $issuedBy                // representative_name (Facilitator name)
            );
            
            if ($insert_stmt->execute()) {
                $inserted_id = $insert_stmt->insert_id;
                $inserted_count++;
                file_put_contents($debug_log, "[$timestamp] INSERTED to material_receipt_form: $sub_description (Qty: $quantity, ID: $inserted_id)\n", FILE_APPEND | LOCK_EX);
                
                // ALSO insert to learner_issued_unit_standards table (for tracking)
                // Only if this is a unit standard (has numeric unit_standard_id)
                if (is_numeric($unit_standard_id)) {
                    $us_insert_sql = "INSERT INTO learner_issued_unit_standards 
                                      (learner_id, learner_name, classID, unit_standard_id, unit_standard_name, 
                                       description, quantity, material_type, issued_by, is_synced, created_at, updated_at)
                                      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)";
                    
                    $us_insert_stmt = $conn->prepare($us_insert_sql);
                    $us_insert_stmt->bind_param('isiississ',
                        $internal_learner_id,  // learner_id (internal LearnerID like 70) - i
                        $learnerName,          // learner_name - s
                        $classID,              // classID - i
                        $unit_standard_id,     // unit_standard_id (e.g., 13958) - i
                        $sub_description,      // unit_standard_name (e.g., "13958 - Learner Guide") - s
                        $materialType,         // description - s
                        $quantity,             // quantity - i
                        $item_type,            // material_type (e.g., "Learner Guide") - s
                        $issuedBy              // issued_by - s
                    );
                    
                    if ($us_insert_stmt->execute()) {
                        $us_inserted_id = $us_insert_stmt->insert_id;
                        file_put_contents($debug_log, "[$timestamp] ALSO INSERTED to learner_issued_unit_standards: $sub_description (ID: $us_inserted_id)\n", FILE_APPEND | LOCK_EX);
                    } else {
                        file_put_contents($debug_log, "[$timestamp] WARNING: Failed to insert to learner_issued_unit_standards: " . $conn->error . "\n", FILE_APPEND | LOCK_EX);
                    }
                    
                    $us_insert_stmt->close();
                }
            } else {
                throw new Exception("Failed to insert: " . $conn->error);
            }
            
            $insert_stmt->close();
        }
    }
    
    // Commit transaction
    $conn->commit();
    
    $message = "Successfully issued $inserted_count item(s) to $learnerName";
    
    file_put_contents($debug_log, "[$timestamp] SUCCESS: $message\n", FILE_APPEND | LOCK_EX);
    
    // Clear any stray output and send clean JSON
    ob_end_clean();
    echo json_encode([
        'success' => true,
        'message' => $message,
        'inserted_count' => $inserted_count
    ]);
    
} catch (Exception $e) {
    // Rollback transaction on error
    if (isset($conn)) {
        $conn->rollback();
    }
    
    $error_msg = "Error: " . $e->getMessage();
    error_log($error_msg);
    file_put_contents($debug_log, "[$timestamp] ERROR: " . $e->getMessage() . "\n", FILE_APPEND | LOCK_EX);
    
    // Clear any stray output and send clean JSON
    ob_end_clean();
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

// Close connection
if (isset($conn)) {
    $conn->close();
}
?>
