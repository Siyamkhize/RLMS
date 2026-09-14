<?php
// Include database connection
include 'connection.php';

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Set headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if (!isset($_POST['classID']) || !isset($_POST['phoneNumber'])) {
    echo json_encode(['status' => 'error', 'message' => 'Missing parameters']);
    exit;
}

$classID = $_POST['classID'];
$phoneNumber = $_POST['phoneNumber'];

$stmt = $conn->prepare("UPDATE facilitator SET phoneNumber = ? WHERE classID = ?");
$stmt->bind_param('ss', $phoneNumber, $classID);
if ($stmt->execute()) {
    echo json_encode(['status' => 'success']);
} else {
    echo json_encode(['status' => 'error', 'message' => 'Update failed']);
}

$stmt->close();
$conn->close();
?>