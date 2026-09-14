<?php
/**
 * ARPL APPENDIX D: Save Practical Skills Assessment Evaluation Checklist
 * Endpoint: POST /mobile/save_arpl_appendix_d.php
 * 
 * Saves Yes/No responses for the 22 practical skills assessment activities
 * for Appendix D of ARPL (Assessor Review and Professional Learning)
 * 
 * Request body (JSON):
 * {
 *   "learnerID": 11515,
 *   "assessor_id": 1,
 *   "ofo_number": "671101",
 *   "activities": {
 *     "1": "yes",    // or "no"
 *     "2": "no",
 *     ...
 *     "22": "yes"
 *   }
 * }
 * 
 * Response:
 * {
 *   "status": "success" | "error",
 *   "message": "Appendix D saved successfully",
 *   "data": {
 *     "id": 123,
 *     "learnerID": 11515,
 *     "updated_at": "2026-07-07 17:15:00"
 *   }
 * }
 */

header('Content-Type: application/json');

try {
    // Get request body - support both POST JSON and GET/POST parameters
    $input = json_decode(file_get_contents('php://input'), true);
    
    // If no JSON input, check for GET or POST parameters
    if (!$input) {
        $input = array_merge($_GET, $_POST);
        
        // If activities is a JSON string, decode it
        if (isset($input['activities']) && is_string($input['activities'])) {
            $input['activities'] = json_decode($input['activities'], true);
        }
    }
    
    if (empty($input)) {
        throw new Exception('Invalid JSON input or parameters');
    }
    
    // Validate required fields
    $required = ['learnerID', 'assessor_id', 'ofo_number', 'activities'];
    foreach ($required as $field) {
        if (!isset($input[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    $learnerID = intval($input['learnerID']);
    $assessor_id = intval($input['assessor_id']);
    $ofo_number = $input['ofo_number'];
    $activities = $input['activities'];
    
    // Database connection
    require_once 'connection.php';
    
    if (!$conn) {
        throw new Exception('Database connection failed');
    }
    
    // Check if assessment already exists
    $stmt = $conn->prepare("
        SELECT id FROM arpl_appendix_d 
        WHERE learnerID = ? AND assessor_id = ? AND ofo_number = ?
    ");
    
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }
    
    $stmt->bind_param('iis', $learnerID, $assessor_id, $ofo_number);
    $stmt->execute();
    $result = $stmt->get_result();
    $existing = $result->fetch_assoc();
    $stmt->close();
    
    // Build column assignments for activities
    $updates = [];
    $params = [];
    $param_types = '';
    
    for ($i = 1; $i <= 22; $i++) {
        if (isset($activities[$i])) {
            $response = strtolower($activities[$i]);
            if ($response === 'yes' || $response === 'no' || $response === 'pending') {
                $updates[] = "activity_{$i} = ?";
                $params[] = $response;
                $param_types .= 's';
            }
        }
    }
    
    // Add update timestamp
    $updates[] = "updated_at = NOW()";
    $param_types .= '';
    
    if ($existing) {
        // UPDATE existing assessment
        $sql = "UPDATE arpl_appendix_d SET " . implode(', ', $updates) . 
               " WHERE learnerID = ? AND assessor_id = ? AND ofo_number = ?";
        
        $params[] = $learnerID;
        $params[] = $assessor_id;
        $params[] = $ofo_number;
        $param_types .= 'iis';
        
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception('Prepare failed: ' . $conn->error);
        }
        
        $stmt->bind_param($param_types, ...$params);
        $stmt->execute();
        
        if ($stmt->error) {
            throw new Exception('Update failed: ' . $stmt->error);
        }
        
        $assessment_id = $existing['id'];
        $stmt->close();
        $message = 'Appendix D assessment updated successfully';
        
    } else {
        // INSERT new assessment
        $columns = ['learnerID', 'assessor_id', 'ofo_number'];
        $values = ['?', '?', '?'];
        $insert_params = [$learnerID, $assessor_id, $ofo_number];
        $insert_types = 'iis';
        
        for ($i = 1; $i <= 22; $i++) {
            if (isset($activities[$i])) {
                $response = strtolower($activities[$i]);
                if ($response === 'yes' || $response === 'no' || $response === 'pending') {
                    $columns[] = "activity_{$i}";
                    $values[] = '?';
                    $insert_params[] = $response;
                    $insert_types .= 's';
                }
            }
        }
        
        $sql = "INSERT INTO arpl_appendix_d (" . implode(', ', $columns) . ") VALUES (" . implode(', ', $values) . ")";
        
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception('Prepare failed: ' . $conn->error);
        }
        
        $stmt->bind_param($insert_types, ...$insert_params);
        $stmt->execute();
        
        if ($stmt->error) {
            throw new Exception('Insert failed: ' . $stmt->error);
        }
        
        $assessment_id = $conn->insert_id;
        $stmt->close();
        $message = 'Appendix D assessment created successfully';
    }
    
    // Success response
    echo json_encode([
        'status' => 'success',
        'message' => $message,
        'data' => [
            'id' => $assessment_id,
            'learnerID' => $learnerID,
            'assessor_id' => $assessor_id,
            'ofo_number' => $ofo_number,
            'updated_at' => date('Y-m-d H:i:s')
        ]
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
