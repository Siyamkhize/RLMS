<?php
// Endpoint: save_arpl_criteria.php
// Purpose: Save or Update ARPL Evaluation Criteria (Section 5)

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'connection.php';

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }

    $required = ['learner_id', 'assessor_id', 'class_id', 'project_id', 'site_id', 'criteria_json'];
    foreach ($required as $field) {
        if (!isset($input[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }

    $learner_id = $input['learner_id'];
    $assessor_id = $input['assessor_id'];
    $class_id = $input['class_id'];
    $project_id = $input['project_id'];
    $site_id = $input['site_id'];
    $criteria_json = $input['criteria_json'];
    $is_recommended = $input['is_recommended'] ?? 0;
    $assessor_confirmation = $input['assessor_confirmation'] ?? 0;

    // Insert or Update
    $stmt = $conn->prepare("
        INSERT INTO arpl_evaluation_criteria 
        (learner_id, assessor_id, class_id, project_id, site_id, criteria_json, is_recommended, assessor_confirmation)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        assessor_id = VALUES(assessor_id),
        class_id = VALUES(class_id),
        project_id = VALUES(project_id),
        site_id = VALUES(site_id),
        criteria_json = IF(
            VALUES(criteria_json) = '' OR VALUES(criteria_json) = '{}' OR VALUES(criteria_json) = '0',
            criteria_json,
            VALUES(criteria_json)
        ),
        is_recommended = VALUES(is_recommended),
        assessor_confirmation = VALUES(assessor_confirmation),
        created_at = CURRENT_TIMESTAMP
    ");

    // criteria_json must be bound as string (s), not int — otherwise JSON is cast to 0
    $stmt->bind_param("iisiisii", $learner_id, $assessor_id, $class_id, $project_id, $site_id, $criteria_json, $is_recommended, $assessor_confirmation);
    
    if ($stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Criteria saved successfully']);
    } else {
        throw new Exception($stmt->error);
    }

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
