<?php
include 'connection.php';

// Query the database to fetch clocking data
$query = "SELECT * FROM learner_clocking";
$stmt = $conn->prepare($query);

if ($stmt) {
    $stmt->execute();
    $result = $stmt->get_result(); // Get the result of the query

    // Fetch all the data as an associative array
    $clockingData = [];
    while ($row = $result->fetch_assoc()) {
        $clockingData[] = $row;
    }

    // Return the clocking data as a JSON response
    echo json_encode($clockingData);

    // Close the statement
    $stmt->close();
} else {
    // Error handling if the query fails
    echo json_encode(['error' => 'Failed to retrieve clocking data']);
}

// Close the connection
$conn->close();
?>
