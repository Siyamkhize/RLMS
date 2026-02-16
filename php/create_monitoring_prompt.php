<?php
// create_monitoring_prompt.php - Create random biometric prompts for learners
header('Content-Type: application/json');
date_default_timezone_set('Africa/Johannesburg');

include 'connection.php';

$response = array("success" => false, "message" => "Unknown error occurred");

try {
    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        $learner_id = isset($_POST['learner_id']) ? intval($_POST['learner_id']) : null;
        $prompt_type = isset($_POST['prompt_type']) ? $_POST['prompt_type'] : 'random_biometric';
        $countdown_duration = isset($_POST['countdown_duration']) ? intval($_POST['countdown_duration']) : 180; // 3 minutes default
        
        if (empty($learner_id)) {
            $response['message'] = "Learner ID is required";
            echo json_encode($response);
            exit;
        }
        
        // Check if learner exists
        $stmt = $conn->prepare("SELECT LearnerID FROM learnerdetails WHERE LearnerID = ?");
        $stmt->bind_param("i", $learner_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows == 0) {
            $response['message'] = "Learner not found";
            echo json_encode($response);
            exit;
        }
        $stmt->close();
        
        // Check if learner is currently clocked in
        $today = date('Y-m-d');
        $stmt = $conn->prepare("SELECT LearnerID FROM learner_clocking WHERE LearnerID = ? AND clock_date = ? AND clock_in_time IS NOT NULL AND clock_out_time IS NULL");
        $stmt->bind_param("is", $learner_id, $today);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows == 0) {
            $response['message'] = "Learner is not currently clocked in";
            echo json_encode($response);
            exit;
        }
        $stmt->close();
        
        // Check if there's already a pending prompt for this learner
        $stmt = $conn->prepare("SELECT monitoring_id FROM monitoring WHERE learner_id = ? AND status = 'pending'");
        $stmt->bind_param("i", $learner_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            $response['message'] = "Learner already has a pending prompt";
            $response['has_pending'] = true;
            echo json_encode($response);
            exit;
        }
        $stmt->close();
        
        // Create the monitoring prompt
        $prompt_time = date('Y-m-d H:i:s');
        $stmt = $conn->prepare("INSERT INTO monitoring (learner_id, prompt_type, prompt_time, countdown_duration, status) VALUES (?, ?, ?, ?, 'pending')");
        $stmt->bind_param("issi", $learner_id, $prompt_type, $prompt_time, $countdown_duration);
        
        if ($stmt->execute()) {
            $monitoring_id = $conn->insert_id;
            $response['success'] = true;
            $response['message'] = "Monitoring prompt created successfully";
            $response['monitoring_id'] = $monitoring_id;
            $response['prompt_time'] = $prompt_time;
            $response['countdown_duration'] = $countdown_duration;
        } else {
            $response['message'] = "Failed to create monitoring prompt: " . $stmt->error;
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

