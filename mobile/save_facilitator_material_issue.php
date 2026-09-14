<?php
// Start output buffering to catch any stray output
ob_start();

// Log errors to file but don't display them (prevents HTML in JSON)
ini_set('log_errors', 1);
ini_set('error_log', dirname(__FILE__) . '/facilitator_material_errors.log');
ini_set('display_errors', 0);
error_reporting(E_ALL);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
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

// Enhanced logging for debugging
$debug_log = 'facilitator_material_debug.log';
$timestamp = date('Y-m-d H:i:s');
$input = file_get_contents('php://input');

// Log all incoming requests
file_put_contents($debug_log, "[$timestamp] REQUEST START\n", FILE_APPEND | LOCK_EX);
file_put_contents($debug_log, "Method: " . $_SERVER['REQUEST_METHOD'] . "\n", FILE_APPEND | LOCK_EX);
file_put_contents($debug_log, "Input: $input\n", FILE_APPEND | LOCK_EX);

try {
    // Get JSON input
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON data received');
    }
    
    // Check if this is batch issuance (new format with learner data)
    $is_batch_issuance = isset($data['issuance_records']);
    
    if ($is_batch_issuance) {
        // New format: batch issuance with learner IDs
        $issuance_records = $data['issuance_records'];
        
        if (empty($issuance_records)) {
            throw new Exception('No issuance records provided');
        }
        
        // Process each learner's materials
        foreach ($issuance_records as $record) {
            // Accept multiple field name variations for flexibility
            $id_number = isset($record['IDNumber']) ? mysqli_real_escape_string($conn, $record['IDNumber']) : 
                        (isset($record['id_number']) ? mysqli_real_escape_string($conn, $record['id_number']) : '');
            
            $learner_id = isset($record['LearnerID']) ? mysqli_real_escape_string($conn, $record['LearnerID']) : 
                         (isset($record['learner_id']) ? mysqli_real_escape_string($conn, $record['learner_id']) : '');
            
            // Priority: IDNumber > LearnerID > learner_id
            $student_id_number = !empty($id_number) ? $id_number : $learner_id;
            
            if (empty($student_id_number)) {
                file_put_contents($debug_log, "[$timestamp] WARNING: No student ID found for learner, skipping\n", FILE_APPEND | LOCK_EX);
                continue;
            }
            
            $learner_name = mysqli_real_escape_string($conn, $record['learner_name']);
            $classID = intval($record['classID']);
            $facilitator_name = mysqli_real_escape_string($conn, $record['facilitator_name']);
            $issued_by = mysqli_real_escape_string($conn, $record['issued_by']);
            $issue_type = mysqli_real_escape_string($conn, $record['issue_type']);
            $materials = $record['materials'];
            
            // Get class name
            $class_query = "SELECT className FROM class WHERE classID = ?";
            $class_stmt = $conn->prepare($class_query);
            $class_stmt->bind_param('i', $classID);
            $class_stmt->execute();
            $class_result = $class_stmt->get_result()->fetch_assoc();
            $className = $class_result ? $class_result['className'] : 'Unknown Class';
            $class_stmt->close();
            
            file_put_contents($debug_log, "[$timestamp] Processing learner: $learner_name\n", FILE_APPEND | LOCK_EX);
            file_put_contents($debug_log, "[$timestamp]   - IDNumber: $id_number\n", FILE_APPEND | LOCK_EX);
            file_put_contents($debug_log, "[$timestamp]   - LearnerID: $learner_id\n", FILE_APPEND | LOCK_EX);
            file_put_contents($debug_log, "[$timestamp]   - Using student_id_number: $student_id_number\n", FILE_APPEND | LOCK_EX);
            
            // Insert each material for this learner
            foreach ($materials as $material) {
                $material_name = mysqli_real_escape_string($conn, $material['material_name']);
                $quantity = intval($material['quantity_issued']);
                
                // Insert into material_receipt_form
                $insert_sql = "INSERT INTO material_receipt_form 
                               (student_id_number, student_full_name, class_name, received, quantity, 
                                description, sub_description, date_received, practitioner_full_name, 
                                representative_name, date_aor_created, synced, created_at)
                               VALUES (?, ?, ?, 'Yes', ?, ?, ?, CURDATE(), ?, ?, CURDATE(), 0, CURRENT_TIMESTAMP)";
                
                $stmt = $conn->prepare($insert_sql);
                $stmt->bind_param('ssssisss',
                    $student_id_number,    // student_id_number (IDNumber or LearnerID)
                    $learner_name,         // student_full_name
                    $className,            // class_name
                    $quantity,             // quantity
                    $issue_type,           // description
                    $material_name,        // sub_description
                    $facilitator_name,     // practitioner_full_name
                    $issued_by             // representative_name
                );
                
                if (!$stmt->execute()) {
                    throw new Exception("Failed to insert material for learner $learner_name: " . $conn->error);
                }
                
                file_put_contents($debug_log, "[$timestamp] INSERTED: $material_name (Qty: $quantity) for learner $learner_name (ID: $student_id_number)\n", FILE_APPEND | LOCK_EX);
                $stmt->close();
            }
        }
        
        // Clear any stray output and send clean JSON
        ob_end_clean();
        echo json_encode([
            'success' => true,
            'message' => 'Materials issued successfully to ' . count($issuance_records) . ' learner(s)',
            'learners_count' => count($issuance_records)
        ]);
        
        if (isset($conn)) {
            $conn->close();
        }
        exit;
    }
    
    // OLD FORMAT: Single class-level issuance (backward compatibility)
    // Validate required fields
    $required_fields = [
        'classID',
        'facilitatorFullName',
        'representativeFullName',
        'description',
        'subDescription',
        'quantity',
        'qualificationName',
        'facilitatorSignature'
    ];
    
    foreach ($required_fields as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    // Sanitize and prepare data
    $classID = intval($data['classID']);
    $facilitator_full_name = mysqli_real_escape_string($conn, $data['facilitatorFullName']);
    $representative_full_name = mysqli_real_escape_string($conn, $data['representativeFullName']);
    $description = mysqli_real_escape_string($conn, $data['description']);
    $sub_description = mysqli_real_escape_string($conn, $data['subDescription']);
    $quantity = intval($data['quantity']);
    $qualification_name = mysqli_real_escape_string($conn, $data['qualificationName']);
    $facilitator_signature_base64 = $data['facilitatorSignature'];
    
    // Representative signature is optional for facilitator submissions
    $representative_signature_base64 = isset($data['representativeSignature']) ? $data['representativeSignature'] : $facilitator_signature_base64;
    
    // Log processed data
    file_put_contents($debug_log, "[$timestamp] PROCESSED DATA:\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  classID: $classID\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  facilitator: $facilitator_full_name\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  representative: $representative_full_name\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  description: $description\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  sub_description: $sub_description\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  quantity: $quantity\n", FILE_APPEND | LOCK_EX);
    
    // Validate quantity
    if ($quantity <= 0) {
        throw new Exception('Quantity must be greater than 0');
    }
    
    // Save signature images
    $reports_folder = 'reports/';
    
    // Save facilitator signature
    $facilitator_signature_name = $facilitator_full_name . '_' . time() . '_signature';
    $facilitator_signature_path = saveSignatureImage($facilitator_signature_base64, $reports_folder, $facilitator_signature_name);
    
    if ($facilitator_signature_path === false) {
        throw new Exception('Failed to save facilitator signature');
    }
    
    // Save representative signature
    $representative_signature_name = $representative_full_name . '_' . time() . '_signature';
    $representative_signature_path = saveSignatureImage($representative_signature_base64, $reports_folder, $representative_signature_name);
    
    if ($representative_signature_path === false) {
        throw new Exception('Failed to save representative signature');
    }
    
    // Get class name from classID
    $class_query = "SELECT className FROM class WHERE classID = ?";
    $class_stmt = $conn->prepare($class_query);
    $class_stmt->bind_param('i', $classID);
    $class_stmt->execute();
    $class_result = $class_stmt->get_result()->fetch_assoc();
    $className = $class_result ? $class_result['className'] : 'Unknown Class';
    $class_stmt->close();
    
    file_put_contents($debug_log, "[$timestamp] Class Name: $className\n", FILE_APPEND | LOCK_EX);
    
    // Get class name from classID
    $class_query = "SELECT className FROM class WHERE classID = ?";
    $class_stmt = $conn->prepare($class_query);
    $class_stmt->bind_param('i', $classID);
    $class_stmt->execute();
    $class_result = $class_stmt->get_result()->fetch_assoc();
    $className = $class_result ? $class_result['className'] : 'Unknown Class';
    $class_stmt->close();
    
    file_put_contents($debug_log, "[$timestamp] Class Name: $className\n", FILE_APPEND | LOCK_EX);
    
    // Check if learner ID is provided (for learner-specific issuance)
    // Accept multiple field name variations: IDNumber, LearnerID, learnerID
    $id_number = isset($data['IDNumber']) ? mysqli_real_escape_string($conn, $data['IDNumber']) : '';
    $learner_id = isset($data['LearnerID']) ? mysqli_real_escape_string($conn, $data['LearnerID']) : 
                 (isset($data['learnerID']) ? mysqli_real_escape_string($conn, $data['learnerID']) : '');
    
    // Priority: IDNumber > LearnerID > learnerID > 'FACILITATOR'
    $student_id_number = !empty($id_number) ? $id_number : (!empty($learner_id) ? $learner_id : 'FACILITATOR');
    $learner_name = isset($data['learnerName']) ? mysqli_real_escape_string($conn, $data['learnerName']) : $facilitator_full_name;
    
    file_put_contents($debug_log, "[$timestamp] Student ID resolution:\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp]   - IDNumber: $id_number\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp]   - LearnerID: $learner_id\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp]   - Final student_id_number: $student_id_number\n", FILE_APPEND | LOCK_EX);
    
    // Check for existing record in material_forms table (for inventory tracking)
    $check_sql = "SELECT id, quantity FROM material_forms 
                  WHERE classID = ? AND description = ? AND sub_description = ?
                  ORDER BY created_at DESC LIMIT 1";
    $check_stmt = $conn->prepare($check_sql);
    $check_stmt->bind_param("iss", $classID, $description, $sub_description);
    $check_stmt->execute();
    $existing = $check_stmt->get_result()->fetch_assoc();
    
    if ($existing) {
        // Update existing record by adding to quantity
        $new_quantity = $existing['quantity'] + $quantity;
        
        file_put_contents($debug_log, "[$timestamp] UPDATING EXISTING RECORD IN material_forms:\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  existing_id: " . $existing['id'] . "\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  previous_quantity: " . $existing['quantity'] . "\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  adding_quantity: $quantity\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  new_total: $new_quantity\n", FILE_APPEND | LOCK_EX);
        
        $update_sql = "UPDATE material_forms 
                       SET quantity = ?,
                           facilitator_full_name = ?,
                           representative_full_name = ?,
                           qualification_name = ?,
                           facilitator_signature = ?,
                           representative_signature = ?,
                           updated_at = CURRENT_TIMESTAMP
                       WHERE id = ?";
        
        $update_stmt = $conn->prepare($update_sql);
        $update_stmt->bind_param("isssssi", 
            $new_quantity,
            $facilitator_full_name,
            $representative_full_name,
            $qualification_name,
            $facilitator_signature_path,
            $representative_signature_path,
            $existing['id']
        );
        
        if (!$update_stmt->execute()) {
            error_log("Material Form Update Error: " . $conn->error);
            file_put_contents($debug_log, "[$timestamp] UPDATE FAILED: " . $conn->error . "\n", FILE_APPEND | LOCK_EX);
            throw new Exception('Failed to update material form: ' . $conn->error);
        }
        
        error_log("Material Form Success: Record updated with ID " . $existing['id']);
        file_put_contents($debug_log, "[$timestamp] UPDATE SUCCESS in material_forms\n", FILE_APPEND | LOCK_EX);
        
    } else {
        // Insert new record into material_forms table (for inventory tracking)
        file_put_contents($debug_log, "[$timestamp] INSERTING NEW RECORD INTO material_forms\n", FILE_APPEND | LOCK_EX);
        
        // Generate unique form number
        $form_number = 'MF-' . $classID . '-' . time();
        
        $insert_sql = "INSERT INTO material_forms 
                       (form_number, classID, facilitator_full_name, representative_full_name,
                        qualification_name, facilitator_signature, representative_signature,
                        description, sub_description, quantity, is_synced, created_at, updated_at)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)";
        
        $insert_stmt = $conn->prepare($insert_sql);
        $insert_stmt->bind_param("sisssssssi", 
            $form_number,
            $classID,
            $facilitator_full_name,
            $representative_full_name,
            $qualification_name,
            $facilitator_signature_path,
            $representative_signature_path,
            $description,
            $sub_description,
            $quantity
        );
        
        if (!$insert_stmt->execute()) {
            error_log("Material Form Insert Error: " . $conn->error);
            file_put_contents($debug_log, "[$timestamp] INSERT FAILED: " . $conn->error . "\n", FILE_APPEND | LOCK_EX);
            throw new Exception('Failed to insert material form: ' . $conn->error);
        }
        
        $record_id = $conn->insert_id;
        error_log("Material Form Success: Record inserted with ID $record_id");
        file_put_contents($debug_log, "[$timestamp] INSERT SUCCESS in material_forms: ID $record_id\n", FILE_APPEND | LOCK_EX);
    }
    
    // ALSO insert into material_receipt_form table (same as Logistics)
    file_put_contents($debug_log, "[$timestamp] INSERTING INTO material_receipt_form (shared with Logistics)\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "[$timestamp] Using student_id_number: $student_id_number\n", FILE_APPEND | LOCK_EX);
    
    $receipt_insert_sql = "INSERT INTO material_receipt_form 
                           (student_id_number, student_full_name, class_name, received, quantity, 
                            description, sub_description, date_received, practitioner_full_name, 
                            representative_name, date_aor_created, synced, created_at)
                           VALUES (?, ?, ?, 'Yes', ?, ?, ?, CURDATE(), ?, ?, CURDATE(), 0, CURRENT_TIMESTAMP)";
    
    $receipt_stmt = $conn->prepare($receipt_insert_sql);
    $receipt_stmt->bind_param('sssissss', 
        $student_id_number,          // student_id_number (IDNumber, LearnerID, or 'FACILITATOR')
        $learner_name,               // student_full_name (Learner or Facilitator name)
        $className,                  // class_name
        $quantity,                   // quantity
        $description,                // description
        $sub_description,            // sub_description
        $qualification_name,         // practitioner_full_name
        $representative_full_name    // representative_name
    );
    
    if ($receipt_stmt->execute()) {
        $receipt_id = $conn->insert_id;
        file_put_contents($debug_log, "[$timestamp] INSERT SUCCESS in material_receipt_form: ID $receipt_id\n", FILE_APPEND | LOCK_EX);
        
        // Clear any stray output and send clean JSON
        ob_end_clean();
        echo json_encode([
            'success' => true,
            'message' => 'Material form submitted successfully to both tables',
            'action' => 'created',
            'quantity' => $quantity,
            'material_forms_id' => $existing ? $existing['id'] : $record_id,
            'material_receipt_form_id' => $receipt_id,
            'description' => $description,
            'sub_description' => $sub_description
        ]);
    } else {
        error_log("Material Receipt Form Insert Error: " . $conn->error);
        file_put_contents($debug_log, "[$timestamp] INSERT FAILED in material_receipt_form: " . $conn->error . "\n", FILE_APPEND | LOCK_EX);
        throw new Exception('Failed to insert into material_receipt_form: ' . $conn->error);
    }
    
} catch (Exception $e) {
    $error_msg = "Material Form Error: " . $e->getMessage();
    error_log($error_msg);
    
    file_put_contents($debug_log, "[$timestamp] ERROR: " . $e->getMessage() . "\n", FILE_APPEND | LOCK_EX);
    
    // Clear any stray output and send clean JSON
    ob_end_clean();
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

// Close connection
if (isset($conn)) {
    $conn->close();
}

// Function to save the base64 signature to a file
function saveSignatureImage($base64Data, $directory, $prefix) {
    // Decode the Base64 string
    $data = base64_decode($base64Data);
    if ($data === false) {
        return false;
    }
    
    // Generate a unique file name for the image
    $fileName = $prefix . '.png';
    $filePath = $directory . $fileName;
    
    // Make sure the directory exists
    if (!is_dir($directory)) {
        mkdir($directory, 0777, true);
    }
    
    // Save the image data to a file
    if (file_put_contents($filePath, $data)) {
        return $filePath;
    }
    
    return false;
}
?>
