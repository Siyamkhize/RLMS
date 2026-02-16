<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

$learner_id = isset($_GET['learner_id']) ? $_GET['learner_id'] : '';

if (empty($learner_id)) {
    echo json_encode(['error' => 'Learner ID is required']);
    exit;
}

try {
    $query = "
        SELECT 
            id,
            learner_id,
            class_id,
            finance_id,
            register_month,
            register_year,
            file_name,
            file_path,
            uploaded_at
        FROM learner_registers
        WHERE learner_id = ?
        ORDER BY register_year DESC, register_month DESC
    ";
    
    $stmt = $conn->prepare($query);
    $stmt->bind_param('s', $learner_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result) {
        $registers = [];
        while ($row = $result->fetch_assoc()) {
            $registers[] = $row;
        }
        echo json_encode($registers);
    } else {
        echo json_encode(['error' => 'Failed to fetch registers']);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    echo json_encode(['error' => 'Error: ' . $e->getMessage()]);
}

$conn->close();
?>
