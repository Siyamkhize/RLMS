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
    $classID = intval($_GET['classID']);
} elseif (isset($_POST['classID'])) {
    $classID = intval($_POST['classID']);
}

if (!$classID || $classID <= 0) {
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
    // Query material_forms table for existing submissions
    $query = "SELECT sub_description, SUM(quantity) as total_quantity, 
              GROUP_CONCAT(representative_full_name) as representatives,
              COUNT(*) as submission_count,
              MAX(created_at) as last_submission
              FROM material_forms 
              WHERE classID = ? AND description = 'Learning Material'
              GROUP BY sub_description
              ORDER BY sub_description";
    
    $stmt = $conn->prepare($query);
    $stmt->bind_param("i", $classID);
    $stmt->execute();
    $result = $stmt->get_result();
    $submissions = $result->fetch_all(MYSQLI_ASSOC);
    
    // Process submissions into checkbox status format
    $checkboxStatus = [];
    $quantities = [];
    $representatives = [];
    $regularMaterials = [];
    
    foreach ($submissions as $submission) {
        $subDesc = $submission['sub_description'];
        $totalQty = intval($submission['total_quantity']);
        $repNames = $submission['representatives'];
        
        // Check if this is a regular material (not unit standard related)
        if ($subDesc === null || 
            (stripos($subDesc, 'learner guide') === false && 
             stripos($subDesc, 'formative') === false && 
             stripos($subDesc, 'summative') === false &&
             !preg_match('/^\d+/', $subDesc))) {
            // This is a regular material like "Stationary (Files, Pens)"
            $regularMaterials[$subDesc] = [
                'quantity' => $totalQty,
                'representative' => $repNames
            ];
            continue;
        }
        
        // Extract unit standard ID from sub_description
        preg_match('/(\d+)/', $subDesc, $matches);
        $unitStandardId = $matches[0] ?? 'unknown';
        
        // Determine the type and create appropriate checkbox key
        $checkboxKey = $unitStandardId; // Default to unit standard itself
        
        if (stripos($subDesc, 'learner guide') !== false) {
            $checkboxKey = $unitStandardId . '_LG';
        } elseif (stripos($subDesc, 'formative') !== false) {
            $checkboxKey = $unitStandardId . '_FORM';
        } elseif (stripos($subDesc, 'summative') !== false) {
            $checkboxKey = $unitStandardId . '_SUM';
        }
        
        // Set checkbox status (checked if quantity > 0)
        $checkboxStatus[$checkboxKey] = ($totalQty > 0);
        $quantities[$checkboxKey] = $totalQty;
        $representatives[$checkboxKey] = $repNames;
    }
    
    // Response format matching Flutter app expectations
    $response = [
        'success' => true,
        'classID' => $classID,
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