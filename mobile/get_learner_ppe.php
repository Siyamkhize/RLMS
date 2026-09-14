<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

try {
    // Get parameters
    $learner_id = $_GET['learnerID'] ?? '';

    if (empty($learner_id)) {
        throw new Exception('Missing required parameter: learnerID');
    }

    // Get PPE sizes for this learner from poe_sizes table
    $sql = "SELECT 
                p.id,
                p.learner_id as LearnerID,
                p.conti_suits_size,
                p.safety_boots_size,
                p.created_at,
                p.updated_at
            FROM poe_sizes p 
            WHERE p.learner_id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $learner_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $ppe_data = $result->fetch_assoc();
        echo json_encode([
            'success' => true,
            'data' => $ppe_data
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'No PPE issuance found for this learner',
            'data' => null
        ]);
    }

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
