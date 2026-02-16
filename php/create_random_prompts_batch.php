<?php
// create_random_prompts_batch.php - Create random prompts for multiple learners who are currently clocked in
header('Content-Type: application/json');
date_default_timezone_set('Africa/Johannesburg');

include 'connection.php';

$response = array("success" => false, "message" => "Unknown error occurred", "created" => array(), "skipped" => array());

try {
    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        $class_id = isset($_POST['class_id']) ? $_POST['class_id'] : null;
        $num_prompts = isset($_POST['num_prompts']) ? intval($_POST['num_prompts']) : 3; // Default 3 random learners
        $countdown_duration = isset($_POST['countdown_duration']) ? intval($_POST['countdown_duration']) : 180;
        
        // Get all learners currently clocked in
        $today = date('Y-m-d');
        $query = "SELECT DISTINCT lc.LearnerID, ld.firstName, ld.lastName 
                  FROM learner_clocking lc
                  JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID
                  WHERE lc.clock_date = ? 
                  AND lc.clock_in_time IS NOT NULL 
                  AND lc.clock_out_time IS NULL";
        
        $params = array($today);
        $types = "s";
        
        if (!empty($class_id)) {
            $query .= " AND ld.classID = ?";
            $params[] = $class_id;
            $types .= "s";
        }
        
        $stmt = $conn->prepare($query);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $clocked_in_learners = array();
        while ($row = $result->fetch_assoc()) {
            // Check if they already have a pending prompt
            $check_stmt = $conn->prepare("SELECT monitoring_id FROM monitoring WHERE learner_id = ? AND status = 'pending'");
            $check_stmt->bind_param("i", $row['LearnerID']);
            $check_stmt->execute();
            $check_result = $check_stmt->get_result();
            
            if ($check_result->num_rows == 0) {
                $clocked_in_learners[] = $row;
            } else {
                $response['skipped'][] = array(
                    'learner_id' => $row['LearnerID'],
                    'name' => $row['firstName'] . ' ' . $row['lastName'],
                    'reason' => 'Already has pending prompt'
                );
            }
            $check_stmt->close();
        }
        $stmt->close();
        
        if (count($clocked_in_learners) == 0) {
            $response['message'] = "No eligible learners found (all either not clocked in or have pending prompts)";
            $response['success'] = true;
            echo json_encode($response);
            exit;
        }
        
        // Randomly select learners
        shuffle($clocked_in_learners);
        $selected_learners = array_slice($clocked_in_learners, 0, min($num_prompts, count($clocked_in_learners)));
        
        // Create prompts for selected learners
        $prompt_time = date('Y-m-d H:i:s');
        $prompt_type = 'random_biometric';
        
        foreach ($selected_learners as $learner) {
            $stmt = $conn->prepare("INSERT INTO monitoring (learner_id, prompt_type, prompt_time, countdown_duration, status) VALUES (?, ?, ?, ?, 'pending')");
            $stmt->bind_param("issi", $learner['LearnerID'], $prompt_type, $prompt_time, $countdown_duration);
            
            if ($stmt->execute()) {
                $monitoring_id = $conn->insert_id;
                $response['created'][] = array(
                    'monitoring_id' => $monitoring_id,
                    'learner_id' => $learner['LearnerID'],
                    'name' => $learner['firstName'] . ' ' . $learner['lastName'],
                    'prompt_time' => $prompt_time,
                    'countdown_duration' => $countdown_duration
                );
            } else {
                $response['skipped'][] = array(
                    'learner_id' => $learner['LearnerID'],
                    'name' => $learner['firstName'] . ' ' . $learner['lastName'],
                    'reason' => 'Database error: ' . $stmt->error
                );
            }
            $stmt->close();
        }
        
        $response['success'] = true;
        $response['message'] = "Created " . count($response['created']) . " random prompts";
        $response['total_eligible'] = count($clocked_in_learners);
        
    } else {
        $response['message'] = "Invalid request method";
    }
} catch (Exception $e) {
    $response['message'] = "Error: " . $e->getMessage();
}

echo json_encode($response);
$conn->close();
?>

