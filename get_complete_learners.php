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
    $unitStandardIds = isset($_GET['unitStandardIds']) ? $_GET['unitStandardIds'] : null;
    
    if (!$classID) {
        throw new Exception('Missing classID parameter');
    }
    
    if (!$unitStandardIds) {
        throw new Exception('Missing unitStandardIds parameter');
    }
    
    // Parse unit standard IDs (comma-separated: "9962,9963,9964")
    $unitStandardArray = explode(',', $unitStandardIds);
    $totalUnitStandards = count($unitStandardArray);
    
    // For each unit standard, we need 3 items: LG, FORM, SUM
    $requiredItemsPerLearner = $totalUnitStandards * 3;
    
    // Get learners who have received ALL items for ALL unit standards
    // We check for sub_descriptions like "9962 - Learner Guide", "9962 - Formative", "9962 - Summative"
    $placeholders = implode(',', array_fill(0, $totalUnitStandards, '?'));
    
    $sql = "SELECT 
                representative_full_name,
                COUNT(DISTINCT sub_description) as items_received
            FROM material_forms 
            WHERE classID = ? 
            AND description = 'Learning Material'
            AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            AND (";
    
    // Build conditions for each unit standard (LG, FORM, SUM)
    $conditions = [];
    foreach ($unitStandardArray as $usId) {
        $conditions[] = "sub_description LIKE '" . $conn->real_escape_string($usId) . " - %'";
    }
    $sql .= implode(' OR ', $conditions);
    $sql .= ")
            GROUP BY representative_full_name
            HAVING items_received >= ?";
    
    $stmt = $conn->prepare($sql);
    
    // Bind classID and required items count
    $stmt->bind_param("ii", $classID, $requiredItemsPerLearner);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $completeLearners = [];
    while ($row = $result->fetch_assoc()) {
        $completeLearners[] = $row['representative_full_name'];
    }
    
    echo json_encode([
        'success' => true,
        'completeLearners' => $completeLearners,
        'count' => count($completeLearners),
        'unitStandards' => $unitStandardArray,
        'requiredItems' => $requiredItemsPerLearner,
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
