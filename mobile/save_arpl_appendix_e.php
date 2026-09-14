<?php
/**
 * API Endpoint: Save ARPL Appendix E Activity Ratings - TRADE-AGNOSTIC
 * 
 * Dynamically selects correct table based on OFO number:
 * - 641201 (Bricklayer) → arplappxe_bricklaying_activity_ratings
 * - 671101 (Electrician) → arplappxe_electrician_activity_ratings
 * - 671201 (Plumber) → arplappxe_plumber_activity_ratings
 */

require_once 'connection.php';
header('Content-Type: application/json');

$response = [
    'status' => 'error',
    'message' => '',
    'saved_ratings' => []
];

try {
    // Expecting JSON payload with multiple ratings
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        // Fallback to POST
        $input = $_POST;
    }
    
    $learnerID = isset($input['learnerID']) ? intval($input['learnerID']) : 0;
    $ofo_number = isset($input['ofo_number']) ? $conn->real_escape_string(trim($input['ofo_number'])) : '671101';
    $facilitator_id = isset($input['facilitator_id']) ? intval($input['facilitator_id']) : 0;
    $ratings = isset($input['ratings']) ? $input['ratings'] : [];
    
    if ($learnerID <= 0) {
        throw new Exception("Valid learnerID is required");
    }
    
    if ($facilitator_id <= 0) {
        throw new Exception("Valid facilitator_id is required");
    }
    
    if (empty($ratings)) {
        throw new Exception("No ratings provided");
    }
    
    $conn->begin_transaction();
    $savedCount = 0;
    $errors = [];
    
    // Determine table name based on OFO (trade-agnostic)
    $table_name = '';
    switch ($ofo_number) {
        case '641201': // Bricklayer
            $table_name = 'arplappxe_bricklaying_activity_ratings';
            break;
        case '671101': // Electrician
            $table_name = 'arplappxe_electrician_activity_ratings';
            break;
        case '671201': // Plumber
            $table_name = 'arplappxe_plumber_activity_ratings';
            break;
        default:
            throw new Exception("Unsupported OFO number: $ofo_number. Cannot determine Appendix E table.");
    }
    
    // Verify table exists
    $checkTable = $conn->query("SHOW TABLES LIKE '$table_name'");
    if ($checkTable->num_rows === 0) {
        throw new Exception("Table '$table_name' does not exist for OFO $ofo_number");
    }
    
    foreach ($ratings as $rating) {
        try {
            $activity_id = isset($rating['activity_id']) ? intval($rating['activity_id']) : 0;
            $activity_name = isset($rating['activity_name']) ? $conn->real_escape_string(trim($rating['activity_name'])) : '';
            $competency_scale_id = isset($rating['competency_scale_id']) ? intval($rating['competency_scale_id']) : 0;
            $comments = isset($rating['comments']) ? $conn->real_escape_string(trim($rating['comments'])) : '';
            
            if ($activity_id <= 0) {
                $errors[] = "Skipped: Invalid activity_id ($activity_id)";
                continue; // Skip invalid activities
            }
        
            if ($competency_scale_id < 1 || $competency_scale_id > 5) {
                $errors[] = "Skipped activity $activity_id: Invalid rating ($competency_scale_id)";
                continue; // Skip invalid ratings (must be 1-5)
            }
        
        // Insert or update rating (using dynamic table name)
        $stmt = $conn->prepare("
            INSERT INTO `$table_name` (
                learnerID,
                ofo_number,
                activity_id,
                activity_name,
                competency_scale_id,
                facilitator_id,
                rating_date,
                comments,
                created_at
            ) VALUES (
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                NOW(),
                ?,
                NOW()
            )
            ON DUPLICATE KEY UPDATE
                competency_scale_id = VALUES(competency_scale_id),
                facilitator_id = VALUES(facilitator_id),
                rating_date = NOW(),
                comments = VALUES(comments)
        ");
        
        if (!$stmt) {
            throw new Exception("Prepare failed: " . $conn->error);
        }
        
        $stmt->bind_param('isisisi', 
            $learnerID, 
            $ofo_number, 
            $activity_id, 
            $activity_name, 
            $competency_scale_id, 
            $facilitator_id, 
            $comments
        );
        
        if (!$stmt->execute()) {
            throw new Exception("Execute failed for activity $activity_id: " . $stmt->error);
        }
        
        $stmt->close();
        $savedCount++;
        
        $response['saved_ratings'][] = [
            'activity_id' => $activity_id,
            'activity_name' => $activity_name,
            'rating' => $competency_scale_id
        ];
        
        } catch (Exception $e) {
            $errors[] = "Activity $activity_id error: " . $e->getMessage();
            error_log("Save error for activity $activity_id: " . $e->getMessage());
        }
    }
    
    $conn->commit();
    
    $response['status'] = 'success';
    $response['message'] = "Successfully saved $savedCount activity ratings";
    $response['saved_count'] = $savedCount;
    if (!empty($errors)) {
        $response['errors'] = $errors;
    }
    
} catch (Exception $e) {
    if ($conn) {
        $conn->rollback();
    }
    $response['message'] = $e->getMessage();
    $response['rolled_back'] = true;
    error_log("Error in save_arpl_appendix_e.php: " . $e->getMessage());
}

echo json_encode($response);
?>
