<?php
// Set the content type to JSON
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

// Database connection
include('connection.php');
if ($conn->connect_error) {
    die(json_encode(["error" => "Connection failed: " . $conn->connect_error]));
}

// Check if learner_id is provided
if (!isset($_GET['learner_id']) || empty($_GET['learner_id'])) {
    echo json_encode(["error" => "Missing learner_id"]);
    exit;
}

$learner_id = intval($_GET['learner_id']); // Sanitize input

// Query to fetch documents for the given learner_id
$query = "SELECT documentName, learner_document 
          FROM learner_document 
          WHERE learner_id = ? 
          AND documentName IN ('ID Document', 'Qualifications')";

$stmt = $conn->prepare($query);
$stmt->bind_param("i", $learner_id);
$stmt->execute();
$result = $stmt->get_result();

$documents = [];
if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $documents[] = [
            "title" => $row['documentName'],
            "learner_document" => $row['learner_document']
        ];
    }
}

$stmt->close();
$conn->close();

// Return the data as JSON
echo json_encode($documents);
?>
