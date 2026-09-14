<?php
header('Content-Type: application/json');
// Enable CORS (adjust the origin as needed)
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

// Include the database connection file
include 'connection.php';

// Check the database connection
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database connection failed: ' . $conn->connect_error]);
    exit;
}

// Query to fetch all records from the poe table
$sql = "SELECT poe_id, learnerID, exercise, type, filePath, submitted_at, synced, logbook_text, UNHEX(HEX(exercise_hash)) AS exercise_hash FROM poe WHERE synced = 0 ORDER BY submitted_at ASC LIMIT 1000";
$result = $conn->query($sql);

// Check for query errors
if (!$result) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Query failed: ' . $conn->error]);
    exit;
}

// Fetch data
$poe = [];
if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        // Convert exercise_hash (binary) to a hexadecimal string for compatibility with SQLite TEXT
        $row['exercise_hash'] = bin2hex($row['exercise_hash']);
        $poe[] = $row;
    }
}

// Return data as JSON
echo json_encode(['status' => 'success', 'data' => $poe], JSON_PRETTY_PRINT);

// Close the database connection
$conn->close();
?>