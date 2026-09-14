<?php
/**
 * ARPL Endpoint: Get Gap Analysis Data (Appendix D)
 * Retrieves gap analysis findings and unit standards
 * Database: arpl_appendix_d, gap_analysis_report
 */

require_once 'connection.php';
header('Content-Type: application/json');

$response = [
    'status' => 'error',
    'message' => '',
    'gap_analysis' => null,
    'unit_standards' => []
];

try {
    $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0);
    $ofo_code = isset($_POST['ofo_code']) ? trim($_POST['ofo_code']) : (isset($_GET['ofo_code']) ? trim($_GET['ofo_code']) : '');
    
    if ($learnerID <= 0) {
        throw new Exception("Valid learnerID required");
    }
    
    // Get main gap analysis data
    $stmt = $conn->prepare("
        SELECT * FROM arpl_appendix_d 
        WHERE learnerID = ? 
        ORDER BY created_at DESC 
        LIMIT 1
    ");
    
    if ($stmt) {
        $stmt->bind_param("i", $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            $response['gap_analysis'] = $result->fetch_assoc();
        }
        $stmt->close();
    }
    
    // Get gap analysis unit standards
    $stmt = $conn->prepare("
        SELECT * FROM arpl_gap_analysis_unit_standards 
        WHERE learnerID = ? 
        ORDER BY unit_standard_id ASC
    ");
    
    if ($stmt) {
        $stmt->bind_param("i", $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $response['unit_standards'][] = $row;
        }
        $stmt->close();
    }
    
    $response['status'] = 'success';
    $response['message'] = 'Gap analysis data retrieved successfully';
    $response['unit_standards_count'] = count($response['unit_standards']);

} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in get_arpl_gap_analysis.php: " . $e->getMessage());
}

echo json_encode($response);
?>
