<?php
include 'connection.php';
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Get classID from GET or POST
$classID = null;
if (isset($_GET['classID'])) {
    $classID = $_GET['classID'];
} elseif (isset($_POST['classID'])) {
    $classID = $_POST['classID'];
}

if (!$classID) {
    echo json_encode([
        'success' => false,
        'error' => 'Invalid or missing classID parameter'
    ]);
    exit;
}

if (!$conn) {
    echo json_encode([
        'success' => false,
        'error' => 'Database connection failed'
    ]);
    exit;
}

try {
    // Get the facilitator ID from the facilitator table using classID
    $facilitatorQuery = "SELECT facilitator_id FROM facilitator WHERE classID = ?";
    $stmt = $conn->prepare($facilitatorQuery);
    $stmt->bind_param("s", $classID);
    $stmt->execute();
    $facilitatorResult = $stmt->get_result();
    
    if ($facilitatorResult->num_rows === 0) {
        echo json_encode([
            'success' => false,
            'error' => 'No facilitator found for this class',
            'classID' => $classID
        ]);
        exit;
    }
    
    $facilitatorData = $facilitatorResult->fetch_assoc();
    $facilitatorID = $facilitatorData['facilitator_id'];

    // Query facilitator_material_issues table for existing submissions
    $query = "SELECT 
                material_type, 
                SUM(quantity) as total_quantity, 
                GROUP_CONCAT(logistics_name) as logistics_officers,
                COUNT(*) as submission_count,
                MAX(created_at) as last_submission,
                MAX(issue_date) as last_issue_date
              FROM facilitator_material_issues 
              WHERE facilitator_id = ? AND class_id = ?
              GROUP BY material_type
              ORDER BY material_type";

    $stmt = $conn->prepare($query);
    $stmt->bind_param("ss", $facilitatorID, $classID);
    $stmt->execute();
    $result = $stmt->get_result();
    $submissions = $result->fetch_all(MYSQLI_ASSOC);

    // Process submissions into material status format
    $checkboxStatus = [];
    $quantities = [];
    $representatives = [];
    $regularMaterials = [];

    foreach ($submissions as $submission) {
        $materialType = $submission['material_type'];
        $totalQty = intval($submission['total_quantity']);
        $officers = $submission['logistics_officers'];

        // Set checkbox status (checked if quantity > 0)
        $checkboxStatus[$materialType] = ($totalQty > 0);
        $quantities[$materialType] = $totalQty;
        $representatives[$materialType] = $officers;
        
        // Also add to regular materials format
        $regularMaterials[$materialType] = [
            'quantity' => $totalQty,
            'representative' => $officers
        ];
    }

    // Response format matching the expected structure from material_copy.dart
    $response = [
        'success' => true,
        'classID' => $classID,
        'facilitatorID' => $facilitatorID,
        'checkboxStatus' => $checkboxStatus,
        'quantities' => $quantities,
        'representatives' => $representatives,
        'regularMaterials' => $regularMaterials,
        'totalSubmissions' => count($submissions),
        'debug' => [
            'timestamp' => date('Y-m-d H:i:s'),
            'rawSubmissions' => $submissions
        ]
    ];

    echo json_encode($response);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => 'Database query failed: ' . $e->getMessage(),
        'classID' => $classID
    ]);
}

$conn->close();
?>