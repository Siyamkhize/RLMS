<?php
/**
 * Upload Learner Document Endpoint - SECURED
 * 
 * Security Features:
 * - Bearer token authentication required
 * - Rate limiting: 15 uploads per minute
 * - PDF-only validation
 * - File size validation (max 5MB)
 * - MIME type verification
 * - Input sanitization
 * - SQL injection protection
 * - Learner existence check
 * 
 * @security CRITICAL - Authentication required
 */

require_once 'require_auth.php';
include 'connection.php';

header('Content-Type: application/json');

// SECURITY: Require authentication
$user = requireAuth($conn);

// SECURITY: Apply rate limiting (15 document uploads per minute)
applyRateLimit($conn, 'upload_document');

try {
    // SECURITY: Validate required POST fields and file upload
    if (!isset($_POST['learner_id'], $_POST['documentName'], $_POST['upload_date'], $_FILES['learner_document'])) {
        sendError('Missing required fields', 400, 'MISSING_REQUIRED_FIELDS');
    }

    // SECURITY: Validate and sanitize learner_id
    $learnerId = validate_int($_POST['learner_id'], 1);
    if ($learnerId === false) {
        sendError('Invalid learner_id format', 400, 'INVALID_PARAMETER');
    }

    // SECURITY: Sanitize text inputs
    $documentName = sanitize_input($_POST['documentName']);
    $uploadDate = sanitize_input($_POST['upload_date']);
    $status = isset($_POST['status']) ? sanitize_input($_POST['status']) : 'Pending';
    $synced = isset($_POST['synced']) ? validate_int($_POST['synced'], 0, 1) : 1;
    $rejectionReason = isset($_POST['rejection_reason']) ? sanitize_input($_POST['rejection_reason']) : null;
    
    // Convert documentName to lowercase with underscores for document_type
    $documentType = strtolower(str_replace(' ', '_', $documentName));

    // SECURITY: Verify learner exists
    $check_stmt = $conn->prepare("SELECT LearnerID FROM learnerdetails WHERE LearnerID = ?");
    $check_stmt->bind_param("i", $learnerId);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    
    if ($check_result->num_rows === 0) {
        $check_stmt->close();
        sendError('Learner not found', 404, 'LEARNER_NOT_FOUND');
    }
    $check_stmt->close();

    $file = $_FILES['learner_document'];

    // SECURITY: Comprehensive file upload validation for PDFs
    $validation = validate_file_upload($file, [
        'allowed_extensions' => ['pdf'],
        'allowed_mime_types' => ['application/pdf'],
        'max_size' => 5 * 1024 * 1024,  // 5MB
        'allow_svg' => false
    ]);

    if (!$validation['valid']) {
        sendError($validation['error'], 400, 'INVALID_FILE_UPLOAD');
    }

    // Create uploads directory with secure permissions
    $uploadDir = 'learner_documents/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }

    // Generate unique filename to avoid conflicts and prevent path traversal
    $uniqueFilename = uniqid('doc_', true) . '.pdf';
    $destination = $uploadDir . $uniqueFilename;

    // Move uploaded file to destination
    if (!move_uploaded_file($file['tmp_name'], $destination)) {
        sendError('Failed to save file on server', 500, 'FILE_SAVE_ERROR');
    }

    // Set secure file permissions
    chmod($destination, 0644);

    // Insert document record into database
    $query = "INSERT INTO learner_document (
        learner_id, documentName, document_type, learner_document, status, upload_date, synced, rejection_reason
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
    
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        // Clean up uploaded file on error
        @unlink($destination);
        sendError('Database prepare failed: ' . $conn->error, 500, 'DATABASE_ERROR');
    }

    $stmt->bind_param(
        'isssssss',
        $learnerId,
        $documentName,
        $documentType,
        $destination,
        $status,
        $uploadDate,
        $synced,
        $rejectionReason
    );

    if (!$stmt->execute()) {
        // Clean up uploaded file on error
        @unlink($destination);
        $stmt->close();
        sendError('Database execute failed: ' . $stmt->error, 500, 'DATABASE_ERROR');
    }

    $documentId = $conn->insert_id;
    $stmt->close();

    // Log security event
    log_security_event('document_uploaded', 'Learner document uploaded successfully', [
        'user_id' => $user['user_id'],
        'learner_id' => $learnerId,
        'document_name' => $documentName,
        'document_type' => $documentType,
        'document_id' => $documentId
    ]);

    // Return success response
    sendSuccess([
        'document_id' => $documentId,
        'filename' => $uniqueFilename
    ], 'Document uploaded successfully');

} catch (Exception $e) {
    sendError($e->getMessage(), 400, 'UPLOAD_ERROR');
} finally {
    $conn->close();
}
?>