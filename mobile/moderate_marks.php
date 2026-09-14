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
    $data = json_decode(file_get_contents('php://input'), true);
    
    $assessmentType = $data['assessmentType'] ?? ''; // 'logbook' or 'pothole'
    $exerciseId = $data['exerciseId'] ?? '';
    $learnerId = $data['learnerId'] ?? '';
    $moderatorStatus = $data['moderatorStatus'] ?? ''; // 'Upheld' or 'Withdrawn'
    $moderatorComment = $data['moderatorComment'] ?? '';
    $moderatorId = $data['moderatorId'] ?? '';
    
    if (empty($assessmentType) || empty($exerciseId) || empty($learnerId) || empty($moderatorStatus)) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Missing required fields'
        ]);
        exit;
    }
    
    if (!in_array($moderatorStatus, ['Upheld', 'Withdrawn'])) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Invalid moderator status. Must be Upheld or Withdrawn'
        ]);
        exit;
    }
    
    $moderationDate = date('Y-m-d H:i:s');
    
    if ($assessmentType === 'logbook') {
        // Update logbook_marks table
        $stmt = $conn->prepare("
            UPDATE logbook_marks 
            SET moderator_status = ?,
                moderator_comment = ?,
                moderator_id = ?,
                moderation_date = ?
            WHERE id = ? AND learner_id = ?
        ");
        
        $stmt->bind_param(
            'ssssss',
            $moderatorStatus,
            $moderatorComment,
            $moderatorId,
            $moderationDate,
            $exerciseId,
            $learnerId
        );
        
    } elseif ($assessmentType === 'pothole') {
        // Update pothole_checklist_marks table
        $stmt = $conn->prepare("
            UPDATE pothole_checklist_marks 
            SET moderator_status = ?,
                moderator_comment = ?,
                moderator_id = ?,
                moderation_date = ?
            WHERE id = ? AND learner_id = ?
        ");
        
        $stmt->bind_param(
            'ssssss',
            $moderatorStatus,
            $moderatorComment,
            $moderatorId,
            $moderationDate,
            $exerciseId,
            $learnerId
        );
        
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'Invalid assessment type'
        ]);
        exit;
    }
    
    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            echo json_encode([
                'status' => 'success',
                'message' => 'Moderation status updated successfully',
                'moderatorStatus' => $moderatorStatus,
                'moderationDate' => $moderationDate
            ]);
        } else {
            echo json_encode([
                'status' => 'error',
                'message' => 'No records updated. Exercise may not exist or already has this status'
            ]);
        }
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to update moderation status: ' . $stmt->error
        ]);
    }
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>
