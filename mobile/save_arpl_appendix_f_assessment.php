<?php
/**
 * ARPL Appendix F Assessment Save API
 * Saves practical assessment evaluation data (tasks and workplace observations)
 * Trade-aware: Routes saves to trade-specific tables
 * 
 * Endpoint: POST mobile/save_arpl_appendix_f_assessment.php
 * 
 * Request Body:
 * {
 *   "learnerID": 20286,
 *   "ofoNumber": "671101",
 *   "trade": "electrician",  // Optional: electrician, bricklayer, or plumber
 *   "assessorName": "John Doe",
 *   "candidateName": "Jane Smith",
 *   "witnessName": "Tom Brown",
 *   "assessmentDate": "2026-07-09",
 *   "authorizedDate": "2026-07-09",
 *   "practicalTasks": [
 *     {"taskNumber": 1, "taskName": "Task 1", "score": 85, "percentage": 85.0},
 *     {"taskNumber": 2, "taskName": "Task 2", "score": 90, "percentage": 90.0}
 *   ],
 *   "workplaceObservations": [
 *     {"observationNumber": 1, "taskObserved": "Observed Task 1", "technicalKnowledge": "Good", "interpretation": "Excellent", "teamWork": "Fair"},
 *     {"observationNumber": 2, "taskObserved": "Observed Task 2", "technicalKnowledge": "Excellent", "interpretation": "Good", "teamWork": "Good"}
 *   ]
 * }
 * 
 * Response: Success or error message
 */

header('Content-Type: application/json');
require_once 'connection.php';

// ══════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ══════════════════════════════════════════════════════════
function getTradeName($ofoNumber) {
    $ofoMapping = [
        '671101' => 'electrician',
        '671102' => 'plumber',
        '671103' => 'bricklayer'
    ];
    return isset($ofoMapping[$ofoNumber]) ? $ofoMapping[$ofoNumber] : 'electrician';
}

function getTableName($appendix, $trade) {
    if ($trade === 'electrician') {
        $tables = [
            'f' => 'arpl_appendix_f',
            'f_tasks' => 'arpl_appendix_f_practical_tasks',
            'f_obs' => 'arpl_appendix_f_workplace_observations'
        ];
    } elseif ($trade === 'bricklayer') {
        $tables = [
            'f' => 'arpl_appendix_f_bricklayer',
            'f_tasks' => 'arpl_appendix_f_practical_tasks_bricklayer',
            'f_obs' => 'arpl_appendix_f_workplace_observations_bricklayer'
        ];
    } elseif ($trade === 'plumber') {
        $tables = [
            'f' => 'arpl_appendix_f_plumber',
            'f_tasks' => 'arpl_appendix_f_practical_tasks_plumber',
            'f_obs' => 'arpl_appendix_f_workplace_observations_plumber'
        ];
    } else {
        return null;
    }
    return isset($tables[$appendix]) ? $tables[$appendix] : null;
}

try {
    // Read JSON input from request body
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    // Get request parameters
    $learnerID = isset($data['learnerID']) ? intval($data['learnerID']) : 0;
    $ofoNumber = isset($data['ofoNumber']) ? $data['ofoNumber'] : null;
    $trade = isset($data['trade']) ? $data['trade'] : null;
    $assessorName = isset($data['assessorName']) ? $data['assessorName'] : null;
    $candidateName = isset($data['candidateName']) ? $data['candidateName'] : null;
    $witnessName = isset($data['witnessName']) ? $data['witnessName'] : null;
    $assessmentDate = isset($data['assessmentDate']) ? $data['assessmentDate'] : null;
    $authorizedDate = isset($data['authorizedDate']) ? $data['authorizedDate'] : null;
    $practicalTasks = isset($data['practicalTasks']) ? $data['practicalTasks'] : [];
    $workplaceObservations = isset($data['workplaceObservations']) ? $data['workplaceObservations'] : [];
    
    // ══════════════════════════════════════════════════════════
    // FETCH OFO FROM CLASS'S TRADE IF NOT PROVIDED
    // ══════════════════════════════════════════════════════════
    if (!$ofoNumber) {
        // First try to get classID from learner record
        $classID = 0;
        $stmt_class = $conn->prepare("
            SELECT classID FROM learnerdetails WHERE LearnerID = ? LIMIT 1
        ");
        
        if ($stmt_class) {
            $stmt_class->bind_param("i", $learnerID);
            $stmt_class->execute();
            $result_class = $stmt_class->get_result();
            
            if ($result_class && $result_class->num_rows > 0) {
                $row_class = $result_class->fetch_assoc();
                $classID = intval($row_class['classID'] ?? 0);
            }
            $stmt_class->close();
        }
        
        // Query class's trade to get OFO
        if ($classID > 0) {
            $stmt_trade = $conn->prepare("
                SELECT t.ofo_number, t.trade_name
                FROM class c
                LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
                WHERE c.classID = ?
                LIMIT 1
            ");
            
            if ($stmt_trade) {
                $stmt_trade->bind_param("i", $classID);
                $stmt_trade->execute();
                $result_trade = $stmt_trade->get_result();
                
                if ($result_trade && $result_trade->num_rows > 0) {
                    $row_trade = $result_trade->fetch_assoc();
                    $ofoNumber = $row_trade['ofo_number'] ?? null;
                    $tradeName = $row_trade['trade_name'] ?? null;
                    
                    if ($tradeName) {
                        $trade = strtolower($tradeName);
                    }
                }
                $stmt_trade->close();
            }
        }
        
        // If still not found from class, try learner's qualification
        if (!$ofoNumber) {
            $stmt_ofo = $conn->prepare("
                SELECT q.OFOcode 
                FROM learnerdetails l
                LEFT JOIN qualification q ON l.qualification_id = q.qualification_id
                WHERE l.LearnerID = ?
                LIMIT 1
            ");
            
            if ($stmt_ofo) {
                $stmt_ofo->bind_param("i", $learnerID);
                $stmt_ofo->execute();
                $result_ofo = $stmt_ofo->get_result();
                
                if ($result_ofo && $result_ofo->num_rows > 0) {
                    $row_ofo = $result_ofo->fetch_assoc();
                    $ofoNumber = $row_ofo['OFOcode'] ?? null;
                }
                $stmt_ofo->close();
            }
        }
    }
    
    // Default to electrician if still not set
    if (!$ofoNumber) {
        $ofoNumber = '671101';
    }
    
    // Auto-detect trade from OFO if not provided
    if (!$trade) {
        $trade = getTradeName($ofoNumber);
    }
    
    if ($learnerID <= 0) {
        throw new Exception('Missing or invalid learnerID');
    }
    
    // Get table names for this trade
    $tableF = getTableName('f', $trade);
    $tableF_tasks = getTableName('f_tasks', $trade);
    $tableF_obs = getTableName('f_obs', $trade);
    
    if (!$tableF || !$tableF_tasks || !$tableF_obs) {
        throw new Exception('Invalid trade specified');
    }
    
    // Start transaction
    $conn->begin_transaction();
    
    // ══════════════════════════════════════════════════════════
    // Save Main Appendix F Data
    // ══════════════════════════════════════════════════════════
    $sqlF = "
        INSERT INTO `".$conn->real_escape_string($tableF)."` 
        (learnerID, ofo_number, assessor_name, candidate_name, witness_name, assessment_date, authorized_date)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        assessor_name = VALUES(assessor_name),
        candidate_name = VALUES(candidate_name),
        witness_name = VALUES(witness_name),
        assessment_date = VALUES(assessment_date),
        authorized_date = VALUES(authorized_date),
        updated_at = CURRENT_TIMESTAMP
    ";
    
    $stmt = $conn->prepare($sqlF);
    
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param('issssss', $learnerID, $ofoNumber, $assessorName, $candidateName, $witnessName, $assessmentDate, $authorizedDate);
    
    if (!$stmt->execute()) {
        throw new Exception("Execute failed: " . $stmt->error);
    }
    $stmt->close();
    
    // ══════════════════════════════════════════════════════════
    // Delete Old Practical Tasks (will replace with new ones)
    // ══════════════════════════════════════════════════════════
    $sqlDelete = "
        DELETE FROM `".$conn->real_escape_string($tableF_tasks)."`
        WHERE learnerID = ? AND ofo_number = ?
    ";
    
    $stmt = $conn->prepare($sqlDelete);
    
    if ($stmt) {
        $stmt->bind_param('is', $learnerID, $ofoNumber);
        $stmt->execute();
        $stmt->close();
    }
    
    // ══════════════════════════════════════════════════════════
    // Save Practical Tasks
    // ══════════════════════════════════════════════════════════
    $sqlTasks = "
        INSERT INTO `".$conn->real_escape_string($tableF_tasks)."`
        (learnerID, ofo_number, task_number, task_name, score, percentage)
        VALUES (?, ?, ?, ?, ?, ?)
    ";
    
    $stmt = $conn->prepare($sqlTasks);
    
    if (!$stmt) {
        throw new Exception("Prepare practical_tasks failed: " . $conn->error);
    }
    
    foreach ($practicalTasks as $task) {
        $taskNum = intval($task['taskNumber'] ?? 0);
        $taskName = $task['taskName'] ?? '';
        $score = intval($task['score'] ?? 0);
        $percentage = floatval($task['percentage'] ?? 0);
        
        $stmt->bind_param('isisid', $learnerID, $ofoNumber, $taskNum, $taskName, $score, $percentage);
        
        if (!$stmt->execute()) {
            throw new Exception("Execute practical_tasks failed: " . $stmt->error);
        }
    }
    $stmt->close();
    
    // ══════════════════════════════════════════════════════════
    // Delete Old Workplace Observations (will replace with new ones)
    // ══════════════════════════════════════════════════════════
    $sqlDeleteObs = "
        DELETE FROM `".$conn->real_escape_string($tableF_obs)."`
        WHERE learnerID = ? AND ofo_number = ?
    ";
    
    $stmt = $conn->prepare($sqlDeleteObs);
    
    if ($stmt) {
        $stmt->bind_param('is', $learnerID, $ofoNumber);
        $stmt->execute();
        $stmt->close();
    }
    
    // ══════════════════════════════════════════════════════════
    // Save Workplace Observations
    // ══════════════════════════════════════════════════════════
    $sqlObs = "
        INSERT INTO `".$conn->real_escape_string($tableF_obs)."`
        (learnerID, ofo_number, observation_number, task_observed, technical_knowledge, interpretation, team_work)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ";
    
    $stmt = $conn->prepare($sqlObs);
    
    if (!$stmt) {
        throw new Exception("Prepare workplace_observations failed: " . $conn->error);
    }
    
    foreach ($workplaceObservations as $obs) {
        $obsNum = intval($obs['observationNumber'] ?? 0);
        $taskObs = $obs['taskObserved'] ?? '';
        $techKnowledge = $obs['technicalKnowledge'] ?? '';
        $interpretation = $obs['interpretation'] ?? '';
        $teamWork = $obs['teamWork'] ?? '';
        
        $stmt->bind_param('isissss', $learnerID, $ofoNumber, $obsNum, $taskObs, $techKnowledge, $interpretation, $teamWork);
        
        if (!$stmt->execute()) {
            throw new Exception("Execute workplace_observations failed: " . $stmt->error);
        }
    }
    $stmt->close();
    
    // Commit transaction
    $conn->commit();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Appendix F assessment saved successfully',
        'learnerID' => $learnerID,
        'ofoNumber' => $ofoNumber,
        'trade' => $trade,
        'practicalTasksCount' => count($practicalTasks),
        'workplaceObservationsCount' => count($workplaceObservations)
    ]);
    
} catch (Exception $e) {
    // Rollback transaction on error
    if (isset($conn)) {
        $conn->rollback();
    }
    
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'error_details' => $e->getTraceAsString()
    ]);
}
?>
