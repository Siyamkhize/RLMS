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

$learner_id = isset($_GET['learner_id']) ? $_GET['learner_id'] : '';
$assessor_id = isset($_GET['assessor_id']) ? $_GET['assessor_id'] : '';
$assessment_date = isset($_GET['assessment_date']) ? $_GET['assessment_date'] : '';

if (empty($learner_id)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing required parameter: learner_id'
    ]);
    exit();
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8mb4");
    
    $sql = "SELECT unit_standard_id, marks 
            FROM logbook_marks 
            WHERE learner_id = ?";
    
    $params = [$learner_id];
    $types = "s";
    
    if (!empty($assessor_id)) {
        $sql .= " AND assessor_id = ?";
        $params[] = $assessor_id;
        $types .= "s";
    }
    
    if (!empty($assessment_date)) {
        $sql .= " AND assessment_date = ?";
        $params[] = $assessment_date;
        $types .= "s";
    }
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $marks = [];
    while ($row = $result->fetch_assoc()) {
        $marks[$row['unit_standard_id']] = $row['marks'];
    }
    
    $stmt->close();
    $conn->close();
    
    echo json_encode([
        'status' => 'success',
        'data' => $marks
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
