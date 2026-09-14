<?php
/**
 * ARPL Endpoint: Save Access Recommendation Data (Appendix I)
 * Saves assessor recommendations for learner access/qualification
 * Database: arplelectrician_access_recommendation, arplbricklayer_access_recommendation, arplplumber_access_recommendation
 * 
 * Schema: RecommendationID (auto), LearnerID, ACRID, Trade, OFOCode, Status, Remarks, CreatedAt (auto), UpdatedAt (auto)
 */

require_once 'connection.php';
header('Content-Type: application/json');

$response = [
    'status' => 'error',
    'message' => '',
    'recommendation_id' => null
];

try {
    $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : 0;
    $ofo_code = isset($_POST['ofo_code']) ? trim($_POST['ofo_code']) : '';
    
    if ($learnerID <= 0) {
        throw new Exception("Valid learnerID required");
    }
    
    // Determine table based on trade
    $table = 'arplelectrician_access_recommendation'; // Default
    $trade = 'Electrician';
    
    if ($ofo_code === '641201') {
        $table = 'arplbricklayer_access_recommendation';
        $trade = 'Bricklaying';
    } elseif ($ofo_code === '642601') {
        $table = 'arplplumber_access_recommendation';
        $trade = 'Plumbing';
    }
    
    // Ensure table exists
    $createTableSQL = "
        CREATE TABLE IF NOT EXISTS `$table` (
            RecommendationID INT AUTO_INCREMENT PRIMARY KEY,
            LearnerID INT NOT NULL,
            ACRID TINYINT UNSIGNED DEFAULT 1,
            Trade VARCHAR(100) NOT NULL,
            OFOCode VARCHAR(20),
            Status VARCHAR(50),
            Remarks TEXT,
            CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_learner (LearnerID),
            INDEX idx_acrid (ACRID)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ";
    
    if (!$conn->query($createTableSQL)) {
        throw new Exception("Failed to ensure table exists: " . $conn->error);
    }
    
    // Get ACRID (multiple recommendations per learner supported)
    $acrid = isset($_POST['ACRID']) ? intval($_POST['ACRID']) : 1;
    $status = isset($_POST['Status']) ? trim($_POST['Status']) : '';
    $remarks = isset($_POST['Remarks']) ? trim($_POST['Remarks']) : '';
    
    // Check if this exact recommendation exists
    $stmt = $conn->prepare("SELECT RecommendationID FROM $table WHERE LearnerID = ? AND ACRID = ? LIMIT 1");
    $stmt->bind_param("ii", $learnerID, $acrid);
    $stmt->execute();
    $result = $stmt->get_result();
    $exists = $result->num_rows > 0;
    if ($exists) {
        $row = $result->fetch_assoc();
        $response['recommendation_id'] = $row['RecommendationID'];
    }
    $stmt->close();
    
    if ($exists) {
        // UPDATE existing record
        $sql = "UPDATE $table SET Status = ?, Remarks = ?, OFOCode = ?, Trade = ?, UpdatedAt = NOW() 
                WHERE LearnerID = ? AND ACRID = ?";
        $stmt = $conn->prepare($sql);
        
        if ($stmt) {
            $stmt->bind_param("sssii", $status, $remarks, $ofo_code, $trade, $learnerID, $acrid);
            $stmt->execute();
            $stmt->close();
            $response['status'] = 'success';
            $response['message'] = 'Access recommendation updated successfully';
        } else {
            throw new Exception("Failed to update recommendation: " . $conn->error);
        }
    } else {
        // INSERT new record
        $sql = "INSERT INTO $table (LearnerID, ACRID, Trade, OFOCode, Status, Remarks, CreatedAt) 
                VALUES (?, ?, ?, ?, ?, ?, NOW())";
        $stmt = $conn->prepare($sql);
        
        if ($stmt) {
            $stmt->bind_param("iissss", $learnerID, $acrid, $trade, $ofo_code, $status, $remarks);
            $stmt->execute();
            $response['recommendation_id'] = $conn->insert_id;
            $stmt->close();
            $response['status'] = 'success';
            $response['message'] = 'Access recommendation saved successfully';
        } else {
            throw new Exception("Failed to save recommendation: " . $conn->error);
        }
    }

} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in save_arpl_access_recommendation.php: " . $e->getMessage());
}

echo json_encode($response);
?>
