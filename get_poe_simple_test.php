<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Simple test version of get_poe.php
try {
    include('connection.php');
    
    $learnerID = isset($_GET['learnerId']) ? intval($_GET['learnerId']) : 0;
    
    if ($learnerID <= 0) {
        echo json_encode(['error' => 'Invalid learnerID provided', 'received' => $_GET]);
        exit;
    }
    
    // Simple query to test basic functionality
    $query = "SELECT * FROM marks WHERE learnerID = ? ORDER BY id DESC LIMIT 10";
    $stmt = $conn->prepare($query);
    
    if (!$stmt) {
        echo json_encode(['error' => 'Failed to prepare query: ' . $conn->error]);
        exit;
    }
    
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $marks = [];
    while ($row = $result->fetch_assoc()) {
        $marks[] = $row;
    }
    
    $response = [
        'status' => 'success',
        'learner_id' => $learnerID,
        'marks_count' => count($marks),
        'marks' => $marks,
        'message' => 'Simple test successful'
    ];
    
    echo json_encode($response, JSON_PRETTY_PRINT);
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    echo json_encode([
        'error' => 'Exception: ' . $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ]);
}
?>