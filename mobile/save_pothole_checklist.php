<?php
/**
 * Save Pothole Checklist API
 * Handles POST for saving checklists (separate from list endpoint)
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Enable error reporting for debugging (remove in production)
error_reporting(E_ALL);
ini_set('display_errors', 1);

try {
    // Handle preflight requests
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit();
    }

    // Only allow POST
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
        exit();
    }

    // Database configuration
    require_once 'connection.php';

    // Parse input
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input || !is_array($input)) {
        throw new Exception('Invalid JSON input');
    }

    // Log input for debugging (remove in production)
    error_log("Received input: " . json_encode($input));

    // Extract fields from app form
    $learner_id = trim($input['learner_id'] ?? '');
    $learner_name = trim($input['learner_name'] ?? '');
    $learner_id_number = trim($input['learner_id_number'] ?? '');
    $assessor_id = trim($input['assessor_id'] ?? '');
    $assessor_name = trim($input['assessor_name'] ?? '');
    $assessor_reg_number = trim($input['assessor_reg_number'] ?? '');
    $venue = trim($input['venue'] ?? '');
    $assessment_date = trim($input['assessment_date'] ?? '');
    $notes = trim($input['notes'] ?? '');  // Global notes, if provided
    $learner_signature = trim($input['learner_signature'] ?? '');
    $assessor_signature = trim($input['assessor_signature'] ?? '');

    // Validation
    if (empty($learner_id) || empty($learner_name) || empty($assessor_id) || empty($assessor_name) || empty($venue) || empty($assessment_date)) {
        throw new Exception('Required fields missing: learner_id, learner_name, assessor_id, assessor_name, venue, assessment_date');
    }
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $assessment_date)) {
        throw new Exception('Valid assessment date is required (YYYY-MM-DD format)');
    }

    $conn->set_charset('utf8mb4');
    $conn->autocommit(false);

    // Check for existing checklist (to avoid unique constraint violation)
    $checkQuery = "SELECT id FROM pothole_checklists WHERE learner_id = ? AND assessor_id = ? AND assessment_date = ?";
    $checkStmt = $conn->prepare($checkQuery);
    if (!$checkStmt) {
        throw new Exception('Prepare failed for duplicate check: ' . $conn->error);
    }
    $checkStmt->bind_param('sss', $learner_id, $assessor_id, $assessment_date);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();
    if ($checkResult->num_rows > 0) {
        $checkStmt->close();
        throw new Exception('Checklist already exists for this learner, assessor, and date');
    }
    $checkStmt->close();

    // Insert main checklist
    $insertQuery = "INSERT INTO pothole_checklists 
                    (learner_id, learner_name, learner_id_number, assessor_id, assessor_name, 
                     assessor_reg_number, venue, assessment_date, notes, 
                     learner_signature, assessor_signature, created_at, updated_at) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())";
    
    $insertStmt = $conn->prepare($insertQuery);
    if (!$insertStmt) {
        throw new Exception('Prepare failed for main insert: ' . $conn->error);
    }
    $insertStmt->bind_param('sssssssssss', 
        $learner_id, $learner_name, $learner_id_number, 
        $assessor_id, $assessor_name, $assessor_reg_number, 
        $venue, $assessment_date, $notes, $learner_signature, $assessor_signature
    );
    if (!$insertStmt->execute()) {
        throw new Exception('Main insert failed: ' . $insertStmt->error);
    }
    $checklist_id = $conn->insert_id;
    $insertStmt->close();

    // Insert checklist items if provided
    $itemsSaved = 0;
    if (isset($input['checklist_items']) && is_array($input['checklist_items'])) {
        $itemQuery = "INSERT INTO pothole_checklist_items (checklist_id, section, label, value, notes) VALUES (?, ?, ?, ?, ?)";
        $itemStmt = $conn->prepare($itemQuery);
        if (!$itemStmt) {
            throw new Exception('Prepare failed for items insert: ' . $conn->error);
        }
        
        foreach ($input['checklist_items'] as $item) {
            $section = trim($item['section'] ?? '');
            $label = trim($item['label'] ?? '');
            $value = null;
            if (isset($item['value'])) {
                $val = $item['value'];
                $value = ($val === true || $val === 1 || $val === '1') ? 1 : (($val === false || $val === 0 || $val === '0') ? 0 : null);
            }
            $item_notes = trim($item['notes'] ?? '');
            
            if (!empty($section) && !empty($label)) {
                $itemStmt->bind_param('issis', $checklist_id, $section, $label, $value, $item_notes);
                if (!$itemStmt->execute()) {
                    // Log but continue for other items
                    error_log("Item insert failed for label '$label': " . $itemStmt->error);
                } else {
                    $itemsSaved++;
                }
            }
        }
        $itemStmt->close();
    }

    // Log to audit table
    $auditQuery = "INSERT INTO pothole_checklist_audit (checklist_id, action, changed_by, change_details) VALUES (?, 'INSERT', ?, ?)";
    $auditStmt = $conn->prepare($auditQuery);
    if (!$auditStmt) {
        error_log('Prepare failed for audit insert: ' . $conn->error);
    } else {
        $change_details = json_encode([
            'learner_id' => $learner_id,
            'assessment_date' => $assessment_date,
            'items_saved' => $itemsSaved
        ]);
        $auditStmt->bind_param('iss', $checklist_id, $assessor_id, $change_details);
        if (!$auditStmt->execute()) {
            error_log('Audit insert failed: ' . $auditStmt->error);
        }
        $auditStmt->close();
    }

    $conn->commit();
    $conn->close();
    
    echo json_encode([
        'status' => 'success',
        'message' => "Checklist saved successfully. Items saved: $itemsSaved",
        'data' => ['checklist_id' => $checklist_id]
    ]);
    
} catch (Exception $e) {
    // Enhanced error logging
    error_log("Pothole save error: " . $e->getMessage() . "\nInput: " . json_encode($input ?? 'no input'));
    
    if (isset($conn)) {
        $conn->rollback();
        $conn->close();
    }
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
} catch (Throwable $t) {
    // Catch fatal errors too
    error_log("Pothole save fatal: " . $t->getMessage() . "\nStack trace: " . $t->getTraceAsString());
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Internal server error. Check logs for details.'
    ]);
}
?>