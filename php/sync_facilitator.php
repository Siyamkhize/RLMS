<?php
include 'connection.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Allow both GET and POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit;
}

try {
    // Query all facilitator data from server database
    $stmt = $conn->prepare("SELECT * FROM facilitator ORDER BY facilitator_id");
    
    $stmt->execute();
    $result = $stmt->get_result();

    $facilitators = [];

    while ($row = $result->fetch_assoc()) {
        // Take data as-is from database
        // PHP will handle NULL values properly in JSON encoding
        $facilitators[] = $row;
    }

    // Log what we're sending
    error_log("[FACILITATOR_SYNC] Sending " . count($facilitators) . " facilitators");
    if (count($facilitators) > 0) {
        error_log("[FACILITATOR_SYNC] First record: " . json_encode($facilitators[0]));
    }

    // Return facilitators as JSON with proper NULL handling
    echo json_encode($facilitators, JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION);
    $stmt->close();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Server error: ' . $e->getMessage()]);
}

$conn->close();
?>

