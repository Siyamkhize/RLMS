<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Database configuration
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "rlms";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Database connection failed: ' . $conn->connect_error
    ]);
    exit;
}

try {
    // Validate required fields
    if (!isset($_POST['learner_id']) || !isset($_POST['assessor_id']) || !isset($_POST['assessment_date'])) {
        throw new Exception('Missing required fields');
    }
    
    $learner_id = $conn->real_escape_string($_POST['learner_id']);
    $assessor_id = $conn->real_escape_string($_POST['assessor_id']);
    $assessment_date = $conn->real_escape_string($_POST['assessment_date']);
    
    // Validate file upload
    if (!isset($_FILES['document']) || $_FILES['document']['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('No file uploaded or upload error');
    }
    
    $file = $_FILES['document'];
    
    // Get file extension
    $file_extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png'];
    
    // Check by extension (more reliable than MIME type)
    if (!in_array($file_extension, $allowed_extensions)) {
        throw new Exception('Invalid file type. Only PDF and images (jpg, png) are allowed. Received: ' . $file_extension);
    }
    
    // Also check MIME type as secondary validation
    $allowed_mime_types = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg', 'application/octet-stream'];
    if (!in_array($file['type'], $allowed_mime_types)) {
        // Log warning but don't reject if extension is valid
        error_log('Warning: Unexpected MIME type ' . $file['type'] . ' for file with extension ' . $file_extension);
    }
    
    // Create upload directory if it doesn't exist
    $upload_dir = '../uploads/pothole_checklists/';
    if (!file_exists($upload_dir)) {
        mkdir($upload_dir, 0777, true);
    }
    
    // Generate unique filename
    $file_extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $filename = 'pothole_checklist_' . $learner_id . '_' . time() . '.' . $file_extension;
    $file_path = $upload_dir . $filename;
    
    // Move uploaded file
    if (!move_uploaded_file($file['tmp_name'], $file_path)) {
        throw new Exception('Failed to save uploaded file');
    }
    
    // Check if record already exists
    $check_sql = "SELECT id FROM pothole_checklist_scanned_documents 
                  WHERE learner_id = ? AND assessor_id = ? AND assessment_date = ?";
    $check_stmt = $conn->prepare($check_sql);
    $check_stmt->bind_param("sss", $learner_id, $assessor_id, $assessment_date);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    
    if ($check_result->num_rows > 0) {
        // Update existing record
        $row = $check_result->fetch_assoc();
        $old_file = $row['document_path'];
        
        // Delete old file if it exists
        if (file_exists($old_file)) {
            unlink($old_file);
        }
        
        $update_sql = "UPDATE pothole_checklist_scanned_documents 
                       SET document_path = ?, created_at = NOW() 
                       WHERE id = ?";
        $update_stmt = $conn->prepare($update_sql);
        $update_stmt->bind_param("si", $file_path, $row['id']);
        $update_stmt->execute();
        $update_stmt->close();
    } else {
        // Insert new record
        $insert_sql = "INSERT INTO pothole_checklist_scanned_documents 
                       (learner_id, assessor_id, document_path, assessment_date, created_at) 
                       VALUES (?, ?, ?, ?, NOW())";
        $insert_stmt = $conn->prepare($insert_sql);
        $insert_stmt->bind_param("ssss", $learner_id, $assessor_id, $file_path, $assessment_date);
        $insert_stmt->execute();
        $insert_stmt->close();
    }
    
    $check_stmt->close();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Scanned document uploaded successfully',
        'file_path' => $file_path
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
