<?php
/**
 * Save Appendix F Data - All 3 Sections
 * 
 * Saves Knowledge, Practical Tasks, and Workplace Observations
 * 
 * Request (POST JSON):
 * {
 *   "learnerID": 11701,
 *   "ofoNumber": "641201",
 *   "assessor_id": 6,
 *   "knowledge": [
 *     {
 *       "question_number": 1,
 *       "question_text": "What is...",
 *       "candidate_score": 85,
 *       "percentage": 85.0
 *     }
 *   ],
 *   "practical": [
 *     {
 *       "task_number": 1,
 *       "task_name": "Build a corner",
 *       "candidate_score": 90,
 *       "percentage": 90.0
 *     }
 *   ],
 *   "workplace_observations": [
 *     {
 *       "activity_id": 1,
 *       "task_observed": "Reinforced Concrete Construction",
 *       "technical_knowledge": 3,
 *       "interpretation_of_instructions": 2,
 *       "team_work_attitude": 3
 *     }
 *   ]
 * }
 * 
 * Response:
 * {
 *   "status": "success",
 *   "message": "All sections saved successfully",
 *   "details": {...}
 * }
 */

// CORS Headers - Allow requests from mobile app
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'connection.php';

error_log("=== Appendix F Save Request ===");

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input: ' . json_last_error_msg());
    }
    
    $learnerID = intval($input['learnerID'] ?? 0);
    $ofoNumber = $input['ofoNumber'] ?? '';
    $assessor_id = intval($input['assessor_id'] ?? 1);
    $knowledge = $input['knowledge'] ?? [];
    $practical = $input['practical'] ?? [];
    $workplace_observations = $input['workplace_observations'] ?? [];
    
    if (!$learnerID || !$ofoNumber) {
        throw new Exception('Missing required fields: learnerID and ofoNumber');
    }
    
    $response = [
        'status' => 'success',
        'message' => 'All sections saved successfully',
        'details' => []
    ];
    
    // ═══════════════════════════════════════════════════════════
    // SECTION 1: SAVE KNOWLEDGE ASSESSMENT
    // ═══════════════════════════════════════════════════════════
    if (!empty($knowledge) && is_array($knowledge)) {
        $savedKnowledge = 0;
        $errorsKnowledge = [];
        
        // First, delete existing knowledge questions for this learner/OFO
        // (in case questions were removed)
        $conn->query("DELETE FROM arpl_appendix_f_knowledge WHERE learnerID = $learnerID AND ofoNumber = '$ofoNumber'");
        
        $stmtKnowledge = $conn->prepare("
            INSERT INTO arpl_appendix_f_knowledge 
            (learnerID, ofoNumber, question_number, question_text, candidate_score, percentage, assessor_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        
        if (!$stmtKnowledge) {
            throw new Exception('Failed to prepare knowledge statement: ' . $conn->error);
        }
        
        foreach ($knowledge as $item) {
            $question_number = intval($item['question_number']);
            $question_text = $item['question_text'] ?? '';
            $candidate_score = intval($item['candidate_score'] ?? 0);
            $percentage = floatval($item['percentage'] ?? 0.0);
            
            $stmtKnowledge->bind_param('iisisdi', 
                $learnerID, 
                $ofoNumber, 
                $question_number, 
                $question_text, 
                $candidate_score, 
                $percentage, 
                $assessor_id
            );
            
            if ($stmtKnowledge->execute()) {
                $savedKnowledge++;
            } else {
                $errorsKnowledge[] = "Question $question_number: " . $stmtKnowledge->error;
            }
        }
        
        $stmtKnowledge->close();
        
        $response['details']['knowledge'] = [
            'saved' => $savedKnowledge,
            'errors' => $errorsKnowledge
        ];
    }
    
    // ═══════════════════════════════════════════════════════════
    // SECTION 2: SAVE PRACTICAL TASKS
    // ═══════════════════════════════════════════════════════════
    if (!empty($practical) && is_array($practical)) {
        $savedPractical = 0;
        $errorsPractical = [];
        
        // First, delete existing practical tasks for this learner/OFO
        $conn->query("DELETE FROM arpl_appendix_f_practical_tasks WHERE learnerID = $learnerID AND ofoNumber = '$ofoNumber'");
        
        $stmtPractical = $conn->prepare("
            INSERT INTO arpl_appendix_f_practical_tasks 
            (learnerID, ofoNumber, task_number, task_name, candidate_score, percentage, assessor_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        
        if (!$stmtPractical) {
            throw new Exception('Failed to prepare practical statement: ' . $conn->error);
        }
        
        foreach ($practical as $item) {
            $task_number = intval($item['task_number']);
            $task_name = $item['task_name'] ?? '';
            $candidate_score = intval($item['candidate_score'] ?? 0);
            $percentage = floatval($item['percentage'] ?? 0.0);
            
            $stmtPractical->bind_param('iisisdi', 
                $learnerID, 
                $ofoNumber, 
                $task_number, 
                $task_name, 
                $candidate_score, 
                $percentage, 
                $assessor_id
            );
            
            if ($stmtPractical->execute()) {
                $savedPractical++;
            } else {
                $errorsPractical[] = "Task $task_number: " . $stmtPractical->error;
            }
        }
        
        $stmtPractical->close();
        
        $response['details']['practical'] = [
            'saved' => $savedPractical,
            'errors' => $errorsPractical
        ];
    }
    
    // ═══════════════════════════════════════════════════════════
    // SECTION 3: SAVE WORKPLACE OBSERVATIONS
    // ═══════════════════════════════════════════════════════════
    if (!empty($workplace_observations) && is_array($workplace_observations)) {
        $savedObservations = 0;
        $errorsObservations = [];
        
        $stmtObservations = $conn->prepare("
            INSERT INTO arpl_appendix_f_workplace_observations 
            (learnerID, ofoNumber, activity_id, task_observed, technical_knowledge, interpretation_of_instructions, team_work_attitude, assessor_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                task_observed = VALUES(task_observed),
                technical_knowledge = VALUES(technical_knowledge),
                interpretation_of_instructions = VALUES(interpretation_of_instructions),
                team_work_attitude = VALUES(team_work_attitude),
                assessor_id = VALUES(assessor_id),
                updated_at = CURRENT_TIMESTAMP
        ");
        
        if (!$stmtObservations) {
            throw new Exception('Failed to prepare observations statement: ' . $conn->error);
        }
        
        foreach ($workplace_observations as $item) {
            $activity_id = intval($item['activity_id']);
            $task_observed = $item['task_observed'] ?? '';
            $technical_knowledge = intval($item['technical_knowledge'] ?? 1);
            $interpretation = intval($item['interpretation_of_instructions'] ?? 1);
            $team_work = intval($item['team_work_attitude'] ?? 1);
            
            // Validate dropdown values (1, 2, or 3 only)
            if ($technical_knowledge < 1 || $technical_knowledge > 3) $technical_knowledge = 1;
            if ($interpretation < 1 || $interpretation > 3) $interpretation = 1;
            if ($team_work < 1 || $team_work > 3) $team_work = 1;
            
            $stmtObservations->bind_param('isissiii', 
                $learnerID, 
                $ofoNumber, 
                $activity_id, 
                $task_observed, 
                $technical_knowledge, 
                $interpretation, 
                $team_work, 
                $assessor_id
            );
            
            if ($stmtObservations->execute()) {
                $savedObservations++;
            } else {
                $errorsObservations[] = "Activity $activity_id: " . $stmtObservations->error;
            }
        }
        
        $stmtObservations->close();
        
        $response['details']['workplace_observations'] = [
            'saved' => $savedObservations,
            'errors' => $errorsObservations
        ];
    }
    
    $conn->close();
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'debug' => [
            'file' => $e->getFile(),
            'line' => $e->getLine()
        ]
    ]);
}
?>
