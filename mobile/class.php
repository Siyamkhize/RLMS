<?php
include('connection.php'); // Include the database connection

error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: application/json'); // Set the content type to JSON
header('Access-Control-Allow-Origin: *'); // Allow cross-origin requests
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Get the siteID from the POST request
$siteID = $_POST['siteID'] ?? '';

$response = [];

// Debugging: Log the received siteID
error_log("Received siteID: $siteID");

// Check if siteID is provided
if (!empty($siteID)) {
    // SQL query to select data from the class table using a prepared statement
    $sql = "SELECT DISTINCT classID, className FROM class WHERE siteID = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('s', $siteID); // Bind the siteID parameter
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result && $result->num_rows > 0) {
        $classDetails = [];
        while ($row = $result->fetch_assoc()) {
            $classID = $row["classID"];

            // Count the total number of learners in the class using a prepared statement
            $countQuery = "SELECT COUNT(LearnerID) AS learner_count FROM learnerdetails WHERE classID = ?";
            $countStmt = $conn->prepare($countQuery);
            $countStmt->bind_param('s', $classID);
            $countStmt->execute();
            $countResult = $countStmt->get_result();
            $learnerCount = $countResult->fetch_assoc()["learner_count"] ?? 0;

            // Fetch clocking details from learner_clocking table using a prepared statement
            $clockingQuery = "
                SELECT 
                    COUNT(DISTINCT learnerID) AS learners_clocked_in,
                    COUNT(DISTINCT CASE WHEN clock_out_time != '00:00:00' AND clock_in_time IS NOT NULL THEN learnerID END) AS learners_clocked_out
                FROM learner_clocking
                WHERE learnerID IN (
                    SELECT learnerID FROM learnerdetails WHERE classID = ?
                ) AND clock_date = CURDATE();
            ";
            $clockingStmt = $conn->prepare($clockingQuery);
            $clockingStmt->bind_param('s', $classID);
            $clockingStmt->execute();
            $clockingResult = $clockingStmt->get_result();
            $clockingRow = $clockingResult->fetch_assoc() ?? ["learners_clocked_in" => 0, "learners_clocked_out" => 0];
            $learnersClockedIn = $clockingRow['learners_clocked_in'];
            $learnersClockedOut = $clockingRow['learners_clocked_out'];
            $learnersAbsent = $learnerCount - $learnersClockedIn;

            // Add the class details to the response array
            $classDetails[] = [
                "className" => $row["className"],
                "learnerCount" => $learnerCount,
                "learnersClockedIn" => $learnersClockedIn,
                "learnersClockedOut" => $learnersClockedOut,
                "learnersAbsent" => $learnersAbsent,
                "classID" => $classID,
            ];
        }
        
        // Return success response with class details
        echo json_encode([
            'success' => true,
            'classDetails' => $classDetails,
            'message' => 'Data retrieved successfully.'
        ]);
    } else {
        // No classes found
        echo json_encode([
            'success' => false,
            'message' => 'No classes found for the provided siteID.'
        ]);
    }

    // Close the prepared statement
    $stmt->close();
} else {
    // Invalid siteID
    echo json_encode([
        'success' => false,
        'message' => 'Invalid siteID.'
    ]);
}

// Close the database connection
$conn->close();
?>
