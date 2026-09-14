<?php
// Database connection
include('connection.php');

// Turn off error reporting for users
error_reporting(0); 
ini_set('display_errors', 0); // Disable displaying errors to the client

// Log errors to a file (for debugging purposes)
ini_set('log_errors', 1);
ini_set('error_log', 'php-error.log');

// Set content type to JSON
header('Content-Type: application/json');

// SQL query to get facilitator data
$sql = "SELECT * FROM material_forms";

$result = $conn->query($sql);

// Initialize an array to store the data
$material_forms = array();

// Check if any data is returned
if ($result->num_rows > 0) {
    // Fetch all rows and store them in the array
    while ($row = $result->fetch_assoc()) {
        $material_forms[] = $row;
    }
    // Return the data as JSON
    echo json_encode($material_forms);
} else {
    // Return empty array if no data found
    echo json_encode([]);
}

// Close the database connection
$conn->close();
?>
