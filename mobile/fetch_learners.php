<?php
header('Content-Type: application/json');

include 'connection.php'; // Your database connection file

$facilitator_id = $_GET['facilitator_id'];

$stmt = $conn->prepare("SELECT LearnerID, Name, Surname, IDNumber FROM learnerdetails WHERE facilitator_id = ?");
$stmt->bind_param("s", $facilitator_id);
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