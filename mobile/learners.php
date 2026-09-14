<?php
include('connection.php'); // Ensure your database connection is included
header('Content-Type: application/json'); // Set the content type to JSON
header('Access-Control-Allow-Origin: *'); // Allow cross-origin requests

// Get the selected class name from the request (assuming you pass it via GET)
$classID = $_GET['classID'] ?? ''; // Use classID for the query

$response = [];

// Prepared SQL query to get learner details along with clocking information
$sql = "SELECT ld.LearnerID, ld.Name, ld.Surname, lc.clock_in_time, lc.clock_out_time, lc.contact_time
        FROM learnerdetails ld
        LEFT JOIN learner_clocking lc ON ld.LearnerID = lc.LearnerID
        WHERE ld.classID = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param('s', $classID);
$stmt->execute();
$result = $stmt->get_result();

if ($result && $result->num_rows > 0) {
    // Fetch all rows and prepare the response
    while ($row = $result->fetch_assoc()) {
        $response[] = [
            'LearnerID' => $row['LearnerID'],
            'Name' => $row['Name'],
            'Surname' => $row['Surname'],
            'ClockIn' => !empty($row['clock_in_time']) ? $row['clock_in_time'] : 'N/A',
            'ClockOut' => !empty($row['clock_out_time']) ? $row['clock_out_time'] : 'N/A',
            'ContactTime' => !empty($row['contact_time']) ? $row['contact_time'] : 'N/A',
            'ViewLink' => "learnerView.php?LearnerID=" . urlencode($row['LearnerID']) // Generate view link
        ];
    }
    // Return success response with data
    echo json_encode([
        'success' => true,
        'learners' => $response,
        'message' => 'Data retrieved successfully.'
    ]);
} else {
    // No results found
    echo json_encode([
        'success' => false,
        'message' => 'No results found.'
    ]);
}

// Close the database connection
$stmt->close();
$conn->close();
?>
