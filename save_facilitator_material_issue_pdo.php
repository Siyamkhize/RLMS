<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Database connection using PDO (since mysqli is not available)
$servername = "localhost";
$username = "rlmsrlmsco_ezxcmacd_rlms"; // Online database username
$password = "aV~4RP=_G{Uxm-Mp"; // Online database password  
$dbname = "rlmsrlmsco_ezxcmacd_rlms"; // Online database name

try {
    $dsn = "mysql:host=$servername;dbname=$dbname;charset=utf8";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false
    ]);
} catch (PDOException $e) {
    error_log("Database connection error: " . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Database connection failed']);
    exit;
}

// Enhanced logging for debugging
$debug_log = 'material_form_debug.log';
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
    
    // Validate required fields
    $required_fields = [
        'classID',
        'facilitatorFullName', 
        'representativeFullName',
        'description',
        'quantity',
        'qualificationName',
        'facilitatorSignature',
        'representativeSignature'
    ];
    
    foreach ($required_fields as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    // Sanitize and prepare data
    $classID = intval($data['classID']);
    $facilitator_full_name = $data['facilitatorFullName'];
    $representative_full_name = $data['representativeFullName'];
    $description = $data['description'];
    $sub_description = isset($data['subDescription']) ? $data['subDescription'] : null;
    $quantity = intval($data['quantity']);
    $qualification_name = $data['qualificationName'];
    $facilitator_signature_base64 = $data['facilitatorSignature'];
    $representative_signature_base64 = $data['representativeSignature'];
    
    // Log processed data
    file_put_contents($debug_log, "[$timestamp] PROCESSED DATA:\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  classID: $classID\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  description: $description\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  sub_description: " . ($sub_description ?? 'NULL') . "\n", FILE_APPEND | LOCK_EX);
    file_put_contents($debug_log, "  quantity: $quantity\n", FILE_APPEND | LOCK_EX);
    
    // Validate quantity
    if ($quantity <= 0) {
        throw new Exception('Quantity must be greater than 0');
    }
    
    // Save signature images
    $reports_folder = 'reports/';
    
    // Save facilitator signature
    $facilitator_signature_name = $facilitator_full_name . '_signature';
    $facilitator_signature_path = saveSignatureImage($facilitator_signature_base64, $reports_folder, $facilitator_signature_name);
    if ($facilitator_signature_path === false) {
        throw new Exception('Failed to save facilitator signature');
    }
    
    // Save representative signature  
    $representative_signature_name = $representative_full_name . '_signature';
    $representative_signature_path = saveSignatureImage($representative_signature_base64, $reports_folder, $representative_signature_name);
    if ($representative_signature_path === false) {
        throw new Exception('Failed to save representative signature');
    }
    
    // Check for existing record by classID + description + sub_description ONLY
    if ($sub_description !== null) {
        $check_sql = "SELECT id, quantity, representative_full_name FROM material_forms 
                      WHERE classID = ? AND description = ? AND sub_description = ?
                      ORDER BY created_at DESC LIMIT 1";
        $check_stmt = $pdo->prepare($check_sql);
        $check_stmt->execute([$classID, $description, $sub_description]);
    } else {
        $check_sql = "SELECT id, quantity, representative_full_name FROM material_forms 
                      WHERE classID = ? AND description = ? AND sub_description IS NULL
                      ORDER BY created_at DESC LIMIT 1";
        $check_stmt = $pdo->prepare($check_sql);
        $check_stmt->execute([$classID, $description]);
    }
    
    $existing = $check_stmt->fetch();
    
    if ($existing) {
        // Update existing record by adding to quantity (cumulative approach)
        $new_quantity = $existing['quantity'] + $quantity;
        
        // Combine representative names if different
        $existing_rep = $existing['representative_full_name'];
        $combined_representatives = $existing_rep;
        if ($existing_rep !== $representative_full_name && strpos($existing_rep, $representative_full_name) === false) {
            $combined_representatives = $existing_rep . ', ' . $representative_full_name;
        }
        
        file_put_contents($debug_log, "[$timestamp] UPDATING EXISTING RECORD:\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  existing_id: " . $existing['id'] . "\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  previous_quantity: " . $existing['quantity'] . "\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  adding_quantity: $quantity\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  new_total: $new_quantity\n", FILE_APPEND | LOCK_EX);
        file_put_contents($debug_log, "  combined_representatives: $combined_representatives\n", FILE_APPEND | LOCK_EX);
        
        $update_sql = "UPDATE material_forms 
                       SET quantity = ?, 
                           representative_full_name = ?,
                           facilitator_full_name = ?,
                           qualification_name = ?,
                           facilitator_signature = ?,
                           representative_signature = ?,
                           updated_at = CURRENT_TIMESTAMP
                       WHERE id = ?";
        
        $update_stmt = $pdo->prepare($update_sql);
        
        if ($update_stmt->execute([
            $new_quantity,
            $combined_representatives,
            $facilitator_full_name,
            $qualification_name, 
            $facilitator_signature_path,
            $representative_signature_path,
            $existing['id']
        ])) {
            error_log("Material Form Success: Record updated with ID " . $existing['id']);
            file_put_contents($debug_log, "[$timestamp] UPDATE SUCCESS\n", FILE_APPEND | LOCK_EX);
            
            echo json_encode([
                'success' => true,
                'message' => "Material form updated successfully. Total quantity is now: $new_quantity",
                'action' => 'updated',
                'previous_quantity' => $existing['quantity'],
                'added_quantity' => $quantity,
                'total_quantity' => $new_quantity,
                'record_id' => $existing['id'],
                'description' => $description,
                'sub_description' => $sub_description,
                'representatives' => $combined_representatives
            ]);
        } else {
            error_log("Material Form Update Error: " . implode(', ', $update_stmt->errorInfo()));
            file_put_contents($debug_log, "[$timestamp] UPDATE FAILED: " . implode(', ', $update_stmt->errorInfo()) . "\n", FILE_APPEND | LOCK_EX);
            throw new Exception('Failed to update material form: ' . implode(', ', $update_stmt->errorInfo()));
        }
        
    } else {
        // Insert new record
        file_put_contents($debug_log, "[$timestamp] INSERTING NEW RECORD\n", FILE_APPEND | LOCK_EX);
        
        $insert_sql = "INSERT INTO material_forms 
                       (classID, facilitator_full_name, representative_full_name, 
                        qualification_name, facilitator_signature, representative_signature, 
                        description, sub_description, quantity, is_synced, created_at, updated_at) 
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)";
        
        $insert_stmt = $pdo->prepare($insert_sql);
        
        if ($insert_stmt->execute([
            $classID,
            $facilitator_full_name,
            $representative_full_name,
            $qualification_name,
            $facilitator_signature_path,
            $representative_signature_path,
            $description,
            $sub_description,
            $quantity
        ])) {
            $record_id = $pdo->lastInsertId();
            error_log("Material Form Success: Record inserted with ID $record_id");
            file_put_contents($debug_log, "[$timestamp] INSERT SUCCESS: ID $record_id\n", FILE_APPEND | LOCK_EX);
            
            echo json_encode([
                'success' => true,
                'message' => 'Material form submitted successfully',
                'action' => 'created',
                'quantity' => $quantity,
                'record_id' => $record_id,
                'description' => $description,
                'sub_description' => $sub_description
            ]);
        } else {
            error_log("Material Form Insert Error: " . implode(', ', $insert_stmt->errorInfo()));
            file_put_contents($debug_log, "[$timestamp] INSERT FAILED: " . implode(', ', $insert_stmt->errorInfo()) . "\n", FILE_APPEND | LOCK_EX);
            throw new Exception('Failed to insert material form: ' . implode(', ', $insert_stmt->errorInfo()));
        }
    }
    
} catch (Exception $e) {
    $error_msg = "Material Form Error: " . $e->getMessage();
    error_log($error_msg);
    
    file_put_contents($debug_log, "[$timestamp] ERROR: " . $e->getMessage() . "\n", FILE_APPEND | LOCK_EX);
    
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

// Close connection
$pdo = null;

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