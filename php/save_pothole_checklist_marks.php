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
$required_fields = ['learner_id', 'assessor_id', 'assessment_date', 'marks'];
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
    $assessor_id = $conn->real_escape_string($data['assessor_id']);
    $assessment_date = $conn->real_escape_string($data['assessment_date']);
    $marks = intval($data['marks']);
    $comments = isset($data['comments']) ? $conn->real_escape_string($data['comments']) : '';
    
    // Validate marks range
    if ($marks < 0 || $marks > 100) {
        throw new Exception("Marks must be between 0 and 100");
    }
    
    // Insert or update marks
    $sql = "INSERT INTO pothole_checklist_marks 
            (learner_id, assessor_id, assessment_date, marks, comments)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
            marks = VALUES(marks),
            comments = VALUES(comments),
            updated_at = CURRENT_TIMESTAMP";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param(
        "sssis",
        $learner_id,
        $assessor_id,
        $assessment_date,
        $marks,
        $comments
    );
    
    if ($stmt->execute()) {
        echo json_encode([
            'status' => 'success',
            'message' => 'Marks saved successfully',
            'marks_id' => $stmt->insert_id > 0 ? $stmt->insert_id : $conn->insert_id
        ]);
    } else {
        throw new Exception("Error saving marks: " . $stmt->error);
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
