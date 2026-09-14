<?php
include 'connection.php'; // Your database connection file

$learnerID = $_GET['learnerID'] ?? '';
$exercise = $_GET['exercise'] ?? '';

if ($learnerID && $exercise) {
    $stmt = $conn->prepare("SELECT marks_scored FROM marks WHERE learnerID = ? AND exercise = ?");
    $stmt->bind_param("is", $learnerID, $exercise);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        echo json_encode(["status" => true, "marks_scored" => $row['marks_scored']]);
    } else {
        echo json_encode(["status" => false, "marks_scored" => "0"]);
    }
} else {
    echo json_encode(["status" => false, "message" => "Invalid request"]);
}

$conn->close();
?>
