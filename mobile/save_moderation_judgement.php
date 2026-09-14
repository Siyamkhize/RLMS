<?php
// ═══════════════════════════════════════════════════════════════════════════════
// ARPL MODERATION JUDGEMENT - SAVE ENDPOINT
// Saves complete moderation report with override mode support
// ═══════════════════════════════════════════════════════════════════════════════

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once '../connection.php';

// Logging function
function logMessage($message) {
    error_log("[SAVE_MODERATION] " . $message);
}

try {
    // Get JSON payload
    $json = file_get_contents('php://input');
    $payload = json_decode($json, true);
    
    if (!$payload) {
        throw new Exception('Invalid JSON payload');
    }
    
    logMessage("Received payload for learner_id: " . ($payload['learner_id'] ?? 'N/A'));
    
    // ═══════════════════════════════════════════════════════════════════════════
    // EXTRACT MAIN FIELDS
    // ═══════════════════════════════════════════════════════════════════════════
    $moderatorId = $payload['moderator_id'] ?? null;
    $learnerId = $payload['learner_id'] ?? null;
    $classId = $payload['class_id'] ?? null;
    $ofoNumber = $payload['ofo_number'] ?? null;
    
    if (!$moderatorId || !$learnerId || !$classId || !$ofoNumber) {
        throw new Exception('Missing required fields: moderator_id, learner_id, class_id, ofo_number');
    }
    
    // Override mode
    $overrideModeActive = isset($payload['override_mode_active']) ? (int)$payload['override_mode_active'] : 0;
    $assessorOverridesJson = isset($payload['assessor_data_overrides']) 
        ? json_encode($payload['assessor_data_overrides']) 
        : null;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // EXTRACT MODERATOR REPORT
    // ═══════════════════════════════════════════════════════════════════════════
    $report = $payload['moderation_report'] ?? [];
    
    $centerName = $report['center_name'] ?? 'MTL TRAINING AND PROJECTS';
    $accreditationNo = $report['accreditation_no'] ?? null;
    $assessorName = $report['assessor_name'] ?? null;
    $assessorRegNo = $report['assessor_reg_no'] ?? null;
    $moderatorName = $report['moderator_name'] ?? null;
    $moderatorRegNo = $report['moderator_reg_no'] ?? null;
    $moderationDate = $report['moderation_date'] ?? null;
    $candidateName = $report['candidate_name'] ?? null;
    $candidateIdNo = $report['candidate_id_no'] ?? null;
    $trade = $report['trade'] ?? null;
    
    // Convert ISO8601 to MySQL DATE
    if ($moderationDate) {
        $moderationDate = date('Y-m-d', strtotime($moderationDate));
    }
    
    // Observation criteria (10-point checklist)
    $observationCriteriaJson = isset($report['observation_criteria']) 
        ? json_encode($report['observation_criteria']) 
        : null;
    
    // Moderator observations & final decision
    $moderatorObservations = $report['moderator_observations'] ?? null;
    $tradeTestResult = $report['trade_test_result'] ?? null;
    $recommendations = $report['recommendations'] ?? null;
    $responsiblePerson = $report['responsible_person'] ?? null;
    $responsibleSignature = $report['responsible_signature'] ?? null;
    $internalModeratorName = $report['internal_moderator_name'] ?? null;
    $internalModeratorSignature = $report['internal_moderator_signature'] ?? null;
    $signatureDate = $report['signature_date'] ?? null;
    $correctiveActions = $report['corrective_actions'] ?? null;
    $completionDate = $report['completion_date'] ?? null;
    $responsiblePersonFinalSignature = $report['responsible_person_final_signature'] ?? null;
    $responsiblePersonDate = $report['responsible_person_date'] ?? null;
    
    // Convert dates
    if ($signatureDate) {
        $signatureDate = date('Y-m-d', strtotime($signatureDate));
    }
    if ($completionDate) {
        $completionDate = date('Y-m-d', strtotime($completionDate));
    }
    if ($responsiblePersonDate) {
        $responsiblePersonDate = date('Y-m-d', strtotime($responsiblePersonDate));
    }
    
    // Validate trade test result
    if ($tradeTestResult && !in_array($tradeTestResult, ['Upheld', 'Rejected'])) {
        throw new Exception('Invalid trade_test_result. Must be "Upheld" or "Rejected"');
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // EXTRACT APPENDIX MODERATION JUDGEMENTS
    // ═══════════════════════════════════════════════════════════════════════════
    $appendixDJson = isset($payload['appendix_d']) ? json_encode($payload['appendix_d']) : null;
    $appendixEJson = isset($payload['appendix_e']) ? json_encode($payload['appendix_e']) : null;
    $appendixFJson = isset($payload['appendix_f']) ? json_encode($payload['appendix_f']) : null;
    $appendixHJson = isset($payload['appendix_h']) ? json_encode($payload['appendix_h']) : null;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // EXTRACT FINAL DECISION
    // ═══════════════════════════════════════════════════════════════════════════
    $finalDecision = $payload['final_decision'] ?? null;
    $finalDecisionReason = $payload['final_decision_reason'] ?? null;
    $moderatorSignatureName = $payload['moderator_signature_name'] ?? null;
    $decisionDate = $payload['decision_date'] ?? date('Y-m-d H:i:s');
    
    if ($decisionDate) {
        $decisionDate = date('Y-m-d H:i:s', strtotime($decisionDate));
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // DATABASE OPERATION: INSERT OR UPDATE
    // ═══════════════════════════════════════════════════════════════════════════
    
    // Check if record exists
    $checkSql = "SELECT id FROM arpl_moderation_reports 
                 WHERE learner_id = ? AND class_id = ? AND ofo_number = ? AND moderator_id = ?";
    $checkStmt = $conn->prepare($checkSql);
    $checkStmt->bind_param('iiss', $learnerId, $classId, $ofoNumber, $moderatorId);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();
    $existingRecord = $checkResult->fetch_assoc();
    $checkStmt->close();
    
    if ($existingRecord) {
        // UPDATE existing record
        logMessage("Updating existing moderation report ID: " . $existingRecord['id']);
        
        $updateSql = "UPDATE arpl_moderation_reports SET
            override_mode_active = ?,
            assessor_data_overrides_json = ?,
            center_name = ?,
            accreditation_no = ?,
            assessor_name = ?,
            assessor_reg_no = ?,
            moderator_name = ?,
            moderator_reg_no = ?,
            moderation_date = ?,
            candidate_name = ?,
            candidate_id_no = ?,
            trade = ?,
            observation_criteria_json = ?,
            moderator_observations = ?,
            trade_test_result = ?,
            recommendations = ?,
            responsible_person = ?,
            responsible_signature = ?,
            internal_moderator_name = ?,
            internal_moderator_signature = ?,
            signature_date = ?,
            corrective_actions = ?,
            completion_date = ?,
            responsible_person_final_signature = ?,
            responsible_person_date = ?,
            appendix_d_moderation_json = ?,
            appendix_e_moderation_json = ?,
            appendix_f_moderation_json = ?,
            appendix_h_moderation_json = ?,
            final_decision = ?,
            final_decision_reason = ?,
            moderator_signature_name = ?,
            decision_date = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?";
        
        $stmt = $conn->prepare($updateSql);
        $stmt->bind_param(
            'issssssssssssssssssssssssssssissi',
            $overrideModeActive,
            $assessorOverridesJson,
            $centerName,
            $accreditationNo,
            $assessorName,
            $assessorRegNo,
            $moderatorName,
            $moderatorRegNo,
            $moderationDate,
            $candidateName,
            $candidateIdNo,
            $trade,
            $observationCriteriaJson,
            $moderatorObservations,
            $tradeTestResult,
            $recommendations,
            $responsiblePerson,
            $responsibleSignature,
            $internalModeratorName,
            $internalModeratorSignature,
            $signatureDate,
            $correctiveActions,
            $completionDate,
            $responsiblePersonFinalSignature,
            $responsiblePersonDate,
            $appendixDJson,
            $appendixEJson,
            $appendixFJson,
            $appendixHJson,
            $finalDecision,
            $finalDecisionReason,
            $moderatorSignatureName,
            $decisionDate,
            $existingRecord['id']
        );
        
    } else {
        // INSERT new record
        logMessage("Inserting new moderation report");
        
        $insertSql = "INSERT INTO arpl_moderation_reports (
            moderator_id, learner_id, class_id, ofo_number,
            override_mode_active, assessor_data_overrides_json,
            center_name, accreditation_no, assessor_name, assessor_reg_no,
            moderator_name, moderator_reg_no, moderation_date,
            candidate_name, candidate_id_no, trade,
            observation_criteria_json,
            moderator_observations, trade_test_result, recommendations,
            responsible_person, responsible_signature,
            internal_moderator_name, internal_moderator_signature, signature_date,
            corrective_actions, completion_date,
            responsible_person_final_signature, responsible_person_date,
            appendix_d_moderation_json, appendix_e_moderation_json,
            appendix_f_moderation_json, appendix_h_moderation_json,
            final_decision, final_decision_reason, moderator_signature_name, decision_date
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        
        $stmt = $conn->prepare($insertSql);
        $stmt->bind_param(
            'siisissssssssssssssssssssssssssssisss',
            $moderatorId, $learnerId, $classId, $ofoNumber,
            $overrideModeActive, $assessorOverridesJson,
            $centerName, $accreditationNo, $assessorName, $assessorRegNo,
            $moderatorName, $moderatorRegNo, $moderationDate,
            $candidateName, $candidateIdNo, $trade,
            $observationCriteriaJson,
            $moderatorObservations, $tradeTestResult, $recommendations,
            $responsiblePerson, $responsibleSignature,
            $internalModeratorName, $internalModeratorSignature, $signatureDate,
            $correctiveActions, $completionDate,
            $responsiblePersonFinalSignature, $responsiblePersonDate,
            $appendixDJson, $appendixEJson, $appendixFJson, $appendixHJson,
            $finalDecision, $finalDecisionReason, $moderatorSignatureName, $decisionDate
        );
    }
    
    if (!$stmt->execute()) {
        throw new Exception('Database error: ' . $stmt->error);
    }
    
    $recordId = $existingRecord ? $existingRecord['id'] : $conn->insert_id;
    $stmt->close();
    
    logMessage("Moderation report saved successfully. Record ID: $recordId");
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SUCCESS RESPONSE
    // ═══════════════════════════════════════════════════════════════════════════
    echo json_encode([
        'status' => 'success',
        'success' => true,
        'message' => 'Moderation judgement saved successfully',
        'data' => [
            'record_id' => $recordId,
            'learner_id' => $learnerId,
            'class_id' => $classId,
            'ofo_number' => $ofoNumber,
            'moderator_id' => $moderatorId,
            'final_decision' => $finalDecision,
            'trade_test_result' => $tradeTestResult,
            'timestamp' => date('Y-m-d H:i:s')
        ]
    ]);
    
} catch (Exception $e) {
    logMessage("ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
