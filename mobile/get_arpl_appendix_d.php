<?php
/**
 * ARPL APPENDIX D: Get Practical Skills Assessment Evaluation Checklist
 * Endpoint: GET /mobile/get_arpl_appendix_d.php?learnerID=11515&assessor_id=1&ofo_number=671101
 * 
 * Retrieves Yes/No responses for the 22 practical skills assessment activities
 * 
 * Query parameters:
 * - learnerID (required): Learner database ID
 * - assessor_id (optional): Facilitator ID - if provided with learnerID, returns specific assessment
 * - ofo_number (optional): OFO code - used with learnerID/assessor_id
 * 
 * Response:
 * {
 *   "status": "success",
 *   "data": {
 *     "id": 123,
 *     "learnerID": 11515,
 *     "assessor_id": 1,
 *     "ofo_number": "671101",
 *     "activities": {
 *       "1": "yes",
 *       "2": "no",
 *       ...
 *       "22": "pending"
 *     },
 *     "created_at": "2026-07-07 17:10:00",
 *     "updated_at": "2026-07-07 17:15:00"
 *   }
 * }
 */

header('Content-Type: application/json');

try {
    // Validate required parameters
    if (!isset($_GET['learnerID'])) {
        throw new Exception('Missing required parameter: learnerID');
    }
    
    $learnerID = intval($_GET['learnerID']);
    $assessor_id = isset($_GET['assessor_id']) ? intval($_GET['assessor_id']) : null;
    $ofo_number = isset($_GET['ofo_number']) ? $_GET['ofo_number'] : null;
    
    // Database connection
    require_once 'connection.php';
    
    if (!$conn) {
        throw new Exception('Database connection failed');
    }
    
    // Build query
    if ($assessor_id && $ofo_number) {
        // Get specific assessment
        $stmt = $conn->prepare("
            SELECT * FROM arpl_appendix_d 
            WHERE learnerID = ? AND assessor_id = ? AND ofo_number = ?
        ");
        
        if (!$stmt) {
            throw new Exception('Prepare failed: ' . $conn->error);
        }
        
        $stmt->bind_param('iis', $learnerID, $assessor_id, $ofo_number);
        
    } elseif ($ofo_number) {
        // Get all assessments for learner and OFO
        $stmt = $conn->prepare("
            SELECT * FROM arpl_appendix_d 
            WHERE learnerID = ? AND ofo_number = ?
            ORDER BY created_at DESC
        ");
        
        if (!$stmt) {
            throw new Exception('Prepare failed: ' . $conn->error);
        }
        
        $stmt->bind_param('is', $learnerID, $ofo_number);
        
    } else {
        // Get all assessments for learner
        $stmt = $conn->prepare("
            SELECT * FROM arpl_appendix_d 
            WHERE learnerID = ?
            ORDER BY ofo_number, created_at DESC
        ");
        
        if (!$stmt) {
            throw new Exception('Prepare failed: ' . $conn->error);
        }
        
        $stmt->bind_param('i', $learnerID);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode([
            'status' => 'success',
            'message' => 'No assessments found',
            'data' => null
        ]);
        $stmt->close();
        $conn->close();
        exit;
    }
    
    // Fetch and format results
    $assessments = [];
    
    while ($row = $result->fetch_assoc()) {
        $assessment = [
            'id' => $row['id'],
            'learnerID' => $row['learnerID'],
            'assessor_id' => $row['assessor_id'],
            'ofo_number' => $row['ofo_number'],
            'activities' => [],
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at']
        ];
        
        // Extract activities 1-22
        for ($i = 1; $i <= 22; $i++) {
            $key = "activity_{$i}";
            $assessment['activities'][$i] = $row[$key] ?? 'pending';
        }
        
        $assessments[] = $assessment;
    }
    
    $stmt->close();
    
    // Return single assessment or array
    $data = (count($assessments) === 1) ? $assessments[0] : $assessments;
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Assessment(s) retrieved successfully',
        'data' => $data
    ]);
    
    $conn->close();
    
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
