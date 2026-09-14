<?php
/**
 * ARPL Endpoint: Get Trade Curriculum Data (Appendix C)
 * Retrieves curriculum/trade information for the specified OFO code
 * Database: arpl_appendix_c, arpl_appendix_c_bricklayer, arpl_appendix_c_plumber
 */

require_once 'connection.php';
header('Content-Type: application/json');

$response = [
    'status' => 'error',
    'message' => '',
    'curriculum' => null
];

try {
    $ofo_code = isset($_POST['ofo_code']) ? trim($_POST['ofo_code']) : (isset($_GET['ofo_code']) ? trim($_GET['ofo_code']) : '');
    $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0);
    
    if (empty($ofo_code)) {
        throw new Exception("Valid ofo_code required");
    }
    
    // Determine table based on trade
    $table = 'arpl_appendix_c'; // Default
    
    if ($ofo_code === '641201') {
        $table = 'arpl_appendix_c_bricklayer';
    } elseif ($ofo_code === '642601') {
        $table = 'arpl_appendix_c_plumber';
    }
    
    // Try the specific table
    $result = $conn->query("SHOW TABLES LIKE '$table'");
    if ($result && $result->num_rows > 0) {
        $stmt = $conn->prepare("SELECT * FROM $table LIMIT 1");
        if ($stmt) {
            $stmt->execute();
            $result = $stmt->get_result();
            if ($result->num_rows > 0) {
                $response['curriculum'] = $result->fetch_assoc();
                $response['status'] = 'success';
                $response['message'] = 'Curriculum data retrieved successfully';
            } else {
                $response['status'] = 'success';
                $response['message'] = 'No curriculum data found for this trade';
            }
            $stmt->close();
        }
    } else {
        throw new Exception("Curriculum table not found for OFO code: $ofo_code");
    }

} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in get_arpl_curriculum.php: " . $e->getMessage());
}

echo json_encode($response);
?>
