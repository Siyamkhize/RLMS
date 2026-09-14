<?php
/**
 * ARPL Endpoint: Get Appeals Data (Appendix H)
 * Retrieves learner appeals and appeal outcomes
 * Note: Appeals are typically stored with assessment records
 */

require_once 'connection.php';
header('Content-Type: application/json');

$response = [
    'status' => 'error',
    'message' => '',
    'appeals' => []
];

try {
    $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0);
    $ofo_code = isset($_POST['ofo_code']) ? trim($_POST['ofo_code']) : (isset($_GET['ofo_code']) ? trim($_GET['ofo_code']) : '');
    
    if ($learnerID <= 0) {
        throw new Exception("Valid learnerID required");
    }
    
    // Currently appeals might be stored in assessment responses or a dedicated table
    // Check if an appeals table exists
    $result = $conn->query("SHOW TABLES LIKE 'arpl_appeals%'");
    
    if ($result && $result->num_rows > 0) {
        while ($row = $result->fetch_row()) {
            $table = $row[0];
            $stmt = $conn->prepare("SELECT * FROM $table WHERE learnerID = ? ORDER BY created_at DESC");
            if ($stmt) {
                $stmt->bind_param("i", $learnerID);
                $stmt->execute();
                $result = $stmt->get_result();
                
                while ($appeal = $result->fetch_assoc()) {
                    $response['appeals'][] = $appeal;
                }
                $stmt->close();
            }
        }
    }
    
    $response['status'] = 'success';
    $response['message'] = 'Appeals data retrieved successfully';
    $response['appeals_count'] = count($response['appeals']);

} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in get_arpl_appeals.php: " . $e->getMessage());
}

echo json_encode($response);
?>
