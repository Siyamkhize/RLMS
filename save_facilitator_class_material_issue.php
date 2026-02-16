<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

require_once 'connection.php';

// Enhanced logging for debugging
$debug_log = 'facilitator_class_material_debug.log';
$timestamp = date('Y-m-d H:i:s');
$input = file_get_contents('php://input');

// Log all incoming requests
file_put_contents($debug_log, "[$timestamp] CLASS MATERIAL REQUEST START\n", FILE_APPEND | LOCK_EX);
file_put_contents($debug_log, "Method: " . $_SERVER['REQUEST_METHOD'] . "\n", FILE_APPEND | LOCK_EX);
file_put_contents($debug_log, "Input: $input\n", FILE_APPEND | LOCK_EX);

try {
    // Get JSON input
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON data received');
    }
    
    // Validate required fields
    $required_fields = [
        'classID',
        'facilitatorFullName', 
        'representativeFullName',
        'description',
        'quantity',
        'qualificationName'
    ];
    
    foreach ($required_fields as $field) {
        if (!isset($data[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    // Sanitize and prepare data
    $classID = intval($data['classID']);
    $facilitator_full_name = mysqli_real_escape_string($conn, $data['facilitatorFullName']);
    $representative_full_name = mysqli_real_escape_string($conn, $data['representativeFullName']);
    $description = mysqli_real_escape_string($conn, $data['description']);
    $sub_description = isset($data['subDescription']) ? mysqli_real_escape_string($conn, $data['subDescription']) : null;
    $quantity = intval($data['quantity']);
    $qualification_name = mysqli_real_escape_string($conn, $data['qualificationName']);
    
    // For class-based issuance, signatures can be empty initially
    $facilitator_signature_base64 = isset($data['facilitatorSignature']) ? $data['facilitatorSignature'] : '';
    $representative_signature_base64 = isset($data['representativeSignature']) ? $data['representativeSignature'] : '';
    
    // Log processed data
    file_put_contents($debug_log, "[$timestamp] PROCESSED DATA:\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  classID: $classID\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  facilitator: $facilitator_full_name\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  representative: $representative_full_name\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  description: $description\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  sub_description: " . ($sub_description ?? 'NULL') . "\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  quantity: $quantity\n", FILE_APPEND | LOCK_EX);
    
    // Validate quantity
    if ($quantity <= 0) {
        throw new Exception('Quantity must be greater than 0');
    }
    
    // Handle signature images (only if provided)
    $facilitator_signature_path = '';
    $representative_signature_path = '';
    
    if (!empty($facilitator_signature_base64)) {
        $reports_folder = 'reports/';
        $facilitator_signature_name = $facilitator_full_name . '_class_signature';
        $facilitator_signature_path = saveSignatureImage($facilitator_signature_base64, $reports_folder, $facilitator_signature_name);
        if ($facilitator_signature_path === false) {
            throw new Exception('Failed to save facilitator signature');
        }
    }
    
    if (!empty($representative_signature_base64)) {
        $reports_folder = 'reports/';
        $representative_signature_name = $representative_full_name . '_class_signature';
        $representative_signature_path = saveSignatureImage($representative_signature_base64, $reports_folder, $representative_signature_name);
        if ($representative_signature_path === false) {
            throw new Exception('Failed to save representative signature');
        }
    }
    
    // Check for existing record for this class and material
    // For class-based issuance, we check by classID + facilitator + description
    if ($sub_description !== null) {
        $check_sql = "SELECT id, quantity, representative_full_name FROM facilitator_class_materials 
                      WHERE classID = ? AND facilitator_full_name = ? AND description = ? AND sub_description = ?
                      ORDER BY created_at DESC LIMIT 1";
        $check_stmt = $conn->prepare($check_sql);
        $check_stmt->bind_param("isss", $classID, $facilitator_full_name, $description, $sub_description);
    } else {
        $check_sql = "SELECT id, quantity, representative_full_name FROM facilitator_class_materials 
                      WHERE classID = ? AND facilitator_full_name = ? AND description = ? AND sub_description IS NULL
                      ORDER BY created_at DESC LIMIT 1";
        $check_stmt = $conn->prepare($check_sql);
        $check_stmt->bind_param("iss", $classID, $facilitator_full_name, $description);
    }
    
    $check_stmt->execute();
    $existing = $check_stmt->get_result()->fetch_assoc();
    
    if ($existing) {
        // Update existing record by adding to quantity (cumulative approach)
        $new_quantity = $existing['quantity'] + $quantity;
        
        // Combine representative names if different
        $existing_rep = $existing['representative_full_name'];
        $combined_representatives = $existing_rep;
        if ($existing_rep !== $representative_full_name && strpos($existing_rep, $representative_full_name) === false) {
            $combined_representatives = $existing_rep . ', ' . $representative_full_name;
        }
        
        file_put_contents($debug_log, "[$timestamp] UPDATING EXISTING CLASS RECORD:\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  existing_id: " . $existing['id'] . "\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  previous_quantity: " . $existing['quantity'] . "\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  adding_quantity: $quantity\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  new_total: $new_quantity\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  combined_representatives: $combined_representatives\n", FILE_APPEND | LOCK_EX);
        
        $update_sql = "UPDATE facilitator_class_materials 
                       SET quantity = ?, 
                           representative_full_name = ?,
                           qualification_name = ?,
                           facilitator_signature = COALESCE(NULLIF(?, ''), facilitator_signature),
                           representative_signature = COALESCE(NULLIF(?, ''), representative_signature),
                           updated_at = CURRENT_TIMESTAMP
                       WHERE id = ?";
        
        $update_stmt = $conn->prepare($update_sql);
        $update_stmt->bind_param("issssi", 
            $new_quantity,
            $combined_representatives,
            $qualification_name, 
            $facilitator_signature_path,
            $representative_signature_path,
            $existing['id']
        );
        
        if ($update_stmt->execute()) {
            error_log("Facilitator Class Material Success: Record updated with ID " . $existing['id']);
            file_put_contents($debug_log, "[$timestamp] UPDATE SUCCESS\n", FILE_APPEND | LOCK_EX);
            
            echo json_encode([
                'success' => true,
                'message' => "Class material issuance updated successfully. Total quantity for facilitator is now: $new_quantity",
                'action' => 'updated',
                'previous_quantity' => $existing['quantity'],
                'added_quantity' => $quantity,
                'total_quantity' => $new_quantity,
                'record_id' => $existing['id'],
                'description' => $description,
                'sub_description' => $sub_description,
                'facilitator' => $facilitator_full_name,
                'representatives' => $combined_representatives
            ]);
        } else {
            error_log("Facilitator Class Material Update Error: " . $conn->error);
            file_put_contents($debug_log, "[$timestamp] UPDATE FAILED: " . $conn->error . "\n", FILE_APPEND | LOCK_EX);
            throw new Exception('Failed to update class material issuance: ' . $conn->error);
        }
        
    } else {
        // Insert new record
        file_put_contents($debug_log, "[$timestamp] INSERTING NEW CLASS RECORD\n", FILE_APPEND | LOCK_EX);
        
        // Create table if it doesn't exist
        $create_table_sql = "CREATE TABLE IF NOT EXISTS facilitator_class_materials (
            id INT AUTO_INCREMENT PRIMARY KEY,
            classID INT NOT NULL,
            facilitator_full_name VARCHAR(255) NOT NULL,
            representative_full_name VARCHAR(255) NOT NULL,
            qualification_name VARCHAR(255),
            facilitator_signature TEXT,
            representative_signature TEXT,
            description VARCHAR(255) NOT NULL,
            sub_description VARCHAR(255),
            quantity INT NOT NULL DEFAULT 0,
            is_synced TINYINT(1) DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_class_facilitator (classID, facilitator_full_name),
            INDEX idx_description (description),
            INDEX idx_created_at (created_at)
        )";
        
        if (!$conn->query($create_table_sql)) {
            throw new Exception('Failed to create facilitator_class_materials table: ' . $conn->error);
        }
        
        $insert_sql = "INSERT INTO facilitator_class_materials 
                       (classID, facilitator_full_name, representative_full_name, 
                        qualification_name, facilitator_signature, representative_signature, 
                        description, sub_description, quantity, is_synced, created_at, updated_at) 
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)";
        
        $insert_stmt = $conn->prepare($insert_sql);
        $insert_stmt->bind_param("isssssssi", 
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
        
        if ($insert_stmt->execute()) {
            $record_id = $conn->insert_id;
            error_log("Facilitator Class Material Success: Record inserted with ID $record_id");
            file_put_contents($debug_log, "[$timestamp] INSERT SUCCESS: ID $record_id\n", FILE_APPEND | LOCK_EX);
            
            echo json_encode([
                'success' => true,
                'message' => 'Class material issuance submitted successfully for facilitator',
                'action' => 'created',
                'quantity' => $quantity,
                'record_id' => $record_id,
                'description' => $description,
                'sub_description' => $sub_description,
                'facilitator' => $facilitator_full_name
            ]);
        } else {
            error_log("Facilitator Class Material Insert Error: " . $conn->error);
            file_put_contents($debug_log, "[$timestamp] INSERT FAILED: " . $conn->error . "\n", FILE_APPEND | LOCK_EX);
            throw new Exception('Failed to insert class material issuance: ' . $conn->error);
        }
    }
    
} catch (Exception $e) {
    $error_msg = "Facilitator Class Material Error: " . $e->getMessage();
    error_log($error_msg);
    
    file_put_contents($debug_log, "[$timestamp] ERROR: " . $e->getMessage() . "\n", FILE_APPEND | LOCK_EX);
    
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
    $fileName = $prefix . '_' . time() . '.png';
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