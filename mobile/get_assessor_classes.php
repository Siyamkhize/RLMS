<?php
include('connection.php'); // Include database connection
header('Content-Type: application/json'); // Set response type to JSON

try {
    // Validate facilitator_id
    if (!isset($_GET['facilitator_id'])) {
        echo json_encode([
            "status" => "error",
            "message" => "facilitator_id is required"
        ]);
        exit;
    }

    // Sanitize and validate facilitator_id
    $facilitator_id = filter_var($_GET['facilitator_id'], FILTER_VALIDATE_INT);
    if ($facilitator_id === false) {
        echo json_encode([
            "status" => "error",
            "message" => "Invalid facilitator_id"
        ]);
        exit;
    }

    // Prepare SQL query to fetch classes
    $query = "
        SELECT s.project_id, c.* 
        FROM class c
        JOIN sites s ON s.siteID = c.siteID
        JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
        WHERE f.facilitator_id = ?
    ";

    // Execute the query
    $stmt = $conn->prepare($query);
    $stmt->bind_param("i", $facilitator_id);
    $stmt->execute();
    $result = $stmt->get_result();

    // Fetch classes
    $classes = [];
    while ($row = $result->fetch_assoc()) {
        $classes[] = $row;
    }

    // Return response
    if (empty($classes)) {
        echo json_encode([
            "status" => "success",
            "message" => "No classes found for the given facilitator_id",
            "data" => []
        ]);
    } else {
        echo json_encode([
            "status" => "success",
            "message" => "Classes retrieved successfully",
            "data" => $classes
        ], JSON_PRETTY_PRINT);
    }

    // Close connections
    $stmt->close();
    $conn->close();
} catch (Exception $e) {
    // Handle exceptions
    echo json_encode([
        "status" => "error",
        "message" => "An error occurred: " . $e->getMessage()
    ]);
}
?>