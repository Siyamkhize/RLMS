<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

try {
    // Get JSON input
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON data');
    }
    
    $learnerId = $data['learnerId'] ?? '';
    $assessmentType = $data['assessmentType'] ?? '';
    $unitStandardName = $data['unitStandardName'] ?? '';
    $moderatorStatus = $data['moderatorStatus'] ?? '';
    $moderatorComment = $data['moderatorComment'] ?? '';
    $moderatorId = $data['moderatorId'] ?? '';
    
    if (empty($learnerId) || empty($assessmentType) || empty($moderatorStatus)) {
        throw new Exception('Missing required fields');
    }
    
    // Determine which table to update based on assessment type
    $table = '';
    $whereClause = '';
    
    switch ($assessmentType) {
        case 'formative':
        case 'summative':
            $table = 'assessments';
            $whereClause = "learner_id = ? AND type = ? AND unit_standard_name = ?";
            break;
            
        case 'logbook':
            $table = 'logbook_marks';
            $whereClause = "learner_id = ? AND unit_standard_name = ?";
            break;
            
        case 'pothole_checklist':
            // Pothole marks are stored in logbook_marks table with unit_standard_id containing 'pothole'
            $table = 'logbook_marks';
            $whereClause = "learner_id = ? AND unit_standard_id LIKE '%pothole%'";
            break;
            
        default:
            throw new Exception('Invalid assessment type');
    }
    
    // Update the moderation status
    if ($assessmentType === 'logbook') {
        $sql = "UPDATE $table 
                SET moderator_status = ?, 
                    moderator_comment = ?,
                    moderator_id = ?,
                    moderation_date = NOW()
                WHERE $whereClause";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param('ssss', $moderatorStatus, $moderatorComment, $moderatorId, $learnerId, $unitStandardName);
        $stmt->execute();
        
        $affectedRows = $stmt->affected_rows;
    } else if ($assessmentType === 'pothole_checklist') {
        // Pothole marks are in logbook_marks table
        $sql = "UPDATE $table 
                SET moderator_status = ?, 
                    moderator_comment = ?,
                    moderator_id = ?,
                    moderation_date = NOW()
                WHERE $whereClause";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param('ssss', $moderatorStatus, $moderatorComment, $moderatorId, $learnerId);
        $stmt->execute();
        
        $affectedRows = $stmt->affected_rows;
    } else {
        // formative or summative
        $sql = "UPDATE $table 
                SET moderator_status = ?, 
                    moderator_comment = ?,
                    moderator_id = ?,
                    moderation_date = NOW()
                WHERE $whereClause";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param('sssss', $moderatorStatus, $moderatorComment, $moderatorId, $learnerId, $assessmentType, $unitStandardName);
        $stmt->execute();
        
        $affectedRows = $stmt->affected_rows;
    }
    
    if ($affectedRows > 0) {
        echo json_encode([
            'status' => 'success',
            'message' => 'Moderation status updated successfully',
            'affected_rows' => $affectedRows
        ]);
    } else {
        echo json_encode([
            'status' => 'warning',
            'message' => 'No records were updated. The assessment may not exist or is already moderated.',
            'affected_rows' => 0
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
