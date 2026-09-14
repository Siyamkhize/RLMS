<?php
/**
 * Get Learners Endpoint - SECURED
 * 
 * Security Features:
 * - Bearer token authentication required
 * - Rate limiting: 60 requests per minute
 * - Input validation for classID
 * - SQL injection protection via prepared statements
 * 
 * @security CRITICAL - Authentication required
 */

require_once 'require_auth.php';
include('connection.php');

header('Content-Type: application/json');
error_reporting(0); // Hide warnings
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

// SECURITY: Require authentication
$user = requireAuth($conn);

// SECURITY: Apply rate limiting (60 requests per minute)
applyRateLimit($conn, 'get_learners');

// SECURITY: Validate required parameters
if (!isset($_GET['classID'])) {
    sendError('classID is required', 400, 'MISSING_PARAMETER');
}

// SECURITY: Validate classID is a valid integer
$classID = validate_int($_GET['classID'], 1);
if ($classID === false) {
    sendError('Invalid classID format', 400, 'INVALID_PARAMETER');
}
// PAGINATION: Support lazy loading
$page = isset($_GET['page']) ? validate_int($_GET['page'], 1) : 1;
$pageSize = isset($_GET['pageSize']) ? validate_int($_GET['pageSize'], 1, 100) : 30;

if ($page === false || $pageSize === false) {
    sendError('Invalid pagination parameters', 400, 'INVALID_PARAMETER');
}

$offset = ($page - 1) * $pageSize;

// Get total count for pagination metadata
$countQuery = "SELECT COUNT(*) as total FROM learnerdetails WHERE classID = ?";
$countStmt = $conn->prepare($countQuery);
$countStmt->bind_param("i", $classID);
$countStmt->execute();
$countResult = $countStmt->get_result();
$totalCount = $countResult->fetch_assoc()['total'];
$countStmt->close();

// Get paginated results
$query = "SELECT * FROM learnerdetails WHERE classID = ? LIMIT ? OFFSET ?";

$stmt = $conn->prepare($query);
$stmt->bind_param("iii", $classID, $pageSize, $offset);
$stmt->execute();
$result = $stmt->get_result();

$classes = [];
while ($row = $result->fetch_assoc()) {
    $classes[] = $row;
}

// Return paginated response with metadata
$response = [
    'data' => $classes,
    'pagination' => [
        'page' => $page,
        'pageSize' => $pageSize,
        'total' => $totalCount,
        'totalPages' => ceil($totalCount / $pageSize),
        'hasMore' => ($offset + $pageSize) < $totalCount
    ]
];

echo json_encode($response, JSON_PRETTY_PRINT);
$stmt->close();
$conn->close();
?>
