<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");
include('connection.php');


$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Get the raw POST data
$data = json_decode(file_get_contents("php://input"), true);

$learnerId = $data['learnerId'];
$assessmentType = $data['assessmentType'];
$comment = $data['comment'];

// Update the database
$sql = "UPDATE marks SET a_comment = ? WHERE learnerID = ? AND type = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("sis", $comment, $learnerId, $assessmentType);

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Comment saved successfully!"]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to save comment: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>