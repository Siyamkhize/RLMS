<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include('connection.php');

$learner_id = $_GET['learner_id'] ?? '';

if (empty($learner_id)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing learner_id parameter'
    ]);
    exit();
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8mb4");
    
    // Get pothole evidence images from poe table
    // Note: poe table might not have 'id' or 'created_at' columns, so we'll select what exists
    $sql = "SELECT exercise, filePath, logbook_text 
            FROM poe 
            WHERE learnerID = ? 
            AND type = 'LogBook'
            AND (exercise LIKE '%Pothole%' OR logbook_text LIKE '%pothole%')
            ORDER BY exercise DESC";
    
    $stmt = $conn->prepare($sql);
    $learner_id_int = intval($learner_id);
    $stmt->bind_param('i', $learner_id_int);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $images = [];
    while ($row = $result->fetch_assoc()) {
        $images[] = [
            'exercise' => $row['exercise'],
            'file_path' => $row['filePath'],
            'description' => $row['logbook_text']
        ];
    }
    
    $stmt->close();
    $conn->close();
    
    echo json_encode([
        'status' => 'success',
        'data' => $images,
        'count' => count($images)
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
