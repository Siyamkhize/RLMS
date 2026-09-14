<?php
header('Content-Type: application/json');

include('connection.php');

$response = [];

// Check the database connection
if ($conn->connect_error) {
    $response = [
        'status' => 'error',
        'message' => 'Database connection failed: ' . $conn->connect_error,
    ];
    echo json_encode($response);
    exit; // Stop further execution
}

// Query to fetch all SDP data
$sql = "SELECT * FROM sdp";
$result = $conn->query($sql);

if ($result && $result->num_rows > 0) {
    $sdps = [];

    // Fetch data row by row
    while ($row = $result->fetch_assoc()) {
        $sdps[] = $row;
    }

    // Success response with data
    $response = [
        'status' => 'success',
        'data' => $sdps,
    ];
} else {
    // Success response with an empty data array
    $response = [
        'status' => 'success',
        'data' => [],
    ];
}

// Return JSON response
echo json_encode($response);

// Close the database connection
$conn->close();
