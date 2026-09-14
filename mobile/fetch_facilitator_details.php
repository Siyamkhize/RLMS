<?php
header('Content-Type: application/json');
$facilitator_id = $_GET['facilitator_id'];

include 'connection.php';

$stmt = $conn->prepare("SELECT firstName, lastName, classID FROM facilitator WHERE facilitator_id = ?");
$stmt->bind_param("s", $facilitator_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    echo json_encode($row);
} else {
    echo json_encode(['status' => 'error', 'message' => 'No facilitator found.']);
}

$stmt->close();
$conn->close();
?>