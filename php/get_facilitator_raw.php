<?php
// Simple endpoint to get raw facilitator data
include 'connection.php';

// Get facilitator ID from query parameter
$facilitator_id = isset($_GET['id']) ? intval($_GET['id']) : null;

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

try {
    if ($facilitator_id) {
        // Get specific facilitator
        $stmt = $conn->prepare("SELECT * FROM facilitator WHERE facilitator_id = ?");
        $stmt->bind_param("i", $facilitator_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($row = $result->fetch_assoc()) {
            echo json_encode([
                'success' => true,
                'count' => 1,
                'data' => $row
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        } else {
            echo json_encode([
                'success' => false,
                'message' => "Facilitator ID $facilitator_id not found"
            ]);
        }
    } else {
        // Get all facilitators
        $stmt = $conn->prepare("SELECT * FROM facilitator ORDER BY facilitator_id");
        $stmt->execute();
        $result = $stmt->get_result();
        
        $facilitators = [];
        while ($row = $result->fetch_assoc()) {
            $facilitators[] = $row;
        }
        
        echo json_encode([
            'success' => true,
            'count' => count($facilitators),
            'data' => $facilitators
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    }
    
    $stmt->close();
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

$conn->close();
?>

