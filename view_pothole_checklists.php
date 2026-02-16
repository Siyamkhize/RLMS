<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

// Get query parameters
$learner_id = isset($_GET['learner_id']) ? $_GET['learner_id'] : '';
$assessor_id = isset($_GET['assessor_id']) ? $_GET['assessor_id'] : '';
$assessment_date = isset($_GET['assessment_date']) ? $_GET['assessment_date'] : '';

// Validate required learner_id
if (empty($learner_id)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing required parameter: learner_id is required'
    ]);
    exit();
}

try {
    // Connection is already established in connection.php
    $conn->set_charset("utf8mb4");
    
    // PRIORITY 1: Check for scanned documents first
    $scanned_sql = "SELECT * FROM pothole_checklist_scanned_documents WHERE learner_id = ?";
    $params = [$learner_id];
    $types = "s";
    
    if (!empty($assessor_id)) {
        $scanned_sql .= " AND assessor_id = ?";
        $params[] = $assessor_id;
        $types .= "s";
    }
    
    if (!empty($assessment_date)) {
        $scanned_sql .= " AND assessment_date = ?";
        $params[] = $assessment_date;
        $types .= "s";
    }
    
    $scanned_sql .= " ORDER BY created_at DESC LIMIT 1";
    
    $stmt = $conn->prepare($scanned_sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $scanned_result = $stmt->get_result();
    
    if ($scanned_result->num_rows > 0) {
        // Found scanned document
        $row = $scanned_result->fetch_assoc();
        
        // Fetch marks from logbook_marks table for this learner (pothole checklist unit standards)
        $marks_sql = "SELECT id, unit_standard_id, marks, 
                             moderator_status, moderator_comment, moderator_id, 
                             moderation_date, assessor_comment 
                      FROM logbook_marks 
                      WHERE learner_id = ? 
                      AND (unit_standard_id = '13958' OR unit_standard_id = '14555')
                      ORDER BY unit_standard_id";
        
        $marks_stmt = $conn->prepare($marks_sql);
        $marks_stmt->bind_param("s", $learner_id);
        $marks_stmt->execute();
        $marks_result = $marks_stmt->get_result();
        
        $unit_standards = [];
        while ($mark_row = $marks_result->fetch_assoc()) {
            $unit_standards[] = [
                'id' => $mark_row['id'],
                'unit_standard_id' => $mark_row['unit_standard_id'],
                'unit_standard_name' => 'Unit Standard ' . $mark_row['unit_standard_id'],
                'marks' => (int)$mark_row['marks'],
                'moderator_status' => $mark_row['moderator_status'] ?? '',
                'moderator_comment' => $mark_row['moderator_comment'] ?? '',
                'moderator_id' => $mark_row['moderator_id'] ?? '',
                'moderation_date' => $mark_row['moderation_date'] ?? '',
                'assessor_comment' => $mark_row['assessor_comment'] ?? ''
            ];
        }
        $marks_stmt->close();
        
        echo json_encode([
            'status' => 'success',
            'data' => [
                'id' => $row['id'],
                'type' => 'scanned',
                'learner_id' => $row['learner_id'],
                'assessor_id' => $row['assessor_id'],
                'assessment_date' => $row['assessment_date'],
                'document_path' => $row['document_path'],
                'created_at' => $row['created_at'],
                'moderator_status' => $row['moderator_status'] ?? '',
                'moderator_comment' => $row['moderator_comment'] ?? '',
                'moderator_id' => $row['moderator_id'] ?? '',
                'moderation_date' => $row['moderation_date'] ?? '',
                'marks_scored' => $row['marks_scored'] ?? '',
                'assessor_comment' => $row['assessor_comment'] ?? '',
                'unit_standards' => $unit_standards
            ]
        ]);
        
        $stmt->close();
        $conn->close();
        exit();
    }
    
    $stmt->close();
    
    // PRIORITY 2: Check for system-generated checklists
    $system_sql = "SELECT * FROM pothole_checklists WHERE learner_id = ?";
    $params = [$learner_id];
    $types = "s";
    
    if (!empty($assessor_id)) {
        $system_sql .= " AND assessor_id = ?";
        $params[] = $assessor_id;
        $types .= "s";
    }
    
    if (!empty($assessment_date)) {
        $system_sql .= " AND assessment_date = ?";
        $params[] = $assessment_date;
        $types .= "s";
    }
    
    $system_sql .= " ORDER BY assessment_date DESC LIMIT 1";
    
    $stmt = $conn->prepare($system_sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        $checklist_id = $row['id'];
        
        // Now fetch the checklist items from the separate table
        $items_sql = "SELECT section, label, value, notes 
                      FROM pothole_checklist_items 
                      WHERE checklist_id = ? 
                      ORDER BY id";
        
        $items_stmt = $conn->prepare($items_sql);
        $items_stmt->bind_param("i", $checklist_id);
        $items_stmt->execute();
        $items_result = $items_stmt->get_result();
        
        // Organize items by section
        $organized_items = [];
        while ($item = $items_result->fetch_assoc()) {
            $section = $item['section'];
            if (!isset($organized_items[$section])) {
                $organized_items[$section] = [];
            }
            $organized_items[$section][] = [
                'label' => $item['label'],
                'value' => (bool)$item['value'], // Convert tinyint to boolean
                'notes' => $item['notes'] ?? ''
            ];
        }
        
        $items_stmt->close();
        
        // Fetch marks from logbook_marks table for this learner (pothole checklist unit standards)
        $marks_sql = "SELECT id, unit_standard_id, marks, 
                             moderator_status, moderator_comment, moderator_id, 
                             moderation_date, assessor_comment 
                      FROM logbook_marks 
                      WHERE learner_id = ? 
                      AND (unit_standard_id = '13958' OR unit_standard_id = '14555')
                      ORDER BY unit_standard_id";
        
        $marks_stmt = $conn->prepare($marks_sql);
        $marks_stmt->bind_param("s", $learner_id);
        $marks_stmt->execute();
        $marks_result = $marks_stmt->get_result();
        
        $unit_standards = [];
        while ($mark_row = $marks_result->fetch_assoc()) {
            $unit_standards[] = [
                'id' => $mark_row['id'],
                'unit_standard_id' => $mark_row['unit_standard_id'],
                'unit_standard_name' => 'Unit Standard ' . $mark_row['unit_standard_id'],
                'marks' => (int)$mark_row['marks'],
                'moderator_status' => $mark_row['moderator_status'] ?? '',
                'moderator_comment' => $mark_row['moderator_comment'] ?? '',
                'moderator_id' => $mark_row['moderator_id'] ?? '',
                'moderation_date' => $mark_row['moderation_date'] ?? '',
                'assessor_comment' => $mark_row['assessor_comment'] ?? ''
            ];
        }
        $marks_stmt->close();
        
        echo json_encode([
            'status' => 'success',
            'data' => [
                'id' => $row['id'],
                'type' => 'system',
                'learner_id' => $row['learner_id'],
                'learner_name' => $row['learner_name'],
                'learner_id_number' => $row['learner_id_number'] ?? '',
                'assessor_id' => $row['assessor_id'],
                'assessor_name' => $row['assessor_name'],
                'assessor_reg_number' => $row['assessor_reg_number'] ?? '',
                'venue' => $row['venue'] ?? '',
                'assessment_date' => $row['assessment_date'],
                'learner_signature' => $row['learner_signature'] ?? '',
                'assessor_signature' => $row['assessor_signature'] ?? '',
                'notes' => $row['notes'] ?? '',
                'checklist_items' => $organized_items,
                'created_at' => $row['created_at'] ?? '',
                'updated_at' => $row['updated_at'] ?? '',
                'moderator_status' => $row['moderator_status'] ?? '',
                'moderator_comment' => $row['moderator_comment'] ?? '',
                'moderator_id' => $row['moderator_id'] ?? '',
                'moderation_date' => $row['moderation_date'] ?? '',
                'marks_scored' => $row['marks_scored'] ?? '',
                'assessor_comment' => $row['assessor_comment'] ?? '',
                'unit_standards' => $unit_standards
            ]
        ]);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'No checklist found for the specified parameters'
        ]);
    }
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
