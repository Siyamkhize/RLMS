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
    
    // Get list of learners who have already received this material type
    // Query from material_receipt_form table (for ToolKit, Consumables, PPE)
    $sql = "SELECT DISTINCT 
                l.Name,
                l.Surname,
                CONCAT(l.Name, ' ', l.Surname) as full_name
            FROM material_receipt_form mrf
            INNER JOIN learnerdetails l ON mrf.student_id_number = l.IDNumber
            WHERE l.classID = ? 
            AND mrf.description = ?";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("is", $classID, $materialType);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $issuedLearners = [];
    while ($row = $result->fetch_assoc()) {
        $issuedLearners[] = [
            'Name' => $row['Name'],
            'Surname' => $row['Surname'],
            'full_name' => $row['full_name']
        ];
    }
    
    echo json_encode($issuedLearners);
    
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
