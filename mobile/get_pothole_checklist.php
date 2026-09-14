<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Database configuration
include('connection.php');

$mysqli = new mysqli($host, $username, $password, $database);
if ($mysqli->connect_error) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database connection failed: ' . $mysqli->connect_error]);
    exit;
}
$mysqli->set_charset('utf8mb4');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit;
}

try {
    $learner_id = $_GET['learner_id'] ?? '';
    $assessor_id = $_GET['assessor_id'] ?? '';
    $assessment_date = $_GET['assessment_date'] ?? '';
    
    if (empty($learner_id) || empty($assessor_id) || empty($assessment_date)) {
        throw new Exception('Missing required parameters: learner_id, assessor_id, assessment_date');
    }
    
    // Get checklist data
    $checklist_query = $mysqli->prepare("
        SELECT * FROM pothole_checklists 
        WHERE learner_id = ? AND assessor_id = ? AND assessment_date = ?
    ");
    $checklist_query->bind_param('sss', $learner_id, $assessor_id, $assessment_date);
    $checklist_query->execute();
    $result = $checklist_query->get_result();
    $checklist = $result->fetch_assoc();
    
    if (!$checklist) {
        echo json_encode([
            'status' => 'success',
            'data' => null,
            'message' => 'No existing checklist found'
        ]);
        exit;
    }
    
    // Get checklist items
    $items_query = $mysqli->prepare("
        SELECT section_name, item_label, item_value, notes 
        FROM pothole_checklist_items 
        WHERE checklist_id = ? 
        ORDER BY section_name, id
    ");
    $items_query->bind_param('i', $checklist['id']);
    $items_query->execute();
    $items_result = $items_query->get_result();
    $items = $items_result->fetch_all(MYSQLI_ASSOC);
    
    // Organize items by section
    $organized_items = [];
    foreach ($items as $item) {
        $section = $item['section_name'];
        if (!isset($organized_items[$section])) {
            $organized_items[$section] = [];
        }
        $organized_items[$section][] = [
            'label' => $item['item_label'],
            'value' => $item['item_value'],
            'notes' => $item['notes']
        ];
    }
    
    // Prepare response
    $response_data = [
        'checklist_id' => $checklist['id'],
        'learner_id' => $checklist['learner_id'],
        'learner_name' => $checklist['learner_name'],
        'learner_id_number' => $checklist['learner_id_number'],
        'assessor_id' => $checklist['assessor_id'],
        'assessor_name' => $checklist['assessor_name'],
        'assessor_reg_number' => $checklist['assessor_reg_number'],
        'venue' => $checklist['venue'],
        'assessment_date' => $checklist['assessment_date'],
        'learner_signature' => $checklist['learner_signature'],
        'assessor_signature' => $checklist['assessor_signature'],
        'status' => $checklist['status'],
        'created_at' => $checklist['created_at'],
        'updated_at' => $checklist['updated_at'],
        'checklist_items' => $organized_items
    ];
    
    echo json_encode([
        'status' => 'success',
        'data' => $response_data
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$mysqli->close();
?>