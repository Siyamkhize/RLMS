<?php
/**
 * Delete ARPL Practical Evidence Image
 * 
 * Removes image file from server and deletes metadata from database
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
    
    $image_id = $input['image_id'] ?? null;
    
    if (!$image_id) {
        throw new Exception('Missing required field: image_id');
    }
    
    // Create database connection
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception('Database connection failed: ' . $conn->connect_error);
    }
    
    // Get image path before deleting
    $stmt = $conn->prepare("SELECT image_path FROM arpl_practical_images WHERE id = ?");
    if (!$stmt) {
        throw new Exception('Query preparation failed: ' . $conn->error);
    }
    
    $stmt->bind_param('i', $image_id);
    
    if (!$stmt->execute()) {
        throw new Exception('Query execution failed: ' . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    if (!$row) {
        throw new Exception('Image not found');
    }
    
    $imagePath = $row['image_path'];
    $stmt->close();
    
    // Delete from database
    $stmt = $conn->prepare("DELETE FROM arpl_practical_images WHERE id = ?");
    if (!$stmt) {
        throw new Exception('Delete query preparation failed: ' . $conn->error);
    }
    
    $stmt->bind_param('i', $image_id);
    
    if (!$stmt->execute()) {
        throw new Exception('Failed to delete image metadata: ' . $stmt->error);
    }
    
    $stmt->close();
    $conn->close();
    
    // Delete physical file
    $fullPath = __DIR__ . '/' . $imagePath;
    if (file_exists($fullPath)) {
        if (!unlink($fullPath)) {
            // Log warning but don't fail the request
            error_log("Warning: Failed to delete physical file: $fullPath");
        }
    }
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Image deleted successfully',
        'image_id' => $image_id
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
