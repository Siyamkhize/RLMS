<?php
// Endpoint: save_arpl_appendix_e.php
// Purpose: Save or Update ARPL Appendix E (Interview Record)

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

    $required = ['learner_id', 'assessor_id', 'class_id', 'project_id', 'site_id', 'question_id', 'rating'];
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
    $question_id = $input['question_id'];
    $rating = $input['rating'];
    $comment = $input['comment'] ?? '';
    
    $assessor_sig_path = null;
    $learner_sig_path = null;

    if (!empty($input['assessor_signature'])) {
        $filename = "sig_assessor_e_" . $learner_id . "_" . $question_id . "_" . time() . ".png";
        $data = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $input['assessor_signature']));
        file_put_contents("signatures/" . $filename, $data);
        $assessor_sig_path = "signatures/" . $filename;
    }

    if (!empty($input['learner_signature'])) {
        $filename = "sig_learner_e_" . $learner_id . "_" . $question_id . "_" . time() . ".png";
        $data = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $input['learner_signature']));
        file_put_contents("signatures/" . $filename, $data);
        $learner_sig_path = "signatures/" . $filename;
    }

    // Insert or Update based on LearnerID and QuestionID
    $stmt = $conn->prepare("
        INSERT INTO arpl_appendix_e 
        (learner_id, assessor_id, class_id, project_id, site_id, question_id, rating, comment, assessor_signature, learner_signature)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        assessor_id = VALUES(assessor_id),
        class_id = VALUES(class_id),
        project_id = VALUES(project_id),
        site_id = VALUES(site_id),
        rating = VALUES(rating),
        comment = VALUES(comment),
        assessor_signature = COALESCE(VALUES(assessor_signature), assessor_signature),
        learner_signature = COALESCE(VALUES(learner_signature), learner_signature),
        created_at = CURRENT_TIMESTAMP
    ");

    // comment must use (s), not (i) — otherwise text is cast to 0
    $stmt->bind_param("iisiiiisss", $learner_id, $assessor_id, $class_id, $project_id, $site_id, $question_id, $rating, $comment, $assessor_sig_path, $learner_sig_path);
    
    if ($stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Appendix E saved successfully']);
    } else {
        throw new Exception($stmt->error);
    }

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
