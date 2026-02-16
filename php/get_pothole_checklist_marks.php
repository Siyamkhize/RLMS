<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'config.php';

// Get query parameters
$learner_id = isset($_GET['learner_id']) ? $_GET['learner_id'] : '';
$assessor_id = isset($_GET['assessor_id']) ? $_GET['assessor_id'] : '';
$assessment_date = isset($_GET['assessment_date']) ? $_GET['assessment_date'] : '';

// Validate required parameters
if (empty($learner_id) || empty($assessor_id) || empty($assessment_date)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing required parameters: learner_id, assessor_id, and assessment_date are required'
    ]);
    exit();
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8mb4");
    
    // Prepare and execute query
    $sql = "SELECT * FROM pothole_checklist_marks 
            WHERE learner_id = ? AND assessor_id = ? AND assessment_date = ?
            LIMIT 1";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sss", $learner_id, $assessor_id, $assessment_date);
    $stmt->execute();
    
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        
        echo json_encode([
            'status' => 'success',
            'data' => [
                'id' => $row['id'],
                'learner_id' => $row['learner_id'],
                'assessor_id' => $row['assessor_id'],
                'assessment_date' => $row['assessment_date'],
                'marks' => intval($row['marks']),
                'comments' => $row['comments'],
                'approval_status' => $row['approval_status'] ?? null,
                'comment' => $row['comment'] ?? null,
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at']
            ]
        ]);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'No marks found for the specified parameters'
        ]);
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
