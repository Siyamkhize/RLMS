<?php
/**
 * Save ARPL Appendix F: Assessment Evaluation Agreement
 * Endpoint: POST mobile/save_arpl_appendix_f.php
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
    
    $knowledge_acknowledged = isset($data['knowledge_acknowledged']) ? ($data['knowledge_acknowledged'] ? 'yes' : 'no') : 'no';
    $practical_acknowledged = isset($data['practical_acknowledged']) ? ($data['practical_acknowledged'] ? 'yes' : 'no') : 'no';
    $workplace_acknowledged = isset($data['workplace_acknowledged']) ? ($data['workplace_acknowledged'] ? 'yes' : 'no') : 'no';
    $assessor_acknowledged = isset($data['assessor_acknowledged']) ? ($data['assessor_acknowledged'] ? 'yes' : 'no') : 'no';
    $candidate_signature = isset($data['candidate_signature']) ? $data['candidate_signature'] : null;
    $assessor_signature = isset($data['assessor_signature']) ? $data['assessor_signature'] : null;
    $agreement_date = isset($data['agreement_date']) ? $data['agreement_date'] : null;
    
    // Check if exists
    $stmt = $conn->prepare("SELECT id FROM arpl_appendix_f WHERE learnerID = ? AND ofo_number = ?");
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    $exists = $stmt->get_result()->num_rows > 0;
    $stmt->close();
    
    if ($exists) {
        $stmt = $conn->prepare("
            UPDATE arpl_appendix_f SET
                knowledge_acknowledged = ?,
                practical_acknowledged = ?,
                workplace_acknowledged = ?,
                assessor_acknowledged = ?,
                candidate_signature = ?,
                assessor_signature = ?,
                agreement_date = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE learnerID = ? AND ofo_number = ?
        ");
        $stmt->bind_param('ssssssssis',
            $knowledge_acknowledged, $practical_acknowledged, $workplace_acknowledged, $assessor_acknowledged,
            $candidate_signature, $assessor_signature, $agreement_date, $learnerID, $ofoNumber
        );
    } else {
        $stmt = $conn->prepare("
            INSERT INTO arpl_appendix_f 
            (learnerID, ofo_number, knowledge_acknowledged, practical_acknowledged, workplace_acknowledged, 
             assessor_acknowledged, candidate_signature, assessor_signature, agreement_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->bind_param('isssssss',
            $learnerID, $ofoNumber, $knowledge_acknowledged, $practical_acknowledged, $workplace_acknowledged,
            $assessor_acknowledged, $candidate_signature, $assessor_signature, $agreement_date
        );
    }
    
    if ($stmt->execute()) {
        echo json_encode(['status' => 'success', 'message' => 'Appendix F saved successfully']);
    } else {
        throw new Exception('Database error: ' . $stmt->error);
    }
    
    $stmt->close();
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>
