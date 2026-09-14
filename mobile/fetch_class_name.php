<?php
header('Content-Type: application/json');
$class_id = $_GET['class_id'];

include 'connection.php';

$stmt = $conn->prepare("SELECT className FROM class WHERE classID = ?");
$stmt->bind_param("s", $class_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    echo json_encode($row);
} else {
    echo json_encode(['status' => 'error', 'message' => 'No class found.']);
}

$stmt->close();
$conn->close();
?>