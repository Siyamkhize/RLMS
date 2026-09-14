<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

include('connection.php');

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Connection failed: " . $conn->connect_error]);
    exit;
}

// Handle OPTIONS preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Get the raw POST data
$data = json_decode(file_get_contents("php://input"), true);

// Log incoming data for debugging
error_log("Received data: " . print_r($data, true));

// Validate input data
if (!isset($data['learnerId']) || !isset($data['assessmentType']) || !isset($data['m_comment'])) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Missing required fields: learnerId, assessmentType, or m_comment"]);
    exit;
}

$learnerId = $data['learnerId'];
$assessmentType = $data['assessmentType'];
$comment = $data['m_comment'];

// Check if a row exists
$checkSql = "SELECT COUNT(*) as count FROM marks WHERE learnerID = ? AND type = ?";
$checkStmt = $conn->prepare($checkSql);
$checkStmt->bind_param("is", $learnerId, $assessmentType);
$checkStmt->execute();
$checkResult = $checkStmt->get_result();
$row = $checkResult->fetch_assoc();
$checkStmt->close();

if ($row['count'] > 0) {
    // Update existing row
    $sql = "UPDATE marks SET comment = ? WHERE learnerID = ? AND type = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sis", $comment, $learnerId, $assessmentType);

    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            echo json_encode(["status" => "success", "message" => "Comment updated successfully!"]);
        } else {
            echo json_encode(["status" => "error", "message" => "No rows updated for learnerID: $learnerId and type: $assessmentType"]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to update comment: " . $stmt->error]);
    }
    $stmt->close();
} else {
    // Insert new row
    $sql = "INSERT INTO marks (learnerID, type, comment, exercise, so, created_at) VALUES (?, ?, ?, ?, ?, NOW())";
    $stmt = $conn->prepare($sql);
    $exercise = "Default Exercise"; // Replace with appropriate value
    $so = "Default SO"; // Replace with appropriate value
    $stmt->bind_param("issss", $learnerId, $assessmentType, $comment, $exercise, $so);

    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "message" => "Comment inserted successfully!"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to insert comment: " . $stmt->error]);
    }
    $stmt->close();
}

$conn->close();
?>