<?php
/**
 * Get ARPL Practical Evidence Images for All Learners in a Class
 * 
 * This endpoint allows assessors and moderators to view all practical images
 * for all learners in their class, organized by learner and practical task.
 * 
 * Used by: Assessors, ARPL Assessors, Moderators, ARPL Moderators
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
    
    $class_id = $input['class_id'] ?? null;
    $ofo_number = $input['ofo_number'] ?? null;
    $learner_id = $input['learner_id'] ?? null; // Optional: filter by specific learner
    $role_filter = $input['role'] ?? null; // Optional: 'assessor' or 'moderator'
    
    // Validate required fields
    if (!$class_id || !$ofo_number) {
        throw new Exception('Missing required fields: class_id, ofo_number');
    }
    
    // Create database connection
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception('Database connection failed: ' . $conn->connect_error);
    }
    
    // Build query - get images grouped by learner
    $query = "SELECT 
                pi.id,
                pi.learner_id,
                pi.class_id,
                pi.ofo_number,
                pi.practical_task_id,
                pi.role,
                pi.user_id,
                pi.image_path,
                pi.caption,
                pi.uploaded_at,
                pi.created_at,
                ld.Name as learner_name,
                ld.Surname as learner_surname,
                ld.IDnumber as learner_id_number
              FROM arpl_practical_images pi
              LEFT JOIN learnerdetails ld ON pi.learner_id = ld.LearnerID
              WHERE pi.class_id = ? 
                AND pi.ofo_number = ?";
    
    $params = [$class_id, $ofo_number];
    $types = 'is';
    
    // Add learner filter if specified
    if ($learner_id) {
        $query .= " AND pi.learner_id = ?";
        $params[] = $learner_id;
        $types .= 'i';
    }
    
    // Add role filter if specified
    if ($role_filter && in_array($role_filter, ['assessor', 'moderator'])) {
        $query .= " AND pi.role = ?";
        $params[] = $role_filter;
        $types .= 's';
    }
    
    $query .= " ORDER BY ld.Surname, ld.Name, pi.practical_task_id, pi.uploaded_at DESC";
    
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
    
    // Group images by learner
    $learners = [];
    $learnerMap = [];
    
    while ($row = $result->fetch_assoc()) {
        $learnerId = (int)$row['learner_id'];
        
        // Initialize learner if not exists
        if (!isset($learnerMap[$learnerId])) {
            $learnerMap[$learnerId] = [
                'learner_id' => $learnerId,
                'learner_name' => trim(($row['learner_name'] ?? '') . ' ' . ($row['learner_surname'] ?? '')),
                'learner_id_number' => $row['learner_id_number'] ?? '',
                'images' => [],
                'image_count' => 0,
                'assessor_images' => 0,
                'moderator_images' => 0,
            ];
        }
        
        // Add image to learner
        $imageData = [
            'id' => (int)$row['id'],
            'practical_task_id' => $row['practical_task_id'],
            'role' => $row['role'],
            'user_id' => $row['user_id'],
            'image_path' => $row['image_path'],
            'caption' => $row['caption'],
            'uploaded_at' => $row['uploaded_at'],
            'created_at' => $row['created_at']
        ];
        
        $learnerMap[$learnerId]['images'][] = $imageData;
        $learnerMap[$learnerId]['image_count']++;
        
        if ($row['role'] === 'assessor') {
            $learnerMap[$learnerId]['assessor_images']++;
        } elseif ($row['role'] === 'moderator') {
            $learnerMap[$learnerId]['moderator_images']++;
        }
    }
    
    // Convert map to array
    $learners = array_values($learnerMap);
    
    $stmt->close();
    $conn->close();
    
    echo json_encode([
        'status' => 'success',
        'learners' => $learners,
        'learner_count' => count($learners),
        'total_images' => array_sum(array_column($learners, 'image_count'))
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
