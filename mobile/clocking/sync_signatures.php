<?php
/**
 * Sync Signature Images API
 * Receives signature images from mobile app and saves to server
 * 
 * Endpoint: /mobile/clocking/sync_signatures.php
 * Method: POST
 * Content-Type: multipart/form-data
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Include database connection
require_once '../../connection.php';

// Response helper
function sendResponse($success, $message, $data = null) {
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data
    ]);
    exit;
}

// Validate request method
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse(false, 'Invalid request method. Use POST.');
}

// Check if signature file was uploaded
if (!isset($_FILES['signature']) || $_FILES['signature']['error'] !== UPLOAD_ERR_OK) {
    sendResponse(false, 'No signature file uploaded or upload error occurred.');
}

// Get filename from POST data
$filename = isset($_POST['filename']) ? trim($_POST['filename']) : '';

if (empty($filename)) {
    sendResponse(false, 'Filename is required.');
}

// Validate filename format: signature_{learnerID}_{timestamp}.png
if (!preg_match('/^signature_\d+_\d{8}_\d{6}\.png$/', $filename)) {
    sendResponse(false, 'Invalid filename format. Expected: signature_{ID}_{YYYYMMDD_HHMMSS}.png');
}

// Extract learner ID and date from filename
// Example: signature_11443_20260911_163045.png
preg_match('/signature_(\d+)_(\d{8})_\d{6}\.png/', $filename, $matches);
$learnerID = $matches[1];
$dateStr = $matches[2]; // YYYYMMDD
$clockDate = substr($dateStr, 0, 4) . '-' . substr($dateStr, 4, 2) . '-' . substr($dateStr, 6, 2);

try {
    // Create signatures directory if it doesn't exist
    $uploadDir = '../../signatures/';
    if (!file_exists($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }

    // Full path where file will be saved
    $targetPath = $uploadDir . $filename;

    // Move uploaded file to target directory
    if (!move_uploaded_file($_FILES['signature']['tmp_name'], $targetPath)) {
        sendResponse(false, 'Failed to save signature file to server.');
    }

    // Update database record with signature filename
    $stmt = $conn->prepare("
        UPDATE learner_clocking 
        SET signature = ? 
        WHERE LearnerID = ? 
        AND DATE(clock_date) = ?
        AND signature IS NULL OR signature = ''
        LIMIT 1
    ");
    
    $stmt->bind_param('sss', $filename, $learnerID, $clockDate);
    $stmt->execute();
    
    $rowsAffected = $stmt->affected_rows;
    $stmt->close();

    // Log the sync
    error_log("[SIGNATURE_SYNC] Saved: $filename for learner $learnerID on $clockDate (DB updated: $rowsAffected rows)");

    sendResponse(true, 'Signature synced successfully.', [
        'filename' => $filename,
        'learner_id' => $learnerID,
        'clock_date' => $clockDate,
        'file_size' => filesize($targetPath),
        'db_updated' => $rowsAffected > 0
    ]);

} catch (Exception $e) {
    error_log("[SIGNATURE_SYNC_ERROR] " . $e->getMessage());
    sendResponse(false, 'Server error: ' . $e->getMessage());
}
?>
