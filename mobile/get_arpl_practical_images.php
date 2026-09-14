<?php
/**
 * Get ARPL Practical Evidence Images
 * 
 * Retrieves all images captured for a specific learner's practical tasks
 * Returns images for both assessor and moderator views
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

try {
    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $learner_id = $input['learner_id'] ?? null;
    $class_id = $input['class_id'] ?? null;
    $ofo_number = $input['ofo_number'] ?? null;
    $role = $input['role'] ?? null; // Optional filter by role
    
    // Validate required fields
    if (!$learner_id || !$class_id || !$ofo_number) {
        throw new Exception('Missing required fields: learner_id, class_id, ofo_number');
    }
    
    // Create database connection
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception('Database connection failed: ' . $conn->connect_error);
    }
    
    // Build query
    $query = "SELECT 
                id,
                learner_id,
                class_id,
                ofo_number,
                practical_task_id,
                role,
                user_id,
                image_path,
                caption,
                uploaded_at,
                created_at
              FROM arpl_practical_images
              WHERE learner_id = ? 
                AND class_id = ? 
                AND ofo_number = ?";
    
    $params = [$learner_id, $class_id, $ofo_number];
    $types = 'iis';
    
    // Add role filter if specified
    if ($role && in_array($role, ['assessor', 'moderator'])) {
        $query .= " AND role = ?";
        $params[] = $role;
        $types .= 's';
    }
    
    $query .= " ORDER BY practical_task_id, uploaded_at DESC";
    
    // Prepare and execute
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        throw new Exception('Query preparation failed: ' . $conn->error);
    }
    
    $stmt->bind_param($types, ...$params);
    
    if (!$stmt->execute()) {
        throw new Exception('Query execution failed: ' . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $images = [];
    
    while ($row = $result->fetch_assoc()) {
        $images[] = [
            'id' => (int)$row['id'],
            'learner_id' => (int)$row['learner_id'],
            'class_id' => (int)$row['class_id'],
            'ofo_number' => $row['ofo_number'],
            'practical_task_id' => $row['practical_task_id'],
            'role' => $row['role'],
            'user_id' => $row['user_id'],
            'image_path' => $row['image_path'],
            'caption' => $row['caption'],
            'uploaded_at' => $row['uploaded_at'],
            'created_at' => $row['created_at']
        ];
    }
    
    $stmt->close();
    $conn->close();
    
    echo json_encode([
        'status' => 'success',
        'images' => $images,
        'count' => count($images)
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
