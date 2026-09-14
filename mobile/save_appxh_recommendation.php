<?php
header('Content-Type: application/json');
require_once('connection.php');

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['learner_id']) || !isset($input['recommendations'])) {
    echo json_encode(['success' => false, 'message' => 'Missing required fields']);
    exit;
}

$learner_id = intval($input['learner_id']);
$recommendations = $input['recommendations']; // Array of recommendations
$ofo_code = $input['ofo_code'] ?? '671101';
$trade = $input['trade'] ?? 'Electrician';

mysqli_begin_transaction($conn);

try {
    // Delete existing recommendations for this learner
    $query = "DELETE FROM arplelectrician_access_recommendation WHERE LearnerID = ?";
    $stmt = mysqli_prepare($conn, $query);
    mysqli_stmt_bind_param($stmt, 'i', $learner_id);
    mysqli_stmt_execute($stmt);
    
    $last_recommendation_id = null;
    $overall_result_status = null;
    
    // Save all recommendations
    foreach ($recommendations as $rec) {
        $acrid = intval($rec['acrid']);
        $status = $rec['status'];
        $remarks = $rec['remarks'] ?? '';
        
        $query = "INSERT INTO arplelectrician_access_recommendation 
                  (LearnerID, ACRID, Trade, OFOCode, Status, Remarks) 
                  VALUES (?, ?, ?, ?, ?, ?)";
        $stmt = mysqli_prepare($conn, $query);
        mysqli_stmt_bind_param($stmt, 'iissss', $learner_id, $acrid, $trade, $ofo_code, $status, $remarks);
        mysqli_stmt_execute($stmt);
        
        if ($acrid == 4) {
            $last_recommendation_id = mysqli_insert_id($conn);
            $overall_result_status = $status;
        }
    }
    
    // Determine next action based on Overall Result (ACRID 4)
    $next_action = null;
    
    if ($overall_result_status == 'Recommended for trade test') {
        // Save to trade test recommended table
        $query = "INSERT INTO arpl_trade_test_recommended 
                  (learner_id, recommendation_id, ofo_code, trade, test_status) 
                  VALUES (?, ?, ?, ?, 'Pending')";
        $stmt = mysqli_prepare($conn, $query);
        mysqli_stmt_bind_param($stmt, 'iiss', $learner_id, $last_recommendation_id, $ofo_code, $trade);
        mysqli_stmt_execute($stmt);
        
        $next_action = 'trade_test';
    } 
    else if ($overall_result_status == 'Recommended for gap closure') {
        $next_action = 'gap_closure';
    }
    
    mysqli_commit($conn);
    
    echo json_encode([
        'success' => true,
        'message' => 'Recommendations saved successfully',
        'learner_id' => $learner_id,
        'recommendation_id' => $last_recommendation_id,
        'next_action' => $next_action
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    mysqli_rollback($conn);
    echo json_encode(['success' => false, 'message' => 'Error: ' . $e->getMessage()]);
}

mysqli_close($conn);
?>
