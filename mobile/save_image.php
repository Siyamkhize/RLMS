<?php
/**
 * Save Learner Profile Image Endpoint - SECURED
 * 
 * Security Features:
 * - Bearer token authentication required
 * - Rate limiting: 20 uploads per minute
 * - File type validation (images only)
 * - File size validation (max 5MB)
 * - MIME type verification
 * - Image integrity check
 * - SQL injection protection
 * 
 * @security CRITICAL - Authentication required
 */

require_once 'require_auth.php';
require_once 'connection.php';

header('Content-Type: application/json');

// SECURITY: Require authentication
$user = requireAuth($conn);

// SECURITY: Apply rate limiting (20 uploads per minute)
applyRateLimit($conn, 'save_image');

$targetDir = "learnerImages/";

// Create directory with secure permissions
if (!is_dir($targetDir)) {
    mkdir($targetDir, 0755, true);
}

// SECURITY: Validate required fields
if (!isset($_FILES['image']) || !isset($_POST['learner_id'])) {
    sendError('Missing image file or learner_id', 400, 'MISSING_REQUIRED_FIELDS');
}

// SECURITY: Validate learner_id is integer
$learner_id = validate_int($_POST['learner_id'], 1);
if ($learner_id === false) {
    sendError('Invalid learner_id format', 400, 'INVALID_PARAMETER');
}

$imageFile = $_FILES['image'];

// SECURITY: Comprehensive file upload validation
$validation = validate_file_upload($imageFile, [
    'allowed_extensions' => ['jpg', 'jpeg', 'png'],
    'allowed_mime_types' => ['image/jpeg', 'image/png'],
    'max_size' => 5 * 1024 * 1024,  // 5MB
    'allow_svg' => false
]);

if (!$validation['valid']) {
    sendError($validation['error'], 400, 'INVALID_FILE_UPLOAD');
}

// Get validated file extension
$fileExt = $validation['extension'];

// Generate simple filename: learnerImages_LEARNERID.ext
$image_name = 'learnerImages_' . $learner_id . '.' . $fileExt;
$targetFilePath = $targetDir . $image_name;

// SECURITY: Verify learner exists before uploading
$check_stmt = $conn->prepare("SELECT LearnerID FROM learnerdetails WHERE LearnerID = ?");
$check_stmt->bind_param("i", $learner_id);
$check_stmt->execute();
$check_result = $check_stmt->get_result();

if ($check_result->num_rows === 0) {
    $check_stmt->close();
    sendError('Learner not found', 404, 'LEARNER_NOT_FOUND');
}
$check_stmt->close();

// Move the uploaded file to the target directory
if (move_uploaded_file($imageFile['tmp_name'], $targetFilePath)) {
    // Set secure file permissions
    chmod($targetFilePath, 0644);
    // Set secure file permissions
    chmod($targetFilePath, 0644);
    
    // Update the existing learner record with the image filename
    $stmt = $conn->prepare("UPDATE learnerdetails SET profile_image = ?, synced = 1 WHERE LearnerID = ?");
    $stmt->bind_param("si", $image_name, $learner_id);

    if ($stmt->execute()) {
        // Log security event
        log_security_event('profile_image_uploaded', 'Profile image uploaded successfully', [
            'user_id' => $user['user_id'],
            'learner_id' => $learner_id,
            'filename' => $image_name
        ]);
        
        sendSuccess([
            'image_name' => $image_name,
            'learner_id' => $learner_id
        ], 'Image uploaded and database updated successfully');
    } else {
        // Clean up uploaded file on database error
        @unlink($targetFilePath);
        sendError('Database error: ' . $stmt->error, 500, 'DATABASE_ERROR');
    }
    $stmt->close();
} else {
    sendError('Failed to save uploaded file', 500, 'FILE_SAVE_ERROR');
}

$conn->close();
?>
