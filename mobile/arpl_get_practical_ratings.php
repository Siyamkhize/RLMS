<?php
/**
 * ARPL Get Practical Ratings Endpoint
 * Retrieves practical papers for assessor marking/rating interface
 * Can filter by: rating_status (pending_rating, rated, reviewed), learnerID, ofo_number
 * Created: July 7, 2026
 */

ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', '/home/username/public_html/logs/php_error_log');
error_reporting(E_ALL);
ob_start();

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
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

if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse('error', 'Invalid request method. GET or POST required.');
}

// ============================================
// GET FILTER PARAMETERS
// ============================================
$ratingStatus = isset($_GET['rating_status']) || isset($_POST['rating_status']) 
    ? trim($_GET['rating_status'] ?? $_POST['rating_status'] ?? 'pending_rating')
    : 'pending_rating';

$learnerID = isset($_GET['learnerID']) || isset($_POST['learnerID'])
    ? intval($_GET['learnerID'] ?? $_POST['learnerID'] ?? 0)
    : 0;

$ofoNumber = isset($_GET['ofo_number']) || isset($_POST['ofo_number'])
    ? trim($_GET['ofo_number'] ?? $_POST['ofo_number'] ?? '')
    : '';

$limit = isset($_GET['limit']) || isset($_POST['limit'])
    ? intval($_GET['limit'] ?? $_POST['limit'] ?? 100)
    : 100;

$offset = isset($_GET['offset']) || isset($_POST['offset'])
    ? intval($_GET['offset'] ?? $_POST['offset'] ?? 0)
    : 0;

// Validate rating_status
if (!in_array($ratingStatus, ['pending_rating', 'rated', 'reviewed'])) {
    $ratingStatus = 'pending_rating';
}

// Limit bounds
$limit = min($limit, 500);
$offset = max($offset, 0);

error_log("Fetching practicals: status=$ratingStatus, learner=$learnerID, ofo=$ofoNumber, limit=$limit, offset=$offset");

// ============================================
// BUILD QUERY
// ============================================
$query = "
    SELECT 
        p.id,
        p.learnerID,
        p.ofo_number,
        p.paper_title,
        p.paper_number,
        p.section_type,
        p.question_count,
        p.file_name,
        p.combined_pdf_path,
        p.upload_status,
        p.rating,
        p.rating_status,
        p.assessor_id,
        p.assessor_comments,
        p.rated_at,
        p.created_at,
        p.updated_at,
        CONCAT(l.Name, ' ', l.Surname) as learner_name,
        l.IDNumber as learner_id_number
    FROM arpl_poe p
    LEFT JOIN learnerdetails l ON p.learnerID = l.LearnerID
    WHERE p.section_type = 'practical'
";

// Add optional filters
if ($ratingStatus !== 'all') {
    $query .= " AND p.rating_status = '" . $conn->real_escape_string($ratingStatus) . "'";
}

if ($learnerID > 0) {
    $query .= " AND p.learnerID = " . intval($learnerID);
}

if (!empty($ofoNumber)) {
    $query .= " AND p.ofo_number = '" . $conn->real_escape_string($ofoNumber) . "'";
}

$query .= " ORDER BY p.rating_status, p.created_at DESC LIMIT " . intval($limit) . " OFFSET " . intval($offset);

// ============================================
// EXECUTE QUERY
// ============================================
$result = $conn->query($query);

if (!$result) {
    error_log('Query error: ' . $conn->error);
    sendResponse('error', 'Database query failed: ' . $conn->error);
}

// Fetch all records
$practicals = [];
while ($row = $result->fetch_assoc()) {
    $practicals[] = $row;
}

// Get total count (without limit/offset)
$countQuery = "
    SELECT COUNT(*) as total FROM arpl_poe 
    WHERE section_type = 'practical'
";

if ($ratingStatus !== 'all') {
    $countQuery .= " AND rating_status = '" . $conn->real_escape_string($ratingStatus) . "'";
}

if ($learnerID > 0) {
    $countQuery .= " AND learnerID = " . intval($learnerID);
}

if (!empty($ofoNumber)) {
    $countQuery .= " AND ofo_number = '" . $conn->real_escape_string($ofoNumber) . "'";
}

$countResult = $conn->query($countQuery);
$countRow = $countResult->fetch_assoc();
$totalCount = intval($countRow['total']);

// ============================================
// SUCCESS RESPONSE
// ============================================
ob_end_clean();

$response = [
    'status' => 'success',
    'message' => 'Practical papers retrieved successfully',
    'pagination' => [
        'total' => $totalCount,
        'limit' => $limit,
        'offset' => $offset,
        'count' => count($practicals)
    ],
    'filters' => [
        'rating_status' => $ratingStatus,
        'learnerID' => $learnerID,
        'ofo_number' => $ofoNumber
    ],
    'data' => $practicals
];

echo json_encode($response);
error_log("Fetched " . count($practicals) . " practical papers (total: $totalCount)");

$conn->close();
ob_end_flush();
