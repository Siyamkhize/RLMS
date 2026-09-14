<?php
/**
 * Save Learner Signature Endpoint - SECURED
 * 
 * Security Features:
 * - Bearer token authentication required
 * - Rate limiting: 20 uploads per minute
 * - File type validation (PNG images only)
 * - File size validation (max 2MB)
 * - MIME type verification
 * - Learner existence check
 * - SQL injection protection
 * 
 * Handles both 'signature' and 'witness_signature' fields
 * 
 * @security CRITICAL - Authentication required
 */

require_once 'require_auth.php';
require_once 'connection.php';

header('Content-Type: application/json');

// SECURITY: Require authentication
$user = requireAuth($conn);

// SECURITY: Apply rate limiting (20 uploads per minute)
applyRateLimit($conn, 'save_signature');

// Determine which signature field is present
$field_name = '';
$signature = null;
if (isset($_FILES['signature'])) {
    $field_name = 'signature';
    $signature = $_FILES['signature'];
} elseif (isset($_FILES['witness_signature'])) {
    $field_name = 'witness_signature';
    $signature = $_FILES['witness_signature'];
}

if (!$signature || !isset($_POST['learner_id'])) {
    sendError('Missing signature file or learner_id', 400, 'MISSING_REQUIRED_FIELDS');
}

// SECURITY: Validate learner_id is integer
$learner_id = validate_int($_POST['learner_id'], 1);
if ($learner_id === false) {
    sendError('Invalid learner_id format', 400, 'INVALID_PARAMETER');
}

// SECURITY: Comprehensive file upload validation for PNG signatures
$validation = validate_file_upload($signature, [
    'allowed_extensions' => ['png'],
    'allowed_mime_types' => ['image/png'],
    'max_size' => 2 * 1024 * 1024,  // 2MB (signatures should be smaller)
    'allow_svg' => false
]);

if (!$validation['valid']) {
    sendError($validation['error'], 400, 'INVALID_FILE_UPLOAD');
}

// SECURITY: Verify learner exists
$check_query = "SELECT LearnerID FROM learnerdetails WHERE LearnerID = ?";
$check_stmt = $conn->prepare($check_query);
$check_stmt->bind_param("i", $learner_id);
$check_stmt->execute();
$check_result = $check_stmt->get_result();

if ($check_result->num_rows === 0) {
    $check_stmt->close();
    sendError('Learner not found', 404, 'LEARNER_NOT_FOUND');
}
$check_stmt->close();

// Ensure upload directory exists with secure permissions
$upload_dir = 'signatures/';
if (!is_dir($upload_dir)) {
    mkdir($upload_dir, 0755, true);
}

// Generate simple filename: signature_LEARNERID.png or witness_signature_LEARNERID.png
$file_name = $field_name . '_' . $learner_id . '.png';
$file_path = $upload_dir . $file_name;

// Move uploaded file
if (move_uploaded_file($signature['tmp_name'], $file_path)) {
    // Set secure file permissions
    chmod($file_path, 0644);
    // Set secure file permissions
    chmod($file_path, 0644);
    
    // Update database - column name matches field name
    $column = $field_name === 'signature' ? 'signature' : 'witness_signature';
    $sql = "UPDATE learnerdetails SET $column = ? WHERE LearnerID = ?";
    $stmt = $conn->prepare($sql);

    if ($stmt === false) {
        // Clean up uploaded file on error
        @unlink($file_path);
        sendError('Database prepare failed: ' . $conn->error, 500, 'DATABASE_ERROR');
    }

    $stmt->bind_param("si", $file_name, $learner_id);

    if ($stmt->execute()) {
        // Log security event
        log_security_event('signature_uploaded', "$field_name uploaded successfully", [
            'user_id' => $user['user_id'],
            'learner_id' => $learner_id,
            'field_name' => $field_name,
            'filename' => $file_name
        ]);
        
        sendSuccess([
            'filename' => $file_name,
            'field_name' => $field_name,
            'learner_id' => $learner_id
        ], "$field_name saved successfully");
    } else {
        // Clean up uploaded file on database error
        @unlink($file_path);
        sendError('Database execute failed: ' . $stmt->error, 500, 'DATABASE_ERROR');
    }

    $stmt->close();
} else {
    sendError('Failed to save signature file', 500, 'FILE_SAVE_ERROR');
}

$conn->close();
?>