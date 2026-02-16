<?php
// update_monitoring_status.php - Update monitoring prompt status after verification
header('Content-Type: application/json');
date_default_timezone_set('Africa/Johannesburg');

include 'connection.php';

$response = array("success" => false, "message" => "Unknown error occurred");

try {
    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        $monitoring_id = isset($_POST['monitoring_id']) ? intval($_POST['monitoring_id']) : null;
        $status = isset($_POST['status']) ? $_POST['status'] : null;
        $response_time = isset($_POST['response_time']) ? $_POST['response_time'] : null;
        
        if (empty($monitoring_id)) {
            $response['message'] = "Monitoring ID is required";
            echo json_encode($response);
            exit;
        }
        
        if (empty($status) || !in_array($status, ['completed', 'failed', 'timeout'])) {
            $response['message'] = "Valid status is required (completed, failed, or timeout)";
            echo json_encode($response);
            exit;
        }
        
        // Check if monitoring prompt exists and is pending
        $stmt = $conn->prepare("SELECT monitoring_id, learner_id, prompt_time FROM monitoring WHERE monitoring_id = ?");
        $stmt->bind_param("i", $monitoring_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows == 0) {
            $response['message'] = "Monitoring prompt not found";
            echo json_encode($response);
            exit;
        }
        
        $monitoring = $result->fetch_assoc();
        $stmt->close();
        
        // Update the monitoring status
        $verification_time = date('Y-m-d H:i:s');
        $verification_method = 'fingerprint';
        
        $stmt = $conn->prepare("UPDATE monitoring SET status = ?, verification_time = ?, verification_method = ?, response_time = ? WHERE monitoring_id = ?");
        $stmt->bind_param("ssssi", $status, $verification_time, $verification_method, $response_time, $monitoring_id);
        
        if ($stmt->execute()) {
            $response['success'] = true;
            $response['message'] = "Monitoring status updated successfully";
            $response['status'] = $status;
            $response['verification_time'] = $verification_time;
            $response['learner_id'] = $monitoring['learner_id'];
        } else {
            $response['message'] = "Failed to update monitoring status: " . $stmt->error;
        }
        $stmt->close();
        
    } else {
        $response['message'] = "Invalid request method";
    }
} catch (Exception $e) {
    $response['message'] = "Error: " . $e->getMessage();
}

echo json_encode($response);
$conn->close();
?>

