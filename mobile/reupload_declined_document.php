<?php
header('Content-Type: application/json');

include 'connection.php';
// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database connection failed: ' . $conn->connect_error
    ]);
    exit;
}

try {
    // Validate required POST fields
    if (!isset($_POST['learner_id'], $_POST['documentName'], $_FILES['learner_document'])) {
        throw new Exception('Missing required fields');
    }

    $learnerId = $conn->real_escape_string($_POST['learner_id']);
    $documentName = $conn->real_escape_string($_POST['documentName']);
    
    // Convert documentName to lowercase with underscores for document_type
    // "ID Document" -> "id_document", "Bank Confirmation Letter" -> "bank_confirmation_letter"
    $documentType = strtolower(str_replace(' ', '_', $documentName));
    
    $uploadDate = date('Y-m-d H:i:s'); // Current timestamp

    // Validate file upload
    $file = $_FILES['learner_document'];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('File upload error: ' . $file['error']);
    }

    // Validate file type and size
    $allowedExtensions = ['pdf'];
    $maxFileSize = 5 * 1024 * 1024; // 5MB
    $fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!in_array($fileExtension, $allowedExtensions)) {
        throw new Exception('Invalid file type. Only PDF files are allowed.');
    }
    if ($file['size'] > $maxFileSize) {
        throw new Exception('File size exceeds 5MB limit.');
    }

    // Create uploads directory if it doesn't exist (same as upload_learner_document.php)
    $uploadDir = 'learner_documents/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }

    // Check if document exists in database for this learner
    $checkQuery = "SELECT document_id, learner_document FROM learner_document 
                   WHERE learner_id = ? AND documentName = ? 
                   ORDER BY document_id DESC LIMIT 1";
    $checkStmt = $conn->prepare($checkQuery);
    if (!$checkStmt) {
        throw new Exception('Prepare check failed: ' . $conn->error);
    }
    
    $checkStmt->bind_param('ss', $learnerId, $documentName);
    $checkStmt->execute();
    $result = $checkStmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception('No existing document found for this learner and document type.');
    }
    
    $existingDoc = $result->fetch_assoc();
    $documentId = $existingDoc['document_id'];
    $oldFilePath = $existingDoc['learner_document'];
    
    $checkStmt->close();

    // Generate unique filename to avoid conflicts (same pattern as upload_learner_document.php)
    $uniqueFilename = uniqid('doc_', true) . '.' . $fileExtension;
    $destination = $uploadDir . $uniqueFilename;

    // Move uploaded file to destination
    if (!move_uploaded_file($file['tmp_name'], $destination)) {
        throw new Exception('Failed to save file on server.');
    }

    // Update document record in database - set status back to Pending for admin review
    $updateQuery = "UPDATE learner_document 
                    SET learner_document = ?, 
                        document_type = ?,
                        status = 'Pending', 
                        upload_date = ?, 
                        synced = 1,
                        rejection_reason = NULL
                    WHERE document_id = ?";
    $updateStmt = $conn->prepare($updateQuery);
    if (!$updateStmt) {
        // If update fails, delete the newly uploaded file
        if (file_exists($destination)) {
            unlink($destination);
        }
        throw new Exception('Prepare update failed: ' . $conn->error);
    }

    $updateStmt->bind_param('sssi', $destination, $documentType, $uploadDate, $documentId);

    if (!$updateStmt->execute()) {
        // If update fails, delete the newly uploaded file
        if (file_exists($destination)) {
            unlink($destination);
        }
        throw new Exception('Execute update failed: ' . $updateStmt->error);
    }

    $updateStmt->close();

    // Delete old file if it exists (after successful database update)
    if (!empty($oldFilePath) && file_exists($oldFilePath)) {
        unlink($oldFilePath);
    }

    // Return success response
    echo json_encode([
        'success' => true,
        'message' => 'Document re-uploaded successfully. Status changed to Pending for review.',
        'document_id' => $documentId,
    ]);

} catch (Exception $e) {
    // Return error response
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
} finally {
    // Close statement and connection
    if (isset($updateStmt)) {
        $updateStmt->close();
    }
    $conn->close();
}
?>
