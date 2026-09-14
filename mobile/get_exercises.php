<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Include the database connection file
include('connection.php');

// Get learnerID from the request (POST or GET)
$learnerID = isset($_GET['learnerID']) ? $_GET['learnerID'] : (isset($_POST['learnerID']) ? $_POST['learnerID'] : null);

if ($learnerID === null) {
    echo json_encode(["error" => "Missing learnerID"]);
    exit;
}

// Prepare the SQL query
$query = "SELECT p.poe_id, p.learnerID, p.exercise, p.type, p.filePath 
          FROM poe p 
          JOIN assessments a ON p.type = a.assesment_type 
          WHERE p.learnerID = ? AND p.exercise = a.exercise";

$stmt = $conn->prepare($query);

if ($stmt === false) {
    echo json_encode(["error" => "SQL error: " . $conn->error]);
    exit;
}

// Bind parameter and execute
$stmt->bind_param("i", $learnerID);
$stmt->execute();
$result = $stmt->get_result();

// Fetch data
$results = [];
while ($row = $result->fetch_assoc()) {
    $results[] = $row;
}

// Close statement
$stmt->close();

// Return the results as JSON
echo json_encode($results);
?>
