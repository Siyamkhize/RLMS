<?php
header('Content-Type: application/json');
require_once('connection.php');

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['learner_id']) || !isset($input['unit_standards'])) {
    echo json_encode(['success' => false, 'message' => 'Missing required fields']);
    exit;
}

$learner_id = intval($input['learner_id']);
$unit_standards = $input['unit_standards']; // Array of unit standard IDs
$recommendation_id = $input['recommendation_id'] ?? null;
$ofo_code = $input['ofo_code'] ?? '671101';
$trade = $input['trade'] ?? 'Electrician';

if (empty($unit_standards)) {
    echo json_encode(['success' => false, 'message' => 'No unit standards selected']);
    exit;
}

mysqli_begin_transaction($conn);

try {
    // Delete existing gap analysis records for this learner (if re-assigning)
    $query = "DELETE FROM arpl_gap_analysis_unit_standards WHERE learner_id = ?";
    $stmt = mysqli_prepare($conn, $query);
    mysqli_stmt_bind_param($stmt, 'i', $learner_id);
    mysqli_stmt_execute($stmt);
    
    // Save each selected unit standard
    foreach ($unit_standards as $us) {
        $unit_standard_id = intval($us['id']);
        $unit_standard_name = $us['unit_standard_name'];
        $module_code = $us['Module_Code'];
        
        $query = "INSERT INTO arpl_gap_analysis_unit_standards 
                  (learner_id, unit_standard_id, unit_standard_name, module_code, ofo_code, trade, recommendation_id, status) 
                  VALUES (?, ?, ?, ?, ?, ?, ?, 'Pending')";
        $stmt = mysqli_prepare($conn, $query);
        mysqli_stmt_bind_param($stmt, 'iissssi', 
            $learner_id, 
            $unit_standard_id, 
            $unit_standard_name, 
            $module_code, 
            $ofo_code, 
            $trade, 
            $recommendation_id
        );
        mysqli_stmt_execute($stmt);
    }
    
    mysqli_commit($conn);
    
    echo json_encode([
        'success' => true,
        'message' => 'Gap analysis unit standards saved successfully',
        'learner_id' => $learner_id,
        'unit_standards_count' => count($unit_standards)
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    mysqli_rollback($conn);
    echo json_encode(['success' => false, 'message' => 'Error: ' . $e->getMessage()]);
}

mysqli_close($conn);
?>
