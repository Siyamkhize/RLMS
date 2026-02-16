<?php
header('Content-Type: application/json');

// Define upload directory
$uploadDir = 'learner_documents/';
$response = ['success' => false, 'error' => '', 'fileName' => '', 'debug' => []];

// Check if directory exists, create if not
if (!is_dir($uploadDir)) {
    if (!mkdir($uploadDir, 0775, true)) {
        $response['error'] = 'Failed to create upload directory.';
        echo json_encode($response);
        exit;
    }
}

// Check if file was uploaded
if (!isset($_FILES['learner_document']) || $_FILES['learner_document']['error'] === UPLOAD_ERR_NO_FILE) {
    $response['error'] = 'No file uploaded.';
    echo json_encode($response);
    exit;
}

$file = $_FILES['learner_document'];

// Get document type from POST data
$documentType = isset($_POST['documentType']) ? $_POST['documentType'] : '';

// Debug information
$response['debug'] = [
    'documentType' => $documentType,
    'fileType' => $file['type'],
    'fileName' => $file['name'],
    'postData' => $_POST
];

// Define allowed file types based on document type
$allowedTypes = ['application/pdf'];
$allowedExtensions = ['pdf'];

if ($documentType === 'Other') {
    // Allow both PDF and image files for "Other" documents
    $allowedTypes = [
        'application/pdf',
        'image/png',
        'image/jpeg',
        'image/jpg', 
        'image/gif',
        'image/bmp',
        'image/webp'
    ];
    $allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'];
}

// Get file extension for validation
$fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));

// Validate file type - check both MIME type and extension
$validMimeType = in_array($file['type'], $allowedTypes);
$validExtension = in_array($fileExtension, $allowedExtensions);

// For images, sometimes MIME type might be different, so prioritize extension for images
$isImageFile = in_array($fileExtension, ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp']);

if ($documentType === 'Other' && $isImageFile) {
    // For "Other" documents with image extensions, allow if extension is valid
    $isValid = $validExtension;
} else {
    // For PDF files and non-Other documents, check both MIME type and extension
    $isValid = $validMimeType && $validExtension;
}

if (!$isValid) {
    if ($documentType === 'Other') {
        $response['error'] = 'For "Other" documents, only PDF and image files (PNG, JPG, JPEG, GIF, BMP, WEBP) are allowed.';
    } else {
        $response['error'] = 'Only PDF files are allowed.';
    }
    echo json_encode($response);
    exit;
}

// Validate file size (10MB limit)
if ($file['size'] > 30 * 1024 * 1024) {
    $response['error'] = 'File size exceeds 30MB limit.';
    echo json_encode($response);
    exit;
}

// Generate a unique file name to avoid conflicts
$originalName = basename($file['name']);
$extension = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
$fileName = uniqid('doc_') . '.' . $extension;
$destination = $uploadDir . $fileName;

// Move the uploaded file
if (move_uploaded_file($file['tmp_name'], $destination)) {
    $response['success'] = true;
    $response['fileName'] = $fileName;
    // Remove debug info for production
    unset($response['debug']);
} else {
    $response['error'] = 'Failed to move uploaded file.';
}

echo json_encode($response);
exit;
?>