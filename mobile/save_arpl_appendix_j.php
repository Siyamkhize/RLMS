<?php
/**
 * Save ARPL Appendix J: Pre-Assessment Agreement
 * Endpoint: POST mobile/save_arpl_appendix_j.php
 * 
 * Saves the 6 acknowledgment checkboxes and signatures from candidate and witness
 * confirming understanding and agreement with ARPL assessment process.
 */

header('Content-Type: application/json');
require_once 'connection.php';

try {
    // Read JSON input
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!isset($data['learnerID']) || !isset($data['ofoNumber'])) {
        throw new Exception('Missing learnerID or ofoNumber');
    }
    
    $learnerID = intval($data['learnerID']);
    $ofoNumber = $data['ofoNumber'];
    
    // Extract acknowledgment checkboxes (convert yes/no to enum values)
    $understandsProcess = isset($data['understands_process']) && $data['understands_process'] ? 'yes' : 'no';
    $consentsToAssessment = isset($data['consents_to_assessment']) && $data['consents_to_assessment'] ? 'yes' : 'no';
    $understandsRights = isset($data['understands_rights']) && $data['understands_rights'] ? 'yes' : 'no';
    $confirmsAccuracy = isset($data['confirms_accuracy']) && $data['confirms_accuracy'] ? 'yes' : 'no';
    $understandsCriteria = isset($data['understands_criteria']) && $data['understands_criteria'] ? 'yes' : 'no';
    $agreesToTerms = isset($data['agrees_to_terms']) && $data['agrees_to_terms'] ? 'yes' : 'no';
    
    // Extract signature fields
    $candidateSignature = isset($data['candidate_signature']) ? $data['candidate_signature'] : null;
    $witnessName = isset($data['witness_name']) ? $data['witness_name'] : null;
    $witnessSignature = isset($data['witness_signature']) ? $data['witness_signature'] : null;
    $agreementDate = isset($data['agreement_date']) ? $data['agreement_date'] : null;
    
    // Check if record exists
    $stmt = $conn->prepare("SELECT id FROM arpl_appendix_j WHERE learnerID = ? AND ofo_number = ?");
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    $result = $stmt->get_result();
    $exists = $result->fetch_assoc();
    $stmt->close();
    
    if ($exists) {
        // UPDATE existing record
        $stmt = $conn->prepare("
            UPDATE arpl_appendix_j SET
                understands_process = ?,
                consents_to_assessment = ?,
                understands_rights = ?,
                confirms_accuracy = ?,
                understands_criteria = ?,
                agrees_to_terms = ?,
                candidate_signature = ?,
                witness_name = ?,
                witness_signature = ?,
                agreement_date = ?
            WHERE learnerID = ? AND ofo_number = ?
        ");
        
        $stmt->bind_param(
            'sssssssssssis',
            $understandsProcess,
            $consentsToAssessment,
            $understandsRights,
            $confirmsAccuracy,
            $understandsCriteria,
            $agreesToTerms,
            $candidateSignature,
            $witnessName,
            $witnessSignature,
            $agreementDate,
            $learnerID,
            $ofoNumber
        );
        
        $message = 'Appendix J agreement updated successfully';
    } else {
        // INSERT new record
        $stmt = $conn->prepare("
            INSERT INTO arpl_appendix_j 
            (learnerID, ofo_number, understands_process, consents_to_assessment, understands_rights,
             confirms_accuracy, understands_criteria, agrees_to_terms, candidate_signature, 
             witness_name, witness_signature, agreement_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        
        $stmt->bind_param(
            'isssssssssss',
            $learnerID,
            $ofoNumber,
            $understandsProcess,
            $consentsToAssessment,
            $understandsRights,
            $confirmsAccuracy,
            $understandsCriteria,
            $agreesToTerms,
            $candidateSignature,
            $witnessName,
            $witnessSignature,
            $agreementDate
        );
        
        $message = 'Appendix J agreement created successfully';
    }
    
    if ($stmt->execute()) {
        echo json_encode([
            'status' => 'success',
            'message' => $message,
            'learnerID' => $learnerID,
            'ofoNumber' => $ofoNumber
        ]);
    } else {
        throw new Exception('Database error: ' . $stmt->error);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
