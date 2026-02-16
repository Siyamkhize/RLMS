<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
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
    
    // Get parameters
    $class_id = $_GET['class_id'] ?? $_POST['class_id'] ?? '';
    $unit_standard_id = $_GET['unit_standard_id'] ?? $_POST['unit_standard_id'] ?? '';
    
    if (empty($class_id)) {
        echo json_encode([
            'success' => false,
            'error' => 'class_id is required'
        ]);
        exit();
    }
    
    // If unit_standard_id is provided, get specific unit standard components
    if (!empty($unit_standard_id)) {
        $query = "SELECT * FROM unit_standard_sub_components 
                  WHERE class_id = ? AND unit_standard_id = ?
                  ORDER BY component_type";
        $stmt = $conn->prepare($query);
        $stmt->bind_param('ss', $class_id, $unit_standard_id);
    } else {
        // Get all components for the class
        $query = "SELECT * FROM unit_standard_sub_components 
                  WHERE class_id = ?
                  ORDER BY unit_standard_id, component_type";
        $stmt = $conn->prepare($query);
        $stmt->bind_param('s', $class_id);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $components = [];
    while ($row = $result->fetch_assoc()) {
        $components[] = $row;
    }
    
    $stmt->close();
    $conn->close();
    
    echo json_encode([
        'success' => true,
        'components' => $components
    ]);
    
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