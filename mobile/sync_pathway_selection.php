<?php
header('Content-Type: application/json');

// Include the database connection file
include ('connection.php');

// Check the database connection
if ($conn->connect_error) {
    die(json_encode(['status' => 'error', 'message' => 'Database connection failed: ' . $conn->connect_error]));
}

// Query to fetch all site data
$sql = "SELECT * FROM pathway_selection";
$result = $conn->query($sql);

// Check if any data was found
if ($result && $result->num_rows > 0) {
    $pathway = [];

    // Fetch each row of data
    while ($row = $result->fetch_assoc()) {
        $pathway[] = $row;
    }

    // Return data as JSON
    echo json_encode(['status' => 'success', 'data' => $pathway]);
} else {
    // Return an empty array if no data was found
    echo json_encode(['status' => 'success', 'data' => []]);
}

// Close the database connection
$conn->close();
?>