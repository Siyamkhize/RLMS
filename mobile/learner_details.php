<?php
include 'connection.php';
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Initialize response array
$response = [
    "success" => false,
    "data" => null,
    "message" => ""
];

// Check if the database connection is successful
if ($conn->connect_error) {
    $response["message"] = "Database connection failed: " . $conn->connect_error;
    echo json_encode($response);
    exit;
}

// Get the learnerID from the GET request and sanitize it
$learnerID = isset($_GET['LearnerID']) ? htmlspecialchars($_GET['LearnerID'], ENT_QUOTES, 'UTF-8') : '';

if ($learnerID) {
    // Prepare SQL to fetch learner details and their bank details
    $sql = "SELECT * FROM learnerdetails 
           
            WHERE LearnerID = ?";
    $stmt = $conn->prepare($sql);

    // Check if the statement was prepared successfully
    if ($stmt) {
        $stmt->bind_param("s", $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();

        // Check if any records were found
        if ($result->num_rows > 0) {
            $learnerData = $result->fetch_assoc();
            $response["success"] = true;
            $response["data"] = $learnerData;
        } else {
            $response["message"] = "No records found";
        }
        $stmt->close();
    } else {
        $response["message"] = "SQL statement preparation failed: " . $conn->error;
    }
} else {
    $response["message"] = "LearnerID not set";
}

// Close the database connection
$conn->close();

// Output the response
echo json_encode($response);
?>
