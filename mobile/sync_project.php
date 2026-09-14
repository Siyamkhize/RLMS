<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Include the database connection file
include ('connection.php');

// Check the database connection
if ($conn->connect_error) {
    die(json_encode(['status' => 'error', 'message' => 'Database connection failed: ' . $conn->connect_error]));
}

// Query to fetch all project data
$sql = "SELECT * FROM project";  // Added FROM clause
$result = $conn->query($sql);

// Check if any data was found
if ($result && $result->num_rows > 0) {
    $project = [];

    // Fetch each row of data
    while ($row = $result->fetch_assoc()) {
        $project[] = $row;
    }

    // Return data as JSON
    echo json_encode(['status' => 'success', 'data' => $project]);
} else {
    // Return an empty array if no data was found
    echo json_encode(['status' => 'success', 'data' => []]);
}

// Close the database connection
$conn->close();
?>
