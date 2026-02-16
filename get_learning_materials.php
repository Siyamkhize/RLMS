<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once 'connection.php';

// Handle OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$category = isset($_GET['category']) ? $_GET['category'] : '';
$unit_standard_id = isset($_GET['unit_standard_id']) ? $_GET['unit_standard_id'] : '';

try {
    // Build query based on filters
    $query = "
        SELECT 
            id,
            material_name,
            material_code,
            unit_standard_id,
            unit_standard_name,
            description,
            category,
            stock_quantity,
            minimum_stock,
            unit_of_measure,
            created_at,
            updated_at
        FROM learning_materials
        WHERE 1=1
    ";
    
    $params = [];
    $types = "";
    
    if (!empty($category)) {
        $query .= " AND category = ?";
        $params[] = $category;
        $types .= "s";
    }
    
    if (!empty($unit_standard_id)) {
        $query .= " AND unit_standard_id = ?";
        $params[] = $unit_standard_id;
        $types .= "s";
    }
    
    $query .= " ORDER BY category ASC, material_name ASC";
    
    $stmt = $conn->prepare($query);
    
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result) {
        $materials = [];
        while ($row = $result->fetch_assoc()) {
            $materials[] = $row;
        }
        echo json_encode($materials);
    } else {
        echo json_encode(['error' => 'Failed to fetch materials: ' . $conn->error]);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
}

$conn->close();
?>