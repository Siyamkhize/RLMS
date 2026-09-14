<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Include database connection
require_once 'connection.php';

try {
    // Get classID from query parameters
    $classID = isset($_GET['classID']) ? $_GET['classID'] : null;

    if (!$classID) {
        throw new Exception('ClassID is required');
    }

    error_log("Getting learner checkbox status for classID: $classID");

    // Initialize response arrays
    $checkboxStatus = [];
    $quantities = [];
    $representatives = [];
    $regularMaterials = [];

    // Query to get all learner material submissions for this class
    $sql = "SELECT 
                learnerID,
                description,
                subDescription,
                SUM(quantity) as total_quantity,
                representativeFullName,
                COUNT(*) as submission_count
            FROM material_receipt_form 
            WHERE classID = ? 
            GROUP BY learnerID, description, subDescription, representativeFullName
            ORDER BY dateCreated DESC";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Database prepare failed: ' . $conn->error);
    }

    $stmt->bind_param('s', $classID);
    
    if (!$stmt->execute()) {
        throw new Exception('Database execution failed: ' . $stmt->error);
    }

    $result = $stmt->get_result();
    
    error_log("Found " . $result->num_rows . " learner material submission records");

    while ($row = $result->fetch_assoc()) {
        $learnerID = $row['learnerID'];
        $description = $row['description'];
        $subDescription = $row['subDescription'];
        $totalQuantity = intval($row['total_quantity']);
        $representative = $row['representativeFullName'];

        error_log("Processing: LearnerID=$learnerID, Desc=$description, SubDesc=$subDescription, Qty=$totalQuantity");

        // Handle Unit Standards and their sub-components
        if ($description === 'Learning Material') {
            // Check if this is a unit standard related submission
            if (strpos($subDescription, ' - ') !== false) {
                // This is a unit standard sub-component (e.g., "13958 - Learner Guide")
                $parts = explode(' - ', $subDescription, 2);
                $unitStandardId = trim($parts[0]);
                $componentType = trim($parts[1]);

                // Map component types to our ID format
                $componentKey = '';
                switch ($componentType) {
                    case 'Learner Guide':
                        $componentKey = $unitStandardId . '_LG';
                        break;
                    case 'Formative':
                        $componentKey = $unitStandardId . '_FORM';
                        break;
                    case 'Summative':
                        $componentKey = $unitStandardId . '_SUM';
                        break;
                    default:
                        // If it doesn't match known components, treat as unit standard itself
                        $componentKey = $unitStandardId;
                        break;
                }

                // Set checkbox status and quantities for this component
                $checkboxStatus[$componentKey] = true;
                $quantities[$componentKey] = $totalQuantity;
                $representatives[$componentKey] = $representative;

                error_log("Unit Standard Component: $componentKey = $totalQuantity units by $representative");

            } else {
                // Check if this is a direct unit standard (just a number)
                if (is_numeric(trim($subDescription))) {
                    $unitStandardId = trim($subDescription);
                    $checkboxStatus[$unitStandardId] = true;
                    $quantities[$unitStandardId] = $totalQuantity;
                    $representatives[$unitStandardId] = $representative;

                    error_log("Direct Unit Standard: $unitStandardId = $totalQuantity units by $representative");
                } else {
                    // This is a regular learning material (e.g., "Stationary (Files, Pens, Exam Pad)")
                    $regularMaterials[$subDescription] = [
                        'quantity' => $totalQuantity,
                        'representative' => $representative
                    ];

                    error_log("Regular Learning Material: $subDescription = $totalQuantity units by $representative");
                }
            }
        } else {
            // This is a regular material (ToolKit, PPE, Consumables, etc.)
            $regularMaterials[$description] = [
                'quantity' => $totalQuantity,
                'representative' => $representative
            ];

            error_log("Regular Material: $description = $totalQuantity units by $representative");
        }
    }

    // Debug output
    error_log("Final checkbox status: " . print_r($checkboxStatus, true));
    error_log("Final quantities: " . print_r($quantities, true));
    error_log("Final representatives: " . print_r($representatives, true));
    error_log("Final regular materials: " . print_r($regularMaterials, true));

    // Return the response
    echo json_encode([
        'success' => true,
        'classID' => $classID,
        'checkboxStatus' => $checkboxStatus,
        'quantities' => $quantities,
        'representatives' => $representatives,
        'regularMaterials' => $regularMaterials,
        'totalRecords' => $result->num_rows
    ]);

} catch (Exception $e) {
    error_log('Get Learner Checkbox Status Error: ' . $e->getMessage());
    
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'error_details' => [
            'file' => __FILE__,
            'line' => $e->getLine()
        ]
    ]);
} finally {
    if (isset($stmt)) {
        $stmt->close();
    }
    if (isset($conn)) {
        $conn->close();
    }
}
?>