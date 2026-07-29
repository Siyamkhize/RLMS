<?php
// Endpoint: get_arpl_data.php
// Purpose: Retrieve existing ARPL data for a learner

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'connection.php';

try {
    $learner_id = $_GET['learner_id'] ?? null;
    
    if (!$learner_id) {
        throw new Exception('Missing learner_id');
    }

    $data = [
        'appendix_d' => null,
        'appendix_e' => [],
        'appendix_f' => null,
        'criteria' => null
    ];

    // Get Appendix D (one row per learner; latest if duplicates exist before migration)
    $stmt = $conn->prepare("SELECT * FROM arpl_appendix_d WHERE learner_id = ? ORDER BY id DESC LIMIT 1");
    if ($stmt === false) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    $stmt->bind_param("i", $learner_id);
    $stmt->execute();
    $data['appendix_d'] = $stmt->get_result()->fetch_assoc();

    // Get Appendix E (one row per question; latest per question if duplicates exist)
    $stmt = $conn->prepare("
        SELECT e.*
        FROM arpl_appendix_e e
        INNER JOIN (
            SELECT question_id, MAX(id) AS max_id
            FROM arpl_appendix_e
            WHERE learner_id = ?
            GROUP BY question_id
        ) latest ON e.id = latest.max_id
        WHERE e.learner_id = ?
        ORDER BY e.question_id
    ");
    if ($stmt === false) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    $stmt->bind_param("ii", $learner_id, $learner_id);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $data['appendix_e'][] = $row;
    }

    // Get Appendix F
    $stmt = $conn->prepare("SELECT * FROM arpl_appendix_f WHERE learner_id = ? ORDER BY id DESC LIMIT 1");
    if ($stmt === false) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    $stmt->bind_param("i", $learner_id);
    $stmt->execute();
    $data['appendix_f'] = $stmt->get_result()->fetch_assoc();

    // Get Criteria
    $stmt = $conn->prepare("SELECT * FROM arpl_evaluation_criteria WHERE learner_id = ? ORDER BY id DESC LIMIT 1");
    if ($stmt === false) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    $stmt->bind_param("i", $learner_id);
    $stmt->execute();
    $data['criteria'] = $stmt->get_result()->fetch_assoc();

    echo json_encode(['success' => true, 'data' => $data]);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
