<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'config.php';

// Get JSON input
$input = file_get_contents('php://input');
$data = json_decode($input, true);

// Validate required fields
$required_fields = ['learner_id', 'learner_name', 'assessor_id', 'assessor_name', 'venue', 'assessment_date', 'checklist_items'];
foreach ($required_fields as $field) {
    if (!isset($data[$field]) || empty($data[$field])) {
        echo json_encode([
            'status' => 'error',
            'message' => "Missing required field: $field"
        ]);
        exit();
    }
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8mb4");
    
    // Prepare data
    $learner_id = $conn->real_escape_string($data['learner_id']);
    $learner_name = $conn->real_escape_string($data['learner_name']);
    $learner_id_number = isset($data['learner_id_number']) ? $conn->real_escape_string($data['learner_id_number']) : '';
    $assessor_id = $conn->real_escape_string($data['assessor_id']);
    $assessor_name = $conn->real_escape_string($data['assessor_name']);
    $assessor_reg_number = isset($data['assessor_reg_number']) ? $conn->real_escape_string($data['assessor_reg_number']) : '';
    $venue = $conn->real_escape_string($data['venue']);
    $assessment_date = $conn->real_escape_string($data['assessment_date']);
    $learner_signature = isset($data['learner_signature']) ? $conn->real_escape_string($data['learner_signature']) : '';
    $assessor_signature = isset($data['assessor_signature']) ? $conn->real_escape_string($data['assessor_signature']) : '';
    
    // Start transaction
    $conn->begin_transaction();
    
    try {
        // Insert or update main checklist record
        $sql = "INSERT INTO pothole_checklists 
                (learner_id, learner_name, learner_id_number, assessor_id, assessor_name, 
                 assessor_reg_number, venue, assessment_date, learner_signature, 
                 assessor_signature, notes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                learner_name = VALUES(learner_name),
                learner_id_number = VALUES(learner_id_number),
                assessor_name = VALUES(assessor_name),
                assessor_reg_number = VALUES(assessor_reg_number),
                venue = VALUES(venue),
                learner_signature = VALUES(learner_signature),
                assessor_signature = VALUES(assessor_signature),
                notes = VALUES(notes),
                updated_at = CURRENT_TIMESTAMP";
        
        $notes = ''; // Can be used for general notes
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param(
            "sssssssssss",
            $learner_id,
            $learner_name,
            $learner_id_number,
            $assessor_id,
            $assessor_name,
            $assessor_reg_number,
            $venue,
            $assessment_date,
            $learner_signature,
            $assessor_signature,
            $notes
        );
        
        if (!$stmt->execute()) {
            throw new Exception("Error saving checklist: " . $stmt->error);
        }
        
        // Get the checklist ID (either newly inserted or existing)
        $checklist_id = $stmt->insert_id > 0 ? $stmt->insert_id : $conn->insert_id;
        
        // If insert_id is 0, it means we updated an existing record, so we need to get its ID
        if ($checklist_id == 0) {
            $id_sql = "SELECT id FROM pothole_checklists 
                       WHERE learner_id = ? AND assessor_id = ? AND assessment_date = ? 
                       LIMIT 1";
            $id_stmt = $conn->prepare($id_sql);
            $id_stmt->bind_param("sss", $learner_id, $assessor_id, $assessment_date);
            $id_stmt->execute();
            $id_result = $id_stmt->get_result();
            if ($id_row = $id_result->fetch_assoc()) {
                $checklist_id = $id_row['id'];
            }
            $id_stmt->close();
        }
        
        $stmt->close();
        
        // Delete existing items for this checklist (for updates)
        $delete_sql = "DELETE FROM pothole_checklist_items WHERE checklist_id = ?";
        $delete_stmt = $conn->prepare($delete_sql);
        $delete_stmt->bind_param("i", $checklist_id);
        $delete_stmt->execute();
        $delete_stmt->close();
        
        // Insert checklist items into separate table
        $item_sql = "INSERT INTO pothole_checklist_items 
                     (checklist_id, section, label, value, notes) 
                     VALUES (?, ?, ?, ?, ?)";
        $item_stmt = $conn->prepare($item_sql);
        
        foreach ($data['checklist_items'] as $item) {
            $section = $item['section'];
            $label = $item['label'];
            $value = $item['value'] ? 1 : 0; // Convert boolean to tinyint
            $item_notes = isset($item['notes']) ? $item['notes'] : '';
            
            $item_stmt->bind_param("issis", $checklist_id, $section, $label, $value, $item_notes);
            if (!$item_stmt->execute()) {
                throw new Exception("Error saving checklist item: " . $item_stmt->error);
            }
        }
        
        $item_stmt->close();
        
        // Commit transaction
        $conn->commit();
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Pothole checklist saved successfully',
            'checklist_id' => $checklist_id
        ]);
        
    } catch (Exception $e) {
        // Rollback on error
        $conn->rollback();
        throw $e;
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
