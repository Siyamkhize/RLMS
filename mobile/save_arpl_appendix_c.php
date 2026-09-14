<?php
/**
 * Save ARPL Appendix C: Trade Curriculum Content Summary
 * Endpoint: POST mobile/save_arpl_appendix_c.php
 */

header('Content-Type: application/json');
require_once '../connection.php';

try {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    $learnerID = isset($data['learnerID']) ? intval($data['learnerID']) : 0;
    $ofoNumber = isset($data['ofoNumber']) ? $data['ofoNumber'] : '';
    
    if ($learnerID <= 0 || empty($ofoNumber)) {
        throw new Exception('Missing learnerID or ofoNumber');
    }
    
    $curriculum_overview = isset($data['curriculum_overview']) ? $data['curriculum_overview'] : null;
    $module_summary = isset($data['module_summary']) ? $data['module_summary'] : null;
    $learning_outcomes = isset($data['learning_outcomes']) ? $data['learning_outcomes'] : null;
    $additional_notes = isset($data['additional_notes']) ? $data['additional_notes'] : null;
    
    // Check if exists
    $stmt = $conn->prepare("SELECT id FROM arpl_appendix_c WHERE learnerID = ? AND ofo_number = ?");
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    $exists = $stmt->get_result()->num_rows > 0;
    $stmt->close();
    
    if ($exists) {
        $stmt = $conn->prepare("
            UPDATE arpl_appendix_c SET
                curriculum_overview = ?,
                module_summary = ?,
                learning_outcomes = ?,
                additional_notes = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE learnerID = ? AND ofo_number = ?
        ");
        $stmt->bind_param('ssssis', $curriculum_overview, $module_summary, $learning_outcomes, $additional_notes, $learnerID, $ofoNumber);
    } else {
        $stmt = $conn->prepare("
            INSERT INTO arpl_appendix_c (learnerID, ofo_number, curriculum_overview, module_summary, learning_outcomes, additional_notes)
            VALUES (?, ?, ?, ?, ?, ?)
        ");
        $stmt->bind_param('isssss', $learnerID, $ofoNumber, $curriculum_overview, $module_summary, $learning_outcomes, $additional_notes);
    }
    
    if ($stmt->execute()) {
        echo json_encode(['status' => 'success', 'message' => 'Appendix C saved successfully']);
    } else {
        throw new Exception('Database error: ' . $stmt->error);
    }
    
    $stmt->close();
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>
