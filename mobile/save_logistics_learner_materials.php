<?php
// Start output buffering to catch any stray output
ob_start();

// Log errors to file but don't display them
ini_set('log_errors', 1);
ini_set('error_log', dirname(__FILE__) . '/logistics_material_errors.log');
ini_set('display_errors', 0);
error_reporting(E_ALL);

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

// Enhanced logging for logistics
$debug_log = 'logistics_materials_debug.log';
$timestamp = date('Y-m-d H:i:s');
$input = file_get_contents('php://input');

file_put_contents($debug_log, "[$timestamp] LOGISTICS REQUEST START\n", FILE_APPEND | LOCK_EX);
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
    
    // Handle BOTH old and new data formats
    // OLD format: learnerID = "0307100332088" (ID number as string)
    // NEW format: learnerID = 70 (internal ID), IDNumber = "9807010472081"
    
    // Check which columns exist in material_receipt_form
    $columns = [];
    $res = $conn->query("SHOW COLUMNS FROM material_receipt_form");
    if ($res) {
        while($row = $res->fetch_assoc()) { $columns[] = $row['Field']; }
    }
    
    $has_sub_desc = in_array('sub_description', $columns);
    $has_rep_name = in_array('representative_name', $columns);
    $has_aor_date = in_array('date_aor_created', $columns);
    
    file_put_contents($debug_log, "[$timestamp] DEBUG: material_receipt_form cols: sub_desc=" . ($has_sub_desc?'Y':'N') . ", rep=" . ($has_rep_name?'Y':'N') . ", aor=" . ($has_aor_date?'Y':'N') . "\n", FILE_APPEND | LOCK_EX);

    $learner_id_value = isset($data['learnerID']) ? $data['learnerID'] : '';
    $id_number = isset($data['IDNumber']) ? $data['IDNumber'] : '';
    
    // Determine if learnerID is internal ID (numeric < 1000000) or ID number (string/large number)
    // USER REQUEST: STRICTLY USE internal LearnerID only.
    $internal_learner_id = 0;
    
    // 1. Try to use learnerID if it's a valid internal ID (typically small numeric)
    if (is_numeric($learner_id_value) && intval($learner_id_value) > 0 && intval($learner_id_value) < 1000000) {
        $internal_learner_id = intval($learner_id_value);
    } 
    // 2. If not a small numeric ID, or if we have an IDNumber, try to look up the internal ID
    if ($internal_learner_id <= 0) {
        $lookup_identifier = !empty($id_number) ? $id_number : $learner_id_value;
        
        if (!empty($lookup_identifier)) {
            $lookup_query = "SELECT LearnerID FROM learnerdetails WHERE IDNumber = ? OR CAST(LearnerID AS CHAR) = ? LIMIT 1";
            $lookup_stmt = $conn->prepare($lookup_query);
            if (!$lookup_stmt) {
                throw new Exception("Database prepare failed for ID lookup: " . $conn->error);
            }
            $lookup_stmt->bind_param('ss', $lookup_identifier, $lookup_identifier);
            $lookup_stmt->execute();
            $lookup_result = $lookup_stmt->get_result()->fetch_assoc();
            $lookup_stmt->close();
            
            if ($lookup_result && !empty($lookup_result['LearnerID'])) {
                $internal_learner_id = intval($lookup_result['LearnerID']);
            }
        }
    }
    
    if ($internal_learner_id <= 0) {
        throw new Exception("Learner not found with identifier: $learner_id_value / $id_number");
    }
    
    // Always use internal LearnerID as the primary identifier string for DB columns
    $student_id_number = strval($internal_learner_id);
    $learner_id_str = strval($internal_learner_id); 
    
    $learnerName = mysqli_real_escape_string($conn, $data['learnerName']);
    $selections = $data['selections']; // Array of usId => true/false
    $quantities = isset($data['quantities']) ? $data['quantities'] : []; // Array of usId => quantity
    
    // Validate and sanitize materialType
    $materialType = isset($data['materialType']) ? mysqli_real_escape_string($conn, $data['materialType']) : '';
    
    // If materialType is empty, 'Select', or invalid, default to 'Learning Material'
    if (empty($materialType) || $materialType === 'Select' || $materialType === '0') {
        $materialType = 'Learning Material';
    }
    
    $issuedBy = isset($data['issuedBy']) ? mysqli_real_escape_string($conn, $data['issuedBy']) : 'Logistics';
    
    // Get class name from classID
    $class_query = "SELECT className FROM class WHERE classID = ?";
    $class_stmt = $conn->prepare($class_query);
    if (!$class_stmt) {
        throw new Exception("Database prepare failed for class lookup: " . $conn->error);
    }
    $class_stmt->bind_param('i', $classID);
    $class_stmt->execute();
    $class_result = $class_stmt->get_result()->fetch_assoc();
    $className = $class_result ? $class_result['className'] : 'Unknown Class';
    $class_stmt->close();
    
    file_put_contents($debug_log, "[$timestamp] Learner ID resolution:\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp]   - Raw learnerID from request: " . json_encode($learner_id_value) . "\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp]   - Internal LearnerID: $internal_learner_id\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp]   - IDNumber: $id_number\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp]   - student_id_number for material_receipt_form: $student_id_number (learner_id_str: $learner_id_str)\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp] Processing materials for learner: $learnerName (Internal ID: $internal_learner_id, IDNumber: $id_number)\n", FILE_APPEND | LOCK_EX);
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
        // Support BOTH formats:
        // - Logistics: 13958_learner_guide, 13958_formative, 13958_summative
        // - Facilitator-style: 13958_LG, 13958_FORM, 13958_SUM
        $unit_standard_id = $usId;
        $item_type = 'Unit Standard';
        $sub_description = '';
        
        // Learner Guide (both formats)
        if (strpos($usId, '_LG') !== false || strpos($usId, '_learner_guide') !== false) {
            $unit_standard_id = str_replace(['_LG', '_learner_guide'], '', $usId);
            $item_type = 'Learner Guide';
            $sub_description = $unit_standard_id . ' - Learner Guide';
        }
        // Formative (both formats)
        elseif (strpos($usId, '_FORM') !== false || strpos($usId, '_formative') !== false) {
            $unit_standard_id = str_replace(['_FORM', '_formative'], '', $usId);
            $item_type = 'Formative';
            $sub_description = $unit_standard_id . ' - Formative';
        }
        // Summative (both formats)
        elseif (strpos($usId, '_SUM') !== false || strpos($usId, '_summative') !== false) {
            $unit_standard_id = str_replace(['_SUM', '_summative'], '', $usId);
            $item_type = 'Summative';
            $sub_description = $unit_standard_id . ' - Summative';
        }
        // Plain unit standard (no suffix)
        elseif (is_numeric($unit_standard_id)) {
            $item_type = 'Unit Standard';
            $sub_description = $unit_standard_id . ' - Unit Standard';
        }
        // Otherwise, it's a simple material type (Toolkit, PPE, Consumables, etc.)
        else {
            $sub_description = $materialType;
            $item_type = $materialType;
        }
        
        file_put_contents($debug_log, "[$timestamp] Processing: $sub_description (Qty: $quantity)\n", FILE_APPEND | LOCK_EX);

        // 1. Save to learner_issued_unit_standards (facilitator-style tracking)
        // Check if this US record exists to avoid duplicates in the US table
        if ($internal_learner_id > 0 && is_numeric($unit_standard_id)) {
            // Check which columns exist in learner_issued_unit_standards
            $us_columns = [];
            $us_res = $conn->query("SHOW COLUMNS FROM learner_issued_unit_standards");
            if ($us_res) {
                while($us_row = $us_res->fetch_assoc()) { $us_columns[] = $us_row['Field']; }
            }
            $has_us_material_type = in_array('material_type', $us_columns);
            $has_us_description = in_array('description', $us_columns);

            $internal_learner_id_str = strval($internal_learner_id);
            $id_number_str = strval($id_number);
            
            // Build dynamic check - STRICTLY USE INTERNAL ID
            $us_check_sql = "SELECT id, quantity FROM learner_issued_unit_standards 
                             WHERE CAST(learner_id AS CHAR) = ? 
                             AND unit_standard_id = ? ";
            $us_check_params = [$learner_id_str, $unit_standard_id];
            $us_check_types = 'ss';
            
            if ($has_us_description) {
                $us_check_sql .= " AND description = ? ";
                $us_check_params[] = $sub_description;
                $us_check_types .= 's';
            }
            if ($has_us_material_type) {
                $us_check_sql .= " AND material_type = ? ";
                $us_check_params[] = $materialType;
                $us_check_types .= 's';
            }
            
            $us_check_sql .= " LIMIT 1";
            
            $us_check_stmt = $conn->prepare($us_check_sql);
            if ($us_check_stmt) {
                $us_check_stmt->bind_param($us_check_types, ...$us_check_params);
                $us_check_stmt->execute();
                $us_existing = $us_check_stmt->get_result()->fetch_assoc();
                $us_check_stmt->close();
                
                if ($us_existing) {
                    $us_new_quantity = intval($us_existing['quantity']) + $quantity;
                    $us_update_sql = "UPDATE learner_issued_unit_standards
                                      SET learner_id = ?,
                                          quantity = ?,
                                          issued_by = ?,
                                          updated_at = CURRENT_TIMESTAMP
                                      WHERE id = ?";
                    $us_update_stmt = $conn->prepare($us_update_sql);
                    if ($us_update_stmt) {
                        $us_update_stmt->bind_param('iisi',
                            $internal_learner_id,
                            $us_new_quantity,
                            $issuedBy,
                            $us_existing['id']
                        );
                        $us_update_stmt->execute();
                        $us_update_stmt->close();
                        file_put_contents($debug_log, "[$timestamp] UPDATED learner_issued_unit_standards: $sub_description quantity to $us_new_quantity (ID: {$us_existing['id']})\n", FILE_APPEND | LOCK_EX);
                    }
                } else {
                    // Build dynamic insert for US table
                    $us_fields = ['learner_id', 'learner_name', 'classID', 'unit_standard_id', 'unit_standard_name', 'quantity', 'issued_by', 'is_synced', 'created_at', 'updated_at'];
                    $us_placeholders = ['?', '?', '?', '?', '?', '?', '?', '1', 'CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP'];
                    $us_types = 'isiisss'; // learner_id(i), learner_name(s), classID(i), unit_standard_id(i), unit_standard_name(s), quantity(i), issued_by(s) -> wait, quantity is int
                    $us_types = 'isiisis'; // i, s, i, i, s, i, s
                    $us_ins_params = [&$internal_learner_id, &$learnerName, &$classID, &$unit_standard_id, &$sub_description, &$quantity, &$issuedBy];
                    
                    if ($has_us_description) {
                        $us_fields[] = 'description';
                        $us_placeholders[] = '?';
                        $us_types .= 's';
                        $us_ins_params[] = &$sub_description;
                    }
                    if ($has_us_material_type) {
                        $us_fields[] = 'material_type';
                        $us_placeholders[] = '?';
                        $us_types .= 's';
                        $us_ins_params[] = &$materialType;
                    }
                    
                    $us_insert_sql = "INSERT INTO learner_issued_unit_standards (" . implode(', ', $us_fields) . ") 
                                      VALUES (" . implode(', ', $us_placeholders) . ")";
                    $us_insert_stmt = $conn->prepare($us_insert_sql);
                    if ($us_insert_stmt) {
                        call_user_func_array([$us_insert_stmt, 'bind_param'], array_merge([$us_types], $us_ins_params));
                        if ($us_insert_stmt->execute()) {
                            $us_inserted_id = $us_insert_stmt->insert_id;
                            file_put_contents($debug_log, "[$timestamp] INSERTED learner_issued_unit_standards: $sub_description (Qty: $quantity, ID: $us_inserted_id)\n", FILE_APPEND | LOCK_EX);
                        }
                        $us_insert_stmt->close();
                    }
                }
            }
        } elseif (is_numeric($unit_standard_id) && $internal_learner_id <= 0) {
            file_put_contents($debug_log, "[$timestamp] SKIPPED learner_issued_unit_standards upsert: No valid internal LearnerID\n", FILE_APPEND | LOCK_EX);
        }
        
        // Check if record exists - COMPREHENSIVE CHECK
        // USER REQUEST: STRICTLY USE learnerID only.
        if ($has_sub_desc) {
            $duplicate_check_sql = "SELECT id, quantity, student_id_number FROM material_receipt_form 
                                    WHERE (
                                        student_id_number = ? 
                                        OR (LOWER(TRIM(student_full_name)) = LOWER(TRIM(?)) AND class_name = ?)
                                    )
                                    AND description = ?
                                    AND sub_description = ?
                                    LIMIT 1";
            $dup_check_stmt = $conn->prepare($duplicate_check_sql);
            if (!$dup_check_stmt) {
                throw new Exception("Database prepare failed for duplicate check: " . $conn->error);
            }
            $dup_check_stmt->bind_param('sssss', 
                $learner_id_str,     // Internal LearnerID (e.g., "1277")
                $learnerName,        // Full name for matching
                $className,          // Class name for scoping
                $materialType,       // Material type
                $sub_description     // Sub description
            );
        } else {
            // Fallback: If sub_description column is missing
            $combined_desc = $materialType . ": " . $sub_description;
            $duplicate_check_sql = "SELECT id, quantity, student_id_number FROM material_receipt_form 
                                    WHERE (
                                        student_id_number = ? 
                                        OR (LOWER(TRIM(student_full_name)) = LOWER(TRIM(?)) AND class_name = ?)
                                    )
                                    AND (description = ? OR description = ?)
                                    LIMIT 1";
            $dup_check_stmt = $conn->prepare($duplicate_check_sql);
            if (!$dup_check_stmt) {
                throw new Exception("Database prepare failed for duplicate check: " . $conn->error);
            }
            $dup_check_stmt->bind_param('sssss', 
                $learner_id_str, 
                $learnerName, 
                $className, 
                $materialType,
                $combined_desc
            );
        }
        
        $dup_check_stmt->execute();
        $existing_record = $dup_check_stmt->get_result()->fetch_assoc();
        $dup_check_stmt->close();
        
        if ($existing_record) {
            // ADD to existing quantity (accumulative)
            $new_quantity = $existing_record['quantity'] + $quantity;
            
            // Also normalize the student_id_number to use internal LearnerID consistently
            if ($has_rep_name) {
                $update_sql = "UPDATE material_receipt_form 
                               SET student_id_number = ?,
                                   quantity = ?, 
                                   date_received = CURDATE(),
                                   representative_name = ?,
                                   synced = 0
                               WHERE id = ?";
                $update_stmt = $conn->prepare($update_sql);
                $update_stmt->bind_param('sisi', $student_id_number, $new_quantity, $issuedBy, $existing_record['id']);
            } else {
                $update_sql = "UPDATE material_receipt_form 
                               SET student_id_number = ?,
                                   quantity = ?, 
                                   date_received = CURDATE(),
                                   synced = 0
                               WHERE id = ?";
                $update_stmt = $conn->prepare($update_sql);
                $update_stmt->bind_param('sii', $student_id_number, $new_quantity, $existing_record['id']);
            }
            
            if (!$update_stmt) {
                throw new Exception("Database prepare failed for form update: " . $conn->error);
            }
            
            if ($update_stmt->execute()) {
                $inserted_count++;
                file_put_contents($debug_log, "[$timestamp] UPDATED: $sub_description quantity from {$existing_record['quantity']} to $new_quantity\n", FILE_APPEND | LOCK_EX);
            } else {
                throw new Exception("Failed to update: " . $conn->error);
            }
            $update_stmt->close();
        } else {
            // Insert matching the working pattern
            $received = 'Yes';
            
            // Build dynamic insert based on existing columns
            $insert_fields = ['student_id_number', 'student_full_name', 'class_name', 'received', 'quantity', 'description', 'date_received', 'practitioner_full_name', 'synced', 'created_at'];
            $insert_placeholders = ['?', '?', '?', '?', '?', '?', 'CURDATE()', '?', '0', 'CURRENT_TIMESTAMP'];
            $insert_types = 'ssssiss';
            
            // Determine final description
            if ($has_sub_desc) {
                $final_description = $materialType;
            } else {
                $final_description = $materialType . ": " . $sub_description;
            }
            
            // Params must match the order of placeholders in the query
            $insert_params = [
                &$student_id_number, 
                &$learnerName, 
                &$className, 
                &$received, 
                &$quantity, 
                &$final_description, 
                &$issuedBy
            ];
            
            // Add optional columns if they exist
            if ($has_sub_desc) {
                $insert_fields[] = 'sub_description';
                $insert_placeholders[] = '?';
                $insert_types .= 's';
                $insert_params[] = &$sub_description;
            }
            
            if ($has_rep_name) {
                $insert_fields[] = 'representative_name';
                $insert_placeholders[] = '?';
                $insert_types .= 's';
                $insert_params[] = &$issuedBy;
            }
            
            if ($has_aor_date) {
                $insert_fields[] = 'date_aor_created';
                $insert_placeholders[] = 'CURDATE()';
            }
            
            $insert_sql = "INSERT INTO material_receipt_form (" . implode(', ', $insert_fields) . ") 
                           VALUES (" . implode(', ', $insert_placeholders) . ")";
            
            $insert_stmt = $conn->prepare($insert_sql);
            if (!$insert_stmt) {
                throw new Exception("Database prepare failed for dynamic form insert: " . $conn->error);
            }
            
            // Bind parameters dynamically
            call_user_func_array([$insert_stmt, 'bind_param'], array_merge([$insert_types], $insert_params));
            
            if ($insert_stmt->execute()) {
                $inserted_id = $insert_stmt->insert_id;
                $inserted_count++;
                file_put_contents($debug_log, "[$timestamp] INSERTED to material_receipt_form: $sub_description (Qty: $quantity, ID: $inserted_id)\n", FILE_APPEND | LOCK_EX);
            } else {
                throw new Exception("Failed to insert: " . $conn->error);
            }
            
            $insert_stmt->close();
        }
    }
    
    // Commit transaction
    $conn->commit();
    
    $message = "Successfully issued $inserted_count item(s) to $learnerName by Logistics";
    
    file_put_contents($debug_log, "[$timestamp] SUCCESS: $message\n", FILE_APPEND | LOCK_EX);
    
    // Clear any stray output and send clean JSON
    ob_end_clean();
    echo json_encode([
        'success' => true,
        'message' => $message,
        'inserted_count' => $inserted_count
    ]);
    
} catch (Throwable $e) {
    // Rollback transaction on error
    if (isset($conn) && $conn->connect_errno == 0) {
        $conn->rollback();
    }
    
    $error_msg = "Error: " . $e->getMessage();
    error_log($error_msg);
    file_put_contents($debug_log, "[$timestamp] ERROR: " . $e->getMessage() . "\n", FILE_APPEND | LOCK_EX);
    
    // Clear any stray output and send clean JSON
    if (ob_get_length()) ob_end_clean();
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
