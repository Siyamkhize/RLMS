<?php
// ═══════════════════════════════════════════════════════════════════════════════
// ARPL MODERATION JUDGEMENT - RETRIEVE ENDPOINT
// Retrieves saved moderation report for a learner
// ═══════════════════════════════════════════════════════════════════════════════

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once '../connection.php';

// Logging function
function logMessage($message) {
    error_log("[GET_MODERATION] " . $message);
}

try {
    // Get parameters from POST or GET
    $json = file_get_contents('php://input');
    $params = json_decode($json, true) ?: [];
    
    // Fall back to GET parameters
    if (empty($params)) {
        $params = $_GET;
    }
    
    $learnerId = $params['learner_id'] ?? $params['learnerID'] ?? null;
    $classId = $params['class_id'] ?? $params['classID'] ?? null;
    $ofoNumber = $params['ofo_number'] ?? $params['ofoNumber'] ?? null;
    $moderatorId = $params['moderator_id'] ?? null;
    
    logMessage("Retrieving moderation for learner_id: $learnerId, class_id: $classId, ofo: $ofoNumber");
    
    if (!$learnerId || !$classId || !$ofoNumber) {
        throw new Exception('Missing required parameters: learner_id, class_id, ofo_number');
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // QUERY DATABASE
    // ═══════════════════════════════════════════════════════════════════════════
    
    $sql = "SELECT * FROM arpl_moderation_reports 
            WHERE learner_id = ? AND class_id = ? AND ofo_number = ?";
    
    // If moderator_id provided, filter by it (for specific moderator's report)
    if ($moderatorId) {
        $sql .= " AND moderator_id = ?";
    }
    
    $sql .= " ORDER BY created_at DESC LIMIT 1";
    
    $stmt = $conn->prepare($sql);
    
    if ($moderatorId) {
        $stmt->bind_param('iiss', $learnerId, $classId, $ofoNumber, $moderatorId);
    } else {
        $stmt->bind_param('iis', $learnerId, $classId, $ofoNumber);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    $record = $result->fetch_assoc();
    $stmt->close();
    
    // ═══════════════════════════════════════════════════════════════════════════
    // BUILD RESPONSE
    // ═══════════════════════════════════════════════════════════════════════════
    
    if (!$record) {
        // No moderation report found
        logMessage("No moderation report found");
        echo json_encode([
            'status' => 'success',
            'found' => false,
            'message' => 'No moderation report found for this learner',
            'data' => null
        ]);
        exit;
    }
    
    logMessage("Moderation report found. Record ID: " . $record['id']);
    
    // Parse JSON fields
    $observationCriteria = json_decode($record['observation_criteria_json'] ?? '[]', true);
    $assessorOverrides = json_decode($record['assessor_data_overrides_json'] ?? '{}', true);
    $appendixD = json_decode($record['appendix_d_moderation_json'] ?? '{}', true);
    $appendixE = json_decode($record['appendix_e_moderation_json'] ?? '{}', true);
    $appendixF = json_decode($record['appendix_f_moderation_json'] ?? '{}', true);
    $appendixH = json_decode($record['appendix_h_moderation_json'] ?? '{}', true);
    
    // Build structured response
    $responseData = [
        'record_id' => (int)$record['id'],
        'moderator_id' => $record['moderator_id'],
        'learner_id' => (int)$record['learner_id'],
        'class_id' => (int)$record['class_id'],
        'ofo_number' => $record['ofo_number'],
        
        // Override mode
        'override_mode_active' => (bool)$record['override_mode_active'],
        'assessor_data_overrides' => $assessorOverrides,
        
        // Moderation report
        'moderation_report' => [
            'center_name' => $record['center_name'],
            'accreditation_no' => $record['accreditation_no'],
            'assessor_name' => $record['assessor_name'],
            'assessor_reg_no' => $record['assessor_reg_no'],
            'moderator_name' => $record['moderator_name'],
            'moderator_reg_no' => $record['moderator_reg_no'],
            'moderation_date' => $record['moderation_date'],
            'candidate_name' => $record['candidate_name'],
            'candidate_id_no' => $record['candidate_id_no'],
            'trade' => $record['trade'],
            
            // Observation criteria
            'observation_criteria' => $observationCriteria,
            
            // Moderator observations & final decision
            'moderator_observations' => $record['moderator_observations'],
            'trade_test_result' => $record['trade_test_result'],
            'recommendations' => $record['recommendations'],
            'responsible_person' => $record['responsible_person'],
            'responsible_signature' => $record['responsible_signature'],
            'internal_moderator_name' => $record['internal_moderator_name'],
            'internal_moderator_signature' => $record['internal_moderator_signature'],
            'signature_date' => $record['signature_date'],
            'corrective_actions' => $record['corrective_actions'],
            'completion_date' => $record['completion_date'],
            'responsible_person_final_signature' => $record['responsible_person_final_signature'],
            'responsible_person_date' => $record['responsible_person_date'],
        ],
        
        // Appendix moderation judgements
        'appendix_d' => $appendixD,
        'appendix_e' => $appendixE,
        'appendix_f' => $appendixF,
        'appendix_h' => $appendixH,
        
        // Final decision
        'final_decision' => $record['final_decision'] ? (int)$record['final_decision'] : null,
        'final_decision_reason' => $record['final_decision_reason'],
        'moderator_signature_name' => $record['moderator_signature_name'],
        'decision_date' => $record['decision_date'],
        
        // Metadata
        'created_at' => $record['created_at'],
        'updated_at' => $record['updated_at']
    ];
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SUCCESS RESPONSE
    // ═══════════════════════════════════════════════════════════════════════════
    echo json_encode([
        'status' => 'success',
        'found' => true,
        'message' => 'Moderation report retrieved successfully',
        'data' => $responseData
    ]);
    
} catch (Exception $e) {
    logMessage("ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'found' => false,
        'message' => $e->getMessage()
    ]);
}
?>
