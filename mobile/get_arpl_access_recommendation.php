<?php
/**
 * ARPL Endpoint: Get Access Recommendation Data (Appendix I)
 * Retrieves assessor recommendations for learner access/qualification
 * Database: arplelectrician_access_recommendation, arplbricklayer_access_recommendation, arplplumber_access_recommendation
 * 
 * Schema: RecommendationID, LearnerID, ACRID, Trade, OFOCode, Status, Remarks, CreatedAt, UpdatedAt
 */

require_once 'connection.php';
header('Content-Type: application/json');

$response = [
    'status' => 'error',
    'message' => '',
    'recommendation' => null,
    'recommendations' => []  // Array for multiple recommendations
];

try {
    $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0);
    $ofo_code = isset($_POST['ofo_code']) ? trim($_POST['ofo_code']) : (isset($_GET['ofo_code']) ? trim($_GET['ofo_code']) : '');
    
    if ($learnerID <= 0) {
        throw new Exception("Valid learnerID required");
    }
    
    // Determine table based on trade
    $table = 'arplelectrician_access_recommendation'; // Default
    
    if ($ofo_code === '641201') {
        $table = 'arplbricklayer_access_recommendation';
    } elseif ($ofo_code === '642601') {
        $table = 'arplplumber_access_recommendation';
    }
    
    // Check if table exists
    $result = $conn->query("SHOW TABLES LIKE '$table'");
    
    if ($result && $result->num_rows > 0) {
        // Get all recommendations for this learner (there may be multiple ACRID entries)
        $stmt = $conn->prepare("SELECT * FROM $table WHERE LearnerID = ? ORDER BY ACRID ASC");
        if ($stmt) {
            $stmt->bind_param("i", $learnerID);
            $stmt->execute();
            $result = $stmt->get_result();
            
            $recommendations = [];
            while ($row = $result->fetch_assoc()) {
                $recommendations[] = $row;
            }
            $stmt->close();
            
            if (!empty($recommendations)) {
                $response['recommendations'] = $recommendations;
                $response['recommendation'] = $recommendations[0];  // Return first as primary
                $response['status'] = 'success';
                $response['message'] = 'Access recommendation retrieved successfully (' . count($recommendations) . ' records)';
            } else {
                $response['status'] = 'success';
                $response['message'] = 'No access recommendation found for this learner';
                $response['recommendation'] = null;
                $response['recommendations'] = [];
            }
        }
    } else {
        $response['status'] = 'success';
        $response['message'] = 'Access recommendation table not found for this trade';
        $response['recommendation'] = null;
    }

} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in get_arpl_access_recommendation.php: " . $e->getMessage());
}

echo json_encode($response);
?>
