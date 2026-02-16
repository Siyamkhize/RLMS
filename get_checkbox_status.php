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
    // Query material_forms table for existing submissions (both Learning Material and regular materials)
    $query = "SELECT 
                description, 
                sub_description, 
                SUM(quantity) as total_quantity, 
                GROUP_CONCAT(representative_full_name) as representatives,
                COUNT(*) as submission_count,
                MAX(created_at) as last_submission
              FROM material_forms 
              WHERE classID = ?
              GROUP BY description, sub_description
              ORDER BY description, sub_description";

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
        $desc = $submission['description'];
        $subDesc = $submission['sub_description'];
        $totalQty = intval($submission['total_quantity']);
        $repNames = $submission['representatives'];

        if ($desc === 'Learning Material') {
            // Handle Unit Standards and Learner Guides
            // Extract unit standard ID from sub_description
            preg_match('/(\d+)/', $subDesc, $matches);
            $unitStandardId = $matches[0] ?? 'unknown';

            // Determine if this is a learner guide
            $isLearnerGuide = (stripos($subDesc, 'learner guide') !== false);

            // Create checkbox key (same format as Flutter app expects)
            $checkboxKey = $isLearnerGuide ? $unitStandardId . '_LG' : $unitStandardId;

            // Set checkbox status (checked if quantity > 0)
            $checkboxStatus[$checkboxKey] = ($totalQty > 0);
            $quantities[$checkboxKey] = $totalQty;
            $representatives[$checkboxKey] = $repNames;
        } else {
            // Handle regular materials (PPE, ToolKit, Consumables, etc.)
            $materialKey = $desc; // Use description as key for regular materials
            $regularMaterials[$materialKey] = [
                'quantity' => $totalQty,
                'representative' => $repNames,
                'hasSubmissions' => ($totalQty > 0)
            ];
        }
    }

    // Response format matching Flutter app expectations
    $response = [
        'success' => true,
        'classID' => $classID,
        'checkboxStatus' => $checkboxStatus,
        'quantities' => $quantities,
        'representatives' => $representatives,
        'regularMaterials' => $regularMaterials, // Add regular materials data
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