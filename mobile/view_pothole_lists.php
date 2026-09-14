<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

// Get query parameters
$learner_id = isset($_GET['learner_id']) ? $_GET['learner_id'] : '';
$assessor_id = isset($_GET['assessor_id']) ? $_GET['assessor_id'] : '';
$assessment_date = isset($_GET['assessment_date']) ? $_GET['assessment_date'] : '';

// Validate required learner_id
if (empty($learner_id)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing required parameter: learner_id is required'
    ]);
    exit();
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8mb4");
    
    // Build query based on provided parameters
    $sql = "SELECT * FROM pothole_checklists WHERE learner_id = ?";
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
    
    $sql .= " ORDER BY assessment_date DESC LIMIT 1";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        
        // Parse checklist items JSON (stored as flat array from save endpoint)
        $checklist_items_raw = json_decode($row['checklist_items'], true);
        
        // Organize items by section for Flutter to consume
        $organized_items = [];
        if (is_array($checklist_items_raw)) {
            foreach ($checklist_items_raw as $item) {
                $section = isset($item['section']) ? $item['section'] : 'Unknown';
                if (!isset($organized_items[$section])) {
                    $organized_items[$section] = [];
                }
                $organized_items[$section][] = [
                    'label' => isset($item['label']) ? $item['label'] : '',
                    'value' => isset($item['value']) ? $item['value'] : true,
                    'notes' => isset($item['notes']) ? $item['notes'] : ''
                ];
            }
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => [
                'id' => $row['id'],
                'learner_id' => $row['learner_id'],
                'learner_name' => $row['learner_name'],
                'learner_id_number' => isset($row['learner_id_number']) ? $row['learner_id_number'] : '',
                'assessor_id' => $row['assessor_id'],
                'assessor_name' => $row['assessor_name'],
                'assessor_reg_number' => isset($row['assessor_reg_number']) ? $row['assessor_reg_number'] : '',
                'venue' => $row['venue'],
                'assessment_date' => $row['assessment_date'],
                'learner_signature' => isset($row['learner_signature']) ? $row['learner_signature'] : '',
                'assessor_signature' => isset($row['assessor_signature']) ? $row['assessor_signature'] : '',
                'checklist_items' => $organized_items,
                'created_at' => isset($row['created_at']) ? $row['created_at'] : '',
                'updated_at' => isset($row['updated_at']) ? $row['updated_at'] : ''
            ]
        ]);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'No checklist found for the specified parameters'
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
