<?php 
include 'connection.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Initialize response array
$response = [];

// Query to fetch material forms data
$query = "SELECT * FROM material_forms";
$stmt = $conn->prepare($query);

if ($stmt) {
    // Execute the query
    $stmt->execute();
    $result = $stmt->get_result(); // Get the result set

    // Check if any records were fetched
    if ($result->num_rows > 0) {
        // Fetch all records into an associative array
        $materialForms = [];
        while ($row = $result->fetch_assoc()) {
            $materialForms[] = $row;
        }

        // Set success response with data
        $response['success'] = true;
        $response['data'] = $materialForms;
    } else {
        // No records found, send empty data response
        $response['success'] = false;
        $response['message'] = 'No material forms found';
    }

    // Close the statement
    $stmt->close();
} else {
    // Handle query failure
    $response['success'] = false;
    $response['error'] = 'Failed to retrieve material forms data';
    error_log("Query failed: " . $conn->error);
}

// Close the database connection
$conn->close();

// Send the JSON response
echo json_encode($response, JSON_PRETTY_PRINT);
?>
