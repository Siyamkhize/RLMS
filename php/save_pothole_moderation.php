<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'config.php';

// Get JSON input
$input = file_get_contents('php://input');
$data = json_decode($input, true);

// Validate required fields
$required_fields = ['learner_id', 'assessment_date', 'approval_status'];
foreach ($required_fields as $field) {
    if (!isset($data[$field])) {
        echo json_encode([
            'status' => 'error',
            'message' => "Missing required field: $field"
        ]);
        exit();
    }
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8mb4");
    
    // Prepare data
    $learner_id = $conn->real_escape_string($data['learner_id']);
    $assessment_date = $conn->real_escape_string($data['assessment_date']);
    $approval_status = $conn->real_escape_string($data['approval_status']);
    $comment = isset($data['comment']) ? $conn->real_escape_string($data['comment']) : '';
    
    // Validate approval_status
    if (!in_array($approval_status, ['Approved', 'Disapproved'])) {
        throw new Exception("Invalid approval status. Must be 'Approved' or 'Disapproved'");
    }
    
    // Update the marks table with approval_status and comment
    // Note: We're updating the pothole_checklist_marks table, not the general marks table
    $sql = "UPDATE pothole_checklist_marks 
            SET approval_status = ?, 
                comment = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE learner_id = ? 
            AND assessment_date = ?";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param(
        "ssss",
        $approval_status,
        $comment,
        $learner_id,
        $assessment_date
    );
    
    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            echo json_encode([
                'status' => 'success',
                'message' => 'Moderation saved successfully',
                'affected_rows' => $stmt->affected_rows
            ]);
        } else {
            // No rows affected - check if record exists
            $check_sql = "SELECT id FROM pothole_checklist_marks 
                         WHERE learner_id = ? AND assessment_date = ?";
            $check_stmt = $conn->prepare($check_sql);
            $check_stmt->bind_param("ss", $learner_id, $assessment_date);
            $check_stmt->execute();
            $check_result = $check_stmt->get_result();
            
            if ($check_result->num_rows === 0) {
                throw new Exception("No marks record found for this learner and assessment date");
            } else {
                // Record exists but no changes made (probably same values)
                echo json_encode([
                    'status' => 'success',
                    'message' => 'Moderation status unchanged (same values)',
                    'affected_rows' => 0
                ]);
            }
            $check_stmt->close();
        }
    } else {
        throw new Exception("Error updating moderation: " . $stmt->error);
    }
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
