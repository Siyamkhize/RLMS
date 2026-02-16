<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

require_once 'connection.php';

try {
    // Get parameters
    $classID = isset($_GET['classID']) ? intval($_GET['classID']) : null;
    $materialType = isset($_GET['materialType']) ? $_GET['materialType'] : null;
    
    if (!$classID) {
        throw new Exception('Missing classID parameter');
    }
    
    if (!$materialType) {
        throw new Exception('Missing materialType parameter');
    }
    
    // Get list of learner IDs who have already received this material type
    // We check the material_forms table for records with matching description
    $sql = "SELECT DISTINCT representative_full_name 
            FROM material_forms 
            WHERE classID = ? 
            AND (description = ? OR sub_description = ?)
            AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("iss", $classID, $materialType, $materialType);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $issuedLearners = [];
    while ($row = $result->fetch_assoc()) {
        $issuedLearners[] = $row['representative_full_name'];
    }
    
    echo json_encode([
        'success' => true,
        'issuedLearners' => $issuedLearners,
        'count' => count($issuedLearners),
        'materialType' => $materialType,
        'classID' => $classID
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

if (isset($conn)) {
    $conn->close();
}
?>
