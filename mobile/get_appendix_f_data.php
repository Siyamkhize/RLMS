<?php
/**
 * Get Appendix F Data - All 3 Sections
 * 
 * Returns Knowledge, Practical Tasks, and Workplace Observations
 * for a specific learner and trade (OFO number)
 * 
 * Request (POST JSON):
 * {
 *   "learnerID": 11701,
 *   "ofoNumber": "641201"
 * }
 * 
 * Response:
 * {
 *   "status": "success",
 *   "data": {
 *     "knowledge": [...],
 *     "practical": [...],
 *     "workplace_observations": [...]
 *   }
 * }
 */

header('Content-Type: application/json');

// Add debug logging
error_log("=== Appendix F GET Request ===");
error_log("Time: " . date('Y-m-d H:i:s'));

require_once 'connection.php';

try {
    $rawInput = file_get_contents('php://input');
    error_log("Raw input: " . $rawInput);
    
    $input = json_decode($rawInput, true);
    error_log("Decoded input: " . print_r($input, true));
    
    if (!isset($input['learnerID']) || !isset($input['ofoNumber'])) {
        throw new Exception('Missing required fields: learnerID and ofoNumber');
    }
    
    $learnerID = intval($input['learnerID']);
    $ofoNumber = $input['ofoNumber'];
    
    $response = [
        'status' => 'success',
        'data' => [
            'knowledge' => [],
            'practical' => [],
            'workplace_observations' => []
        ]
    ];
    
    // ═══════════════════════════════════════════════════════════
    // SECTION 1: KNOWLEDGE ASSESSMENT
    // ═══════════════════════════════════════════════════════════
    $stmtKnowledge = $conn->prepare("
        SELECT 
            id,
            question_number,
            question_text,
            candidate_score,
            percentage,
            assessor_id,
            created_at,
            updated_at
        FROM arpl_appendix_f_knowledge
        WHERE learnerID = ? AND ofoNumber = ?
        ORDER BY question_number ASC
    ");
    
    if ($stmtKnowledge) {
        $stmtKnowledge->bind_param('is', $learnerID, $ofoNumber);
        $stmtKnowledge->execute();
        $result = $stmtKnowledge->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $response['data']['knowledge'][] = [
                'id' => intval($row['id']),
                'question_number' => intval($row['question_number']),
                'question_text' => $row['question_text'],
                'candidate_score' => intval($row['candidate_score']),
                'percentage' => floatval($row['percentage'])
            ];
        }
        $stmtKnowledge->close();
    }
    
    // ═══════════════════════════════════════════════════════════
    // SECTION 2: PRACTICAL TASKS
    // ═══════════════════════════════════════════════════════════
    $stmtPractical = $conn->prepare("
        SELECT 
            id,
            task_number,
            task_name,
            candidate_score,
            percentage,
            assessor_id,
            created_at,
            updated_at
        FROM arpl_appendix_f_practical_tasks
        WHERE learnerID = ? AND ofoNumber = ?
        ORDER BY task_number ASC
    ");
    
    if ($stmtPractical) {
        $stmtPractical->bind_param('is', $learnerID, $ofoNumber);
        $stmtPractical->execute();
        $result = $stmtPractical->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $response['data']['practical'][] = [
                'id' => intval($row['id']),
                'task_number' => intval($row['task_number']),
                'task_name' => $row['task_name'],
                'candidate_score' => intval($row['candidate_score']),
                'percentage' => floatval($row['percentage'])
            ];
        }
        $stmtPractical->close();
    }
    
    // ═══════════════════════════════════════════════════════════
    // SECTION 3: WORKPLACE OBSERVATIONS
    // ═══════════════════════════════════════════════════════════
    // First, get all available activities for this trade
    $activitiesTable = '';
    switch ($ofoNumber) {
        case '641201': // Bricklayer
            $activitiesTable = 'arplappxe_bricklaying_activities';
            break;
        case '671201': // Plumber
            $activitiesTable = 'arplappxe_plumbing_activities';
            break;
        case '671101': // Electrician
            $activitiesTable = 'arplappxe_electrician_activities';
            break;
        default:
            throw new Exception("Unsupported OFO number: $ofoNumber");
    }
    
    // Check if activities table exists
    $checkTable = $conn->query("SHOW TABLES LIKE '$activitiesTable'");
    if ($checkTable->num_rows === 0) {
        throw new Exception("Activities table '$activitiesTable' does not exist for OFO $ofoNumber");
    }
    
    // Get all activities with their observation ratings (if any)
    $sqlObservations = "
        SELECT 
            a.activity_id,
            a.activity_name as task_observed,
            COALESCE(wo.technical_knowledge, 1) as technical_knowledge,
            COALESCE(wo.interpretation_of_instructions, 1) as interpretation_of_instructions,
            COALESCE(wo.team_work_attitude, 1) as team_work_attitude,
            wo.id as observation_id,
            wo.created_at,
            wo.updated_at
        FROM `$activitiesTable` a
        LEFT JOIN arpl_appendix_f_workplace_observations wo
            ON a.activity_id = wo.activity_id 
            AND wo.learnerID = ? 
            AND wo.ofoNumber = ?
        ORDER BY a.activity_id ASC
    ";
    
    $stmtObservations = $conn->prepare($sqlObservations);
    if ($stmtObservations) {
        $stmtObservations->bind_param('is', $learnerID, $ofoNumber);
        $stmtObservations->execute();
        $result = $stmtObservations->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $response['data']['workplace_observations'][] = [
                'activity_id' => intval($row['activity_id']),
                'task_observed' => $row['task_observed'],
                'technical_knowledge' => intval($row['technical_knowledge']),
                'interpretation_of_instructions' => intval($row['interpretation_of_instructions']),
                'team_work_attitude' => intval($row['team_work_attitude']),
                'has_rating' => !is_null($row['observation_id'])
            ];
        }
        $stmtObservations->close();
    }
    
    $conn->close();
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
