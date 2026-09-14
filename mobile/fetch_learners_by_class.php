<?php
header('Content-Type: application/json');

include 'connection.php'; // Your database connection file

$class_id = $_GET['class_id'];

$stmt = $conn->prepare("SELECT LearnerID, Name, Surname, IDNumber FROM learnerdetails WHERE classID = ?");
$stmt->bind_param("s", $class_id);
$stmt->execute();
$result = $stmt->get_result();

$learners = [];
while ($row = $result->fetch_assoc()) {
    $learners[] = $row;
}

$stmt->close();
$conn->close();

echo json_encode($learners);
?>