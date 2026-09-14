<?php
include 'connection.php';

// Suppress PHP errors and warnings in the response
error_reporting(0); // Turn off error reporting for users
ini_set('display_errors', 0); // Disable displaying errors to the client

// Set content type to JSON
header('Content-Type: application/json');

// Query the database to fetch material receipt form data
$query = "SELECT * FROM material_receipt_form";
$stmt = $conn->prepare($query);

try {
    // Execute the statement
    $stmt->execute();
    
    // Get the result
    $result = $stmt->get_result();
    
    // Fetch the received data as an associative array
    $received = [];
    while ($row = $result->fetch_assoc()) {
        $received[] = $row;
    }

    // Return the received data as a JSON response
    echo json_encode(['status' => 'success', 'data' => $received]);
} catch (Exception $e) {
    // Handle database query failure
    echo json_encode(['status' => 'error', 'message' => 'Failed to retrieve data']);
}

// Close the statement
$stmt->close();

// Close the connection
$conn->close();
?>
