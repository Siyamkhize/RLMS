<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Include database connection
require_once __DIR__ . '/connection.php';

try {
    // Get learner_id from query parameter
    if (!isset($_GET['learner_id']) || empty($_GET['learner_id'])) {
        throw new Exception('learner_id parameter is required');
    }
    
    $learner_id = $conn->real_escape_string($_GET['learner_id']);
    
    // Fetch work experiences for the learner
    $sql = "SELECT 
                id,
                learner_id,
                employer_name,
                position_held,
                period_from,
                period_to,
                responsibilities,
                created_at,
                updated_at,
                synced
            FROM work_experience
            WHERE learner_id = '$learner_id'
            ORDER BY period_from DESC";
    
    $result = $conn->query($sql);
    
    if (!$result) {
        throw new Exception('Query failed: ' . $conn->error);
    }
    
    $work_experiences = [];
    while ($row = $result->fetch_assoc()) {
        $work_experiences[] = $row;
    }
    
    echo json_encode([
        'success' => true,
        'data' => $work_experiences,
        'count' => count($work_experiences)
    ]);
    
} catch (Exception $e) {
    error_log("Error in get_work_experience.php: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'data' => []
    ]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>
