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
$query = "SELECT * FROM learnerdetails WHERE classID = ?
";

$stmt = $conn->prepare($query);
$stmt->bind_param("i", $classID);
$stmt->execute();
$result = $stmt->get_result();

$classes = [];
while ($row = $result->fetch_assoc()) {
    $classes[] = $row;
}

echo json_encode($classes, JSON_PRETTY_PRINT);
$stmt->close();
$conn->close();
?>
