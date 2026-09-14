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

/**
 * Securely load signature file and convert to base64 data URL
 * Prevents exposing file paths in API responses
 */
function loadSignatureSecurely($signature) {
    if (empty($signature)) {
        return null;
    }
    
    // Check if signature is a filename (ends with .png, .jpg, etc.)
    if (preg_match('/\.(png|jpg|jpeg|gif)$/i', $signature)) {
        // It's a filename - look for it in the mobile/signatures folder
        $mobilePath = __DIR__ . '/signatures/' . $signature;
        
        if (file_exists($mobilePath)) {
            $imageData = file_get_contents($mobilePath);
            $base64 = base64_encode($imageData);
            return 'data:image/png;base64,' . $base64;
        }
        
        // Try parent signatures folder
        $parentPath = dirname(__DIR__) . '/signatures/' . $signature;
        if (file_exists($parentPath)) {
            $imageData = file_get_contents($parentPath);
            $base64 = base64_encode($imageData);
            return 'data:image/png;base64,' . $base64;
        }
        
        // File not found
        return null;
    }
    
    // If it's already a data URL, use as-is
    if (strpos($signature, 'data:image') === 0) {
        return $signature;
    }
    
    // If it's just base64, prepend data URL prefix
    if (!empty($signature)) {
        return 'data:image/png;base64,' . $signature;
    }
    
    return null;
}

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
    
    // FUNCTION to find a checklist with fallback levels of strictness
    function findChecklist($conn, $learner_id, $assessor_id, $assessment_date) {
        // Level 1: Strict match (Learner + Assessor + Date)
        $res = checkDatabase($conn, $learner_id, $assessor_id, $assessment_date);
        if ($res) return $res;
        
        // Level 2: Learner + Assessor
        $res = checkDatabase($conn, $learner_id, $assessor_id, null);
        if ($res) return $res;
        
        // Level 3: Learner only
        $res = checkDatabase($conn, $learner_id, null, null);
        if ($res) return $res;
        
        return null;
    }
    
    function checkDatabase($conn, $learner_id, $assessor_id, $assessment_date) {
        // Try scanned documents first
        $sql = "SELECT * FROM pothole_checklist_scanned_documents WHERE learner_id = ?";
        $params = [$learner_id];
        $types = "s";
        if ($assessor_id) { $sql .= " AND assessor_id = ?"; $params[] = $assessor_id; $types .= "s"; }
        if ($assessment_date) { $sql .= " AND assessment_date = ?"; $params[] = $assessment_date; $types .= "s"; }
        $sql .= " ORDER BY created_at DESC LIMIT 1";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($row = $result->fetch_assoc()) {
            $row['type'] = 'scanned';
            return $row;
        }
        $stmt->close();
        
        // Try system-generated checklists
        $sql = "SELECT * FROM pothole_checklists WHERE learner_id = ?";
        $params = [$learner_id];
        $types = "s";
        if ($assessor_id) { $sql .= " AND assessor_id = ?"; $params[] = $assessor_id; $types .= "s"; }
        if ($assessment_date) { $sql .= " AND assessment_date = ?"; $params[] = $assessment_date; $types .= "s"; }
        $sql .= " ORDER BY assessment_date DESC LIMIT 1";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($row = $result->fetch_assoc()) {
            $row['type'] = 'system';
            return $row;
        }
        $stmt->close();

        // Try pothole_checklist_marks (if marks exist, we should show the checklist)
        $sql = "SELECT * FROM pothole_checklist_marks WHERE learner_id = ?";
        $params = [$learner_id];
        $types = "s";
        if ($assessor_id) { $sql .= " AND assessor_id = ?"; $params[] = $assessor_id; $types .= "s"; }
        if ($assessment_date) { $sql .= " AND assessment_date = ?"; $params[] = $assessment_date; $types .= "s"; }
        $sql .= " ORDER BY assessment_date DESC LIMIT 1";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($row = $result->fetch_assoc()) {
            $row['type'] = 'system'; // Treat as system if marks exist
            return $row;
        }
        $stmt->close();
        
        return null;
    }

    $checklist = findChecklist($conn, $learner_id, $assessor_id, $assessment_date);
    
    if ($checklist) {
        if ($checklist['type'] == 'scanned') {
            // Found scanned document
            $row = $checklist;
            
            // Fetch marks from logbook_marks table
            $marks_sql = "SELECT id, unit_standard_id, marks, moderator_status, moderator_comment, moderator_id, moderation_date, assessor_comment 
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
                    'document_path' => $row['document_path'] ?? '',
                    'created_at' => $row['created_at'] ?? '',
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
            // Found system-generated checklist or marks
            $row = $checklist;
            $checklist_id = $row['id'];
            
            // Now fetch the checklist items
            $organized_items = [];
            if (isset($row['learner_name'])) { // It's from pothole_checklists table
                $items_sql = "SELECT section, label, value, notes FROM pothole_checklist_items WHERE checklist_id = ? ORDER BY id";
                $items_stmt = $conn->prepare($items_sql);
                $items_stmt->bind_param("i", $checklist_id);
                $items_stmt->execute();
                $items_result = $items_stmt->get_result();
                
                while ($item = $items_result->fetch_assoc()) {
                    $section = $item['section'];
                    if (!isset($organized_items[$section])) $organized_items[$section] = [];
                    $organized_items[$section][] = [
                        'label' => $item['label'],
                        'value' => (bool)$item['value'],
                        'notes' => $item['notes'] ?? ''
                    ];
                }
                $items_stmt->close();
            }
            
            // Fetch marks from logbook_marks table
            $marks_sql = "SELECT id, unit_standard_id, marks, moderator_status, moderator_comment, moderator_id, moderation_date, assessor_comment 
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
            
            // Secure signature handling - never expose file URLs
            $learnerSig = loadSignatureSecurely($row['learner_signature'] ?? '');
            $assessorSig = loadSignatureSecurely($row['assessor_signature'] ?? '');
            
            echo json_encode([
                'status' => 'success',
                'data' => [
                    'id' => $row['id'],
                    'type' => 'system',
                    'learner_id' => $row['learner_id'],
                    'learner_name' => $row['learner_name'] ?? '',
                    'learner_id_number' => $row['learner_id_number'] ?? '',
                    'assessor_id' => $row['assessor_id'],
                    'assessor_name' => $row['assessor_name'] ?? '',
                    'assessor_reg_number' => $row['assessor_reg_number'] ?? '',
                    'venue' => $row['venue'] ?? '',
                    'assessment_date' => $row['assessment_date'],
                    'learner_signature' => $learnerSig,
                    'assessor_signature' => $assessorSig,
                    'notes' => $row['notes'] ?? '',
                    'checklist_items' => $organized_items,
                    'created_at' => $row['created_at'] ?? '',
                    'updated_at' => $row['updated_at'] ?? '',
                    'moderator_status' => $row['moderator_status'] ?? '',
                    'moderator_comment' => $row['moderator_comment'] ?? '',
                    'moderator_id' => $row['moderator_id'] ?? '',
                    'moderation_date' => $row['moderation_date'] ?? '',
                    'marks_scored' => $row['marks_scored'] ?? ($row['marks'] ?? ''),
                    'assessor_comment' => $row['assessor_comment'] ?? ($row['comments'] ?? ''),
                    'unit_standards' => $unit_standards
                ]
            ]);
        }
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'No checklist or marks found for this learner'
        ]);
    }
    
    $conn->close();
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>