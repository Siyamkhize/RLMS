<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include('connection.php');

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8mb4");
    
    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        echo json_encode([
            'success' => false,
            'error' => 'Invalid JSON input'
        ]);
        exit();
    }
    
    $class_id = $input['class_id'] ?? '';
    $unit_standard_id = $input['unit_standard_id'] ?? '';
    $component_type = $input['component_type'] ?? '';
    $quantity = intval($input['quantity'] ?? 0);
    $facilitator_id = $input['facilitator_id'] ?? '';
    $representative_name = $input['representative_name'] ?? '';
    
    if (empty($class_id) || empty($unit_standard_id) || empty($component_type)) {
        echo json_encode([
            'success' => false,
            'error' => 'class_id, unit_standard_id, and component_type are required'
        ]);
        exit();
    }
    
    // Validate component_type
    $valid_types = ['Formative', 'Summative', 'Learner Guide'];
    if (!in_array($component_type, $valid_types)) {
        echo json_encode([
            'success' => false,
            'error' => 'Invalid component_type. Must be: ' . implode(', ', $valid_types)
        ]);
        exit();
    }
    
    // Use INSERT ... ON DUPLICATE KEY UPDATE to handle both insert and update
    $query = "INSERT INTO unit_standard_sub_components 
              (class_id, unit_standard_id, component_type, quantity, facilitator_id, representative_name) 
              VALUES (?, ?, ?, ?, ?, ?)
              ON DUPLICATE KEY UPDATE 
              quantity = VALUES(quantity),
              facilitator_id = VALUES(facilitator_id),
              representative_name = VALUES(representative_name),
              updated_at = CURRENT_TIMESTAMP";
    
    $stmt = $conn->prepare($query);
    $stmt->bind_param('sssiss', $class_id, $unit_standard_id, $component_type, $quantity, $facilitator_id, $representative_name);
    
    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'Component saved successfully'
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'error' => 'Failed to save component: ' . $stmt->error
        ]);
    }
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    if (isset($conn)) {
        $conn->close();
    }
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}
?>