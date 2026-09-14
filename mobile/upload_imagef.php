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

if (!isset($_POST['classID']) || !isset($_POST['field']) || !isset($_FILES['image'])) {
    echo json_encode(['status' => 'error', 'message' => 'Missing parameters']);
    exit;
}

$classID = $_POST['classID'];
$field = $_POST['field'];
if (!in_array($field, ['f_profile', 'f_signature'])) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid field']);
    exit;
}

$uploadDir = 'Uploads/';
if (!file_exists($uploadDir)) {
    mkdir($uploadDir, 0777, true);
}

$file = $_FILES['image'];
$ext = pathinfo($file['name'], PATHINFO_EXTENSION);
$filename = $classID . '_' . $field . '_' . time() . '.' . $ext;
$filePath = $uploadDir . $filename;

if (move_uploaded_file($file['tmp_name'], $filePath)) {
    $url = 'http://192.168.0.255/lito/dist/rlms/' . $filePath;
    $stmt = $conn->prepare("UPDATE facilitator SET `$field` = ? WHERE classID = ?");
    $stmt->bind_param('ss', $url, $classID);
    if ($stmt->execute()) {
        echo json_encode(['status' => 'success', 'url' => $url]);
    } else {
        echo json_encode(['status' => 'error', 'message' => 'Database update failed']);
    }
    $stmt->close();
} else {
    echo json_encode(['status' => 'error', 'message' => 'File upload failed']);
}

$conn->close();
?>