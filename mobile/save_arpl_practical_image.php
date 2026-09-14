<?php
/**
 * Save ARPL Practical Evidence Image
 * 
 * Accepts base64-encoded image, saves to server, stores metadata in database
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

try {
    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $learner_id = $input['learner_id'] ?? null;
    $class_id = $input['class_id'] ?? null;
    $ofo_number = $input['ofo_number'] ?? null;
    $practical_task_id = $input['practical_task_id'] ?? null;
    $role = $input['role'] ?? null;
    $user_id = $input['user_id'] ?? null;
    $image_base64 = $input['image_base64'] ?? null;
    $caption = $input['caption'] ?? '';
    
    // Validate required fields
    if (!$learner_id || !$class_id || !$ofo_number || !$practical_task_id || !$role || !$user_id || !$image_base64) {
        throw new Exception('Missing required fields');
    }
    
    // Validate role
    if (!in_array($role, ['assessor', 'moderator'])) {
        throw new Exception('Invalid role. Must be assessor or moderator');
    }
    
    // Validate practical_task_id format (PT1-PT10)
    if (!preg_match('/^PT([1-9]|10)$/', $practical_task_id)) {
        throw new Exception('Invalid practical_task_id format. Must be PT1 through PT10');
    }
    
   
    // Create directory structure: arpl_practical_images/{ofo_number}_class{class_id}/{learner_id}/
     $folderName = $ofo_number . '_class' . $class_id;
    $uploadDir = __DIR__ . '/arpl_practical_images/' . $folderName . '/' . $learner_id . '/';
        if (!is_dir($uploadDir)) {
            if (!mkdir($uploadDir, 0755, true)) {
                throw new Exception('Failed to create upload directory');
            }
        }
    
    // Generate unique filename
    $timestamp = time();
    $filename = $practical_task_id . '_' . $role . '_' . $timestamp . '.jpg';
    $fullPath = $uploadDir . $filename;
    
    // Decode base64 image
    $imageData = base64_decode($image_base64);
    if ($imageData === false) {
        throw new Exception('Failed to decode base64 image');
    }
    
    // Save image to file
    if (file_put_contents($fullPath, $imageData) === false) {
        throw new Exception('Failed to save image file');
    }
    
    // Store relative path for database (path is relative to mobile folder)
    $relativePath = 'arpl_practical_images/' . $folderName . '/' . $learner_id . '/' . $filename;

    // Create database connection
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        // Clean up uploaded file
        unlink($fullPath);
        throw new Exception('Database connection failed: ' . $conn->connect_error);
    }
    
    // Insert metadata into database
    $stmt = $conn->prepare("
        INSERT INTO arpl_practical_images 
        (learner_id, class_id, ofo_number, practical_task_id, role, user_id, image_path, caption, uploaded_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ");
    
    if (!$stmt) {
        // Clean up uploaded file
        unlink($fullPath);
        throw new Exception('Query preparation failed: ' . $conn->error);
    }
    
    $stmt->bind_param(
        'iissssss',
        $learner_id,
        $class_id,
        $ofo_number,
        $practical_task_id,
        $role,
        $user_id,
        $relativePath,
        $caption
    );
    
    if (!$stmt->execute()) {
        // Clean up uploaded file
        unlink($fullPath);
        throw new Exception('Failed to save image metadata: ' . $stmt->error);
    }
    
    $image_id = $conn->insert_id;
    
    $stmt->close();
    $conn->close();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Image uploaded successfully',
        'image_id' => $image_id,
        'image_path' => $relativePath,
        'filename' => $filename
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
