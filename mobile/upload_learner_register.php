<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

// Get POST data
$learner_id = isset($_POST['learner_id']) ? $_POST['learner_id'] : '';
$class_id = isset($_POST['class_id']) ? $_POST['class_id'] : '';
$finance_id = isset($_POST['finance_id']) ? $_POST['finance_id'] : '';
$register_month = isset($_POST['register_month']) ? $_POST['register_month'] : '';
$register_year = isset($_POST['register_year']) ? $_POST['register_year'] : '';

// Validate required fields
if (empty($learner_id) || empty($class_id) || empty($register_month) || empty($register_year)) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing required fields'
    ]);
    exit;
}

// Check if file was uploaded
if (!isset($_FILES['register_file']) || $_FILES['register_file']['error'] !== UPLOAD_ERR_OK) {
    echo json_encode([
        'success' => false,
        'message' => 'No file uploaded or upload error'
    ]);
    exit;
}

try {
    // Create upload directory if it doesn't exist
    $uploadDir = 'uploads/registers/';
    if (!file_exists($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }

    // Generate unique filename
    $file = $_FILES['register_file'];
    $fileExtension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $fileName = 'register_' . $learner_id . '_' . $register_year . '_' . str_pad($register_month, 2, '0', STR_PAD_LEFT) . '_' . time() . '.' . $fileExtension;
    $filePath = $uploadDir . $fileName;

    // Move uploaded file
    if (!move_uploaded_file($file['tmp_name'], $filePath)) {
        echo json_encode([
            'success' => false,
            'message' => 'Failed to save file'
        ]);
        exit;
    }

    // Check if register already exists for this month/year
    $checkQuery = "
        SELECT id FROM learner_registers 
        WHERE learner_id = ? 
        AND register_month = ? 
        AND register_year = ?
    ";
    
    $checkStmt = $conn->prepare($checkQuery);
    $checkStmt->bind_param('sii', $learner_id, $register_month, $register_year);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();
    
    if ($checkResult->num_rows > 0) {
        // Update existing record
        $row = $checkResult->fetch_assoc();
        $updateQuery = "
            UPDATE learner_registers 
            SET file_name = ?,
                file_path = ?,
                finance_id = ?,
                uploaded_at = NOW()
            WHERE id = ?
        ";
        
        $updateStmt = $conn->prepare($updateQuery);
        $updateStmt->bind_param('sssi', $fileName, $filePath, $finance_id, $row['id']);
        
        if ($updateStmt->execute()) {
            echo json_encode([
                'success' => true,
                'message' => 'Register updated successfully',
                'register_id' => $row['id']
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'message' => 'Failed to update register: ' . $conn->error
            ]);
        }
        
        $updateStmt->close();
    } else {
        // Insert new record
        $insertQuery = "
            INSERT INTO learner_registers 
            (learner_id, class_id, finance_id, register_month, register_year, file_name, file_path, uploaded_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
        ";
        
        $insertStmt = $conn->prepare($insertQuery);
        $insertStmt->bind_param('sssssss', $learner_id, $class_id, $finance_id, $register_month, $register_year, $fileName, $filePath);
        
        if ($insertStmt->execute()) {
            echo json_encode([
                'success' => true,
                'message' => 'Register uploaded successfully',
                'register_id' => $conn->insert_id
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'message' => 'Failed to save register: ' . $conn->error
            ]);
        }
        
        $insertStmt->close();
    }
    
    $checkStmt->close();
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
