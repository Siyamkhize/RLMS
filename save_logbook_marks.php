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

$input = json_decode(file_get_contents('php://input'), true);

$learner_id = isset($input['learner_id']) ? $input['learner_id'] : '';
$assessor_id = isset($input['assessor_id']) ? $input['assessor_id'] : '';
$assessment_date = isset($input['assessment_date']) ? $input['assessment_date'] : '';
$unit_standards_marks = isset($input['unit_standards_marks']) ? $input['unit_standards_marks'] : [];

if (empty($learner_id) || empty($assessor_id) || empty($assessment_date) || empty($unit_standards_marks)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing required fields'
    ]);
    exit();
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8mb4");
    $conn->begin_transaction();
    
    $sql = "INSERT INTO logbook_marks 
            (learner_id, unit_standard_id, assessor_id, marks, assessment_date)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE marks = VALUES(marks), updated_at = NOW()";
    
    $stmt = $conn->prepare($sql);
    
    // $unit_standards_marks is an array of objects: [{unit_standard_id: "123", marks: 85}, ...]
    foreach ($unit_standards_marks as $item) {
        $unit_standard_id = $item['unit_standard_id'];
        $mark_value = $item['marks'];
        
        if ($mark_value < 0 || $mark_value > 100) {
            throw new Exception("Marks must be between 0 and 100 for unit standard $unit_standard_id");
        }
        
        $stmt->bind_param("sssis", $learner_id, $unit_standard_id, $assessor_id, $mark_value, $assessment_date);
        $stmt->execute();
    }
    
    $stmt->close();
    $conn->commit();
    $conn->close();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'LogBook marks saved successfully'
    ]);
    
} catch (Exception $e) {
    if (isset($conn)) {
        $conn->rollback();
        $conn->close();
    }
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
