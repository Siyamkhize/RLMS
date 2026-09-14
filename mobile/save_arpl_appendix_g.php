<?php
/**
 * Save ARPL Appendix G: Appeals Form
 * Endpoint: POST mobile/save_arpl_appendix_g.php
 * 
 * Saves appeal information including moderator details, grounds for appeal,
 * status, and signatures from both candidate and assessor.
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
    
    // Extract form fields
    $appealSubject = isset($data['appeal_subject']) ? $data['appeal_subject'] : null;
    $groundsForAppeal = isset($data['grounds_for_appeal']) ? $data['grounds_for_appeal'] : null;
    $moderatorName = isset($data['moderator_name']) ? $data['moderator_name'] : null;
    $appealStatus = isset($data['appeal_status']) ? $data['appeal_status'] : 'Submitted';
    $assessorFindings = isset($data['assessor_findings']) ? $data['assessor_findings'] : null;
    $candidateSignature = isset($data['candidate_signature']) ? $data['candidate_signature'] : null;
    $assessorSignature = isset($data['assessor_signature']) ? $data['assessor_signature'] : null;
    $candidateSignedAt = isset($data['candidate_signed_at']) ? $data['candidate_signed_at'] : null;
    $assessorSignedAt = isset($data['assessor_signed_at']) ? $data['assessor_signed_at'] : null;
    $candidateDate = isset($data['candidate_date']) ? $data['candidate_date'] : null;
    $assessorDate = isset($data['assessor_date']) ? $data['assessor_date'] : null;
    
    // Validate status
    $validStatuses = ['Submitted', 'Under Review', 'Resolved'];
    if (!in_array($appealStatus, $validStatuses)) {
        $appealStatus = 'Submitted';
    }
    
    // Check if record exists
    $stmt = $conn->prepare("SELECT id FROM arpl_appendix_g WHERE learnerID = ? AND ofo_number = ?");
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    $result = $stmt->get_result();
    $exists = $result->fetch_assoc();
    $stmt->close();
    
    if ($exists) {
        // UPDATE existing record
        $stmt = $conn->prepare("
            UPDATE arpl_appendix_g SET
                appeal_subject = ?,
                grounds_for_appeal = ?,
                moderator_name = ?,
                appeal_status = ?,
                assessor_findings = ?,
                candidate_signature = ?,
                assessor_signature = ?,
                candidate_signed_at = ?,
                assessor_signed_at = ?,
                candidate_date = ?,
                assessor_date = ?
            WHERE learnerID = ? AND ofo_number = ?
        ");
        
        $stmt->bind_param(
            'sssssssssss|is',
            $appealSubject,
            $groundsForAppeal,
            $moderatorName,
            $appealStatus,
            $assessorFindings,
            $candidateSignature,
            $assessorSignature,
            $candidateSignedAt,
            $assessorSignedAt,
            $candidateDate,
            $assessorDate,
            $learnerID,
            $ofoNumber
        );
        
        $message = 'Appendix G appeal updated successfully';
    } else {
        // INSERT new record
        $stmt = $conn->prepare("
            INSERT INTO arpl_appendix_g 
            (learnerID, ofo_number, appeal_subject, grounds_for_appeal, moderator_name, 
             appeal_status, assessor_findings, candidate_signature, assessor_signature,
             candidate_signed_at, assessor_signed_at, candidate_date, assessor_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        
        $stmt->bind_param(
            'issssssssssss',
            $learnerID,
            $ofoNumber,
            $appealSubject,
            $groundsForAppeal,
            $moderatorName,
            $appealStatus,
            $assessorFindings,
            $candidateSignature,
            $assessorSignature,
            $candidateSignedAt,
            $assessorSignedAt,
            $candidateDate,
            $assessorDate
        );
        
        $message = 'Appendix G appeal created successfully';
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
