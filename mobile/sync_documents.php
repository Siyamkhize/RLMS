<?php
header('Content-Type: application/json');
include('connection.php');

// Check connection
if ($conn->connect_error) {
    die(json_encode(['success' => false, 'message' => 'Connection failed: ' . $conn->connect_error]));
}

// SQL query to get all learner documents
$query = "SELECT document_id, documentName, learner_document, status, learner_id, upload_date FROM learner_document";
$result = $conn->query($query);

$response = ['success' => false, 'message' => 'No records found', 'data' => []];

if ($result->num_rows > 0) {
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    $response['success'] = true;
    $response['message'] = 'Records fetched successfully';
    $response['data'] = $data;
} else {
    $response['message'] = 'No documents found in the database';
}

// Close the connection
$conn->close();

// Return the response as JSON
echo json_encode($response);
?>
