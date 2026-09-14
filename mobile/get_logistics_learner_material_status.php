<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');

require_once 'connection.php';

try {
    $classID = isset($_GET['classID']) ? intval($_GET['classID']) : 0;
    $learnerID = isset($_GET['learnerID']) ? mysqli_real_escape_string($conn, $_GET['learnerID']) : '';
    
    if (empty($classID) || empty($learnerID)) {
        echo json_encode(['success' => false, 'error' => 'Missing classID or learnerID']);
        exit;
    }
    
    // Get class name from classID
    $class_query = "SELECT className FROM class WHERE classID = ?";
    $class_stmt = $conn->prepare($class_query);
    $class_stmt->bind_param('i', $classID);
    $class_stmt->execute();
    $class_result = $class_stmt->get_result()->fetch_assoc();
    $className = $class_result ? $class_result['className'] : '';
    $class_stmt->close();
    
    // Get all materials issued to this learner from material_receipt_form table
    $query = "SELECT 
                id,
                description,
                sub_description,
                SUM(quantity) as total_quantity,
                representative_name as issued_by,
                MAX(date_received) as last_issued,
                practitioner_full_name as unit_standard_info
              FROM material_receipt_form
              WHERE student_id_number = ? AND class_name = ? AND received = 'Yes'
              GROUP BY description, sub_description
              ORDER BY date_received DESC";
    
    $stmt = $conn->prepare($query);
    if ($stmt === false) {
        throw new Exception('Query preparation failed: ' . $conn->error);
    }
    
    $stmt->bind_param('ss', $learnerID, $className);
    $stmt->execute();
    $result = $stmt->get_result();
    
    // Build both a raw rows array and a logistics-friendly
    // map for checkboxes/quantities used by the mobile app.
    $rows = [];
    $materialsMap = [];   // e.g. 13958_learner_guide => true
    $quantitiesMap = [];  // e.g. 13958_learner_guide => 2
    
    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
        
        $description = $row['description'];
        $subDescription = $row['sub_description'];
        $totalQuantity = isset($row['total_quantity']) ? intval($row['total_quantity']) : 0;
        
        // Derive a component key like 13958_learner_guide / 13958_formative / 13958_summative
        $componentKey = '';
        $unitStandardId = '';
        
        // Try to parse "13958 - Learner Guide" style sub_description
        if (preg_match('/^(\d+)\s*-\s*(.+)$/', $subDescription, $matches)) {
            $unitStandardId = $matches[1];
            $label = strtolower(trim($matches[2]));
            
            if (strpos($label, 'learner guide') !== false) {
                $componentKey = $unitStandardId . '_learner_guide';
            } elseif (strpos($label, 'formative') !== false) {
                $componentKey = $unitStandardId . '_formative';
            } elseif (strpos($label, 'summative') !== false) {
                $componentKey = $unitStandardId . '_summative';
            } else {
                // Fallback: plain unit standard
                $componentKey = $unitStandardId;
            }
        } else {
            // Fallback if sub_description not in expected format
            $componentKey = $subDescription !== '' ? $subDescription : $description;
        }
        
        if ($componentKey !== '') {
            $materialsMap[$componentKey] = true;
            $quantitiesMap[$componentKey] = $totalQuantity;
        }
    }
    
    $stmt->close();
    
    echo json_encode([
        'success' => true,
        'materials' => $materialsMap,
        'quantities' => $quantitiesMap,
        'rows' => $rows,
        'count' => count($rows),
        'source' => 'logistics',
        'className' => $className
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => 'Database error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
