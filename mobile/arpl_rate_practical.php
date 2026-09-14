<?php
/**
 * ARPL Practical Paper Rating Endpoint
 * Allows assessors to add ratings and comments to practical papers
 * Created: July 7, 2026
 */

ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', '/home/username/public_html/logs/php_error_log');
error_reporting(E_ALL);
ob_start();

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

include_once 'connection.php';

/**
 * Send JSON response and exit
 */
function sendResponse($status, $message, $data = []) {
    global $conn;
    ob_end_clean();
    $success = ($status === 'success');
    echo json_encode(array_merge(
        ['status' => $status, 'success' => $success, 'message' => $message],
        $data
    ));
    if (isset($conn)) {
        $conn->close();
    }
    exit;
}

// Check database connection
if (!$conn) {
    error_log('Connection failed');
    sendResponse('error', 'Database connection failed');
}

// Handle OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse('error', 'Invalid request method. POST required.');
}

// ============================================
// VALIDATE INPUT PARAMETERS
// ============================================
$recordId = intval($_POST['record_id'] ?? 0);
$assessorId = intval($_POST['assessor_id'] ?? 0);
$rating = floatval($_POST['rating'] ?? 0);
$comments = trim($_POST['assessor_comments'] ?? '');

// Validate required fields
if ($recordId <= 0 || $assessorId <= 0 || $rating < 0 || $rating > 100) {
    error_log('Invalid input: recordId=' . $recordId . ', assessorId=' . $assessorId . ', rating=' . $rating);
    sendResponse('error', 'Invalid input: record_id and assessor_id required, rating must be 0-100');
}

// ============================================
// VERIFY RECORD EXISTS AND IS PRACTICAL
// ============================================
$checkStmt = $conn->prepare("
    SELECT id, section_type, learnerID, paper_title, paper_number
    FROM arpl_poe 
    WHERE id = ?
");

if (!$checkStmt) {
    error_log('Prepare failed: ' . $conn->error);
    sendResponse('error', 'Database error');
}

$checkStmt->bind_param('i', $recordId);
$checkStmt->execute();
$checkResult = $checkStmt->get_result();

if ($checkResult->num_rows === 0) {
    $checkStmt->close();
    error_log('Record not found: recordId=' . $recordId);
    sendResponse('error', 'Record not found');
}

$record = $checkResult->fetch_assoc();
$checkStmt->close();

// Verify it's a practical paper
if ($record['section_type'] !== 'practical') {
    error_log('Cannot rate theory paper: recordId=' . $recordId . ', section=' . $record['section_type']);
    sendResponse('error', 'Can only rate practical papers');
}

// ============================================
// UPDATE RECORD WITH RATING
// ============================================
$conn->begin_transaction();

try {
    $ratingStatus = 'rated';
    $ratedAt = date('Y-m-d H:i:s');

    $updateStmt = $conn->prepare('
        UPDATE arpl_poe SET 
            rating = ?,
            rating_status = ?,
            assessor_id = ?,
            assessor_comments = ?,
            rated_at = ?
        WHERE id = ? AND section_type = ?
    ');

    if (!$updateStmt) {
        throw new Exception('Database prepare error: ' . $conn->error);
    }

    $sectionType = 'practical';
    $updateStmt->bind_param(
        'dssisss',
        $rating,
        $ratingStatus,
        $assessorId,
        $comments,
        $ratedAt,
        $recordId,
        $sectionType
    );

    if (!$updateStmt->execute()) {
        throw new Exception('Failed to update record: ' . $updateStmt->error);
    }

    $affectedRows = $updateStmt->affected_rows;
    $updateStmt->close();

    if ($affectedRows === 0) {
        throw new Exception('No records updated');
    }

    // Commit transaction
    $conn->commit();

    // ============================================
    // SUCCESS RESPONSE
    // ============================================
    ob_end_clean();

    $response = [
        'status' => 'success',
        'message' => 'Practical paper rated successfully',
        'data' => [
            'record_id' => $recordId,
            'learnerID' => $record['learnerID'],
            'paper_title' => $record['paper_title'],
            'paper_number' => $record['paper_number'],
            'section_type' => 'practical',
            'rating' => $rating,
            'rating_status' => $ratingStatus,
            'assessor_id' => $assessorId,
            'assessor_comments' => $comments,
            'rated_at' => $ratedAt
        ]
    ];

    echo json_encode($response);
    error_log("ARPL practical rated: recordId=$recordId, rating=$rating, assessorId=$assessorId");

} catch (Exception $e) {
    $conn->rollback();
    error_log('Rating update failed: ' . $e->getMessage());
    sendResponse('error', 'Rating update failed: ' . $e->getMessage());
}

$conn->close();
ob_end_flush();
