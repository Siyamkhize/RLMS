<?php
header('Content-Type: application/json');

include 'connection.php'; // Your database connection file

$facilitator_id = $_GET['facilitator_id'];

$stmt = $conn->prepare("SELECT classID FROM facilitator WHERE facilitator_id = ?");
$stmt->bind_param("s", $facilitator_id);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    echo json_encode($row);
} else {
    echo json_encode([]);
}

$stmt->close();
$conn->close();
?>