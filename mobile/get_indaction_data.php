<?php
header('Content-Type: application/json');
include 'connection.php';

$response = array("success" => false, "message" => "Unknown error occurred");

if ($_SERVER["REQUEST_METHOD"] == "GET") {
    $learnerID = $_GET['LearnerID'] ?? null;
    $clockDate = $_GET['clock_date'] ?? date('Y-m-d');

    if ($learnerID) {
        $stmt = $conn->prepare("SELECT clock_in_time, clock_out_time, contact_time FROM induction_clocking WHERE LearnerID = ? AND clock_date = ?");
        $stmt->bind_param("is", $learnerID, $clockDate);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            $row = $result->fetch_assoc();
            $response['success'] = true;
            $response['clock_in_time'] = $row['clock_in_time'];
            $response['clock_out_time'] = $row['clock_out_time'];
            $response['contact_time'] = $row['contact_time'];
        } else {
            $response['message'] = 'No clocking data found for the specified learner and date.';
        }
        $stmt->close();
    } else {
        $response['message'] = 'LearnerID is required.';
    }
} else {
    $response['message'] = 'Invalid request method.';
}

$conn->close();
echo json_encode($response);
?>