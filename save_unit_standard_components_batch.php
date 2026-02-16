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
    
    $components = $input['components'] ?? [];
    
    if (empty($components) || !is_array($components)) {
        echo json_encode([
            'success' => false,
            'error' => 'components array is required'
        ]);
        exit();
    }
    
    $conn->autocommit(false); // Start transaction
    
    $valid_types = ['Formative', 'Summative', 'Learner Guide'];
    $saved_count = 0;
    
    foreach ($components as $component) {
        $class_id = $component['class_id'] ?? '';
        $unit_standard_id = $component['unit_standard_id'] ?? '';
        $component_type = $component['component_type'] ?? '';
        $quantity = intval($component['quantity'] ?? 0);
        $facilitator_id = $component['facilitator_id'] ?? '';
        $representative_name = $component['representative_name'] ?? '';
        
        if (empty($class_id) || empty($unit_standard_id) || empty($component_type)) {
            continue; // Skip invalid entries
        }
        
        if (!in_array($component_type, $valid_types)) {
            continue; // Skip invalid component types
        }
        
        // Use INSERT ... ON DUPLICATE KEY UPDATE
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
            $saved_count++;
        }
        
        $stmt->close();
    }
    
    $conn->commit(); // Commit transaction
    $conn->close();
    
    echo json_encode([
        'success' => true,
        'message' => "Successfully saved $saved_count components",
        'saved_count' => $saved_count
    ]);
    
} catch (Exception $e) {
    if (isset($conn)) {
        $conn->rollback(); // Rollback on error
        $conn->close();
    }
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}
?>