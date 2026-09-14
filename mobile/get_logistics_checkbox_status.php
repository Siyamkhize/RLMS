<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

require_once 'connection.php';

try {
    $classID = isset($_GET['classID']) ? $_GET['classID'] : null;
    $learnerParam = isset($_GET['learnerID']) ? $_GET['learnerID'] : null;
    
    if (!$classID) {
        throw new Exception('ClassID is required');
    }
    
    error_log("Getting logistics checkbox status for classID: $classID, learnerID: " . ($learnerParam ?? 'ALL'));
    
    $checkboxStatus = [];
    $quantities = [];
    
    // Resolve learner identifiers (STRICTLY use internal LearnerID)
    $internal_learner_id_str = '';
    $id_number_str = '';
    
    if ($learnerParam !== null && $learnerParam !== '') {
        // Look up both identifiers to ensure we find all existing records during transition
        $lookup_sql = "SELECT LearnerID, IDNumber FROM learnerdetails WHERE IDNumber = ? OR CAST(LearnerID AS CHAR) = ? LIMIT 1";
        $lookup_stmt = $conn->prepare($lookup_sql);
        if ($lookup_stmt) {
            $lookup_stmt->bind_param('ss', $learnerParam, $learnerParam);
            $lookup_stmt->execute();
            $lookup_result = $lookup_stmt->get_result()->fetch_assoc();
            $lookup_stmt->close();
            
            if ($lookup_result) {
                $internal_learner_id_str = strval($lookup_result['LearnerID']);
                $id_number_str = strval($lookup_result['IDNumber']);
            }
        }
    }
    
    // Query learner_issued_unit_standards table (same as facilitator)
    if ($learnerParam) {
        // Get materials for specific learner, matching either identifier for robustness
        $sql = "SELECT 
                    unit_standard_id,
                    material_type,
                    SUM(quantity) as total_quantity
                FROM learner_issued_unit_standards 
                WHERE classID = ? 
                  AND (CAST(learner_id AS CHAR) = ? OR CAST(learner_id AS CHAR) = ?) 
                GROUP BY unit_standard_id, material_type";
        
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception('Database prepare failed: ' . $conn->error);
        }
        
        $stmt->bind_param('iss', $classID, $internal_learner_id_str, $id_number_str);
    } else {
        // Get all materials for class (for filtering purposes)
        $sql = "SELECT 
                    unit_standard_id,
                    material_type,
                    SUM(quantity) as total_quantity
                FROM learner_issued_unit_standards 
                WHERE classID = ?
                GROUP BY unit_standard_id, material_type
                ORDER BY created_at DESC";
        
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception('Database prepare failed: ' . $conn->error);
        }
        
        $stmt->bind_param('i', $classID);
    }
    
    if (!$stmt->execute()) {
        throw new Exception('Database execution failed: ' . $stmt->error);
    }
    
    $result = $stmt->get_result();
    error_log("Found " . $result->num_rows . " material records");
    
    while ($row = $result->fetch_assoc()) {
        $unitStandardId = $row['unit_standard_id'];
        $materialType = isset($row['material_type']) ? $row['material_type'] : '';
        $totalQuantity = intval($row['total_quantity']);
        
        // Map material_type to checkbox key format used in logistics dialog:
        //  - 13958_LG, 13958_FORM, 13958_SUM, or plain 13958
        $componentKey = '';
        switch ($materialType) {
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
                $componentKey = $unitStandardId;
                break;
        }
        
        // Set checkbox status and quantities
        $checkboxStatus[$componentKey] = true;
        $quantities[$componentKey] = $totalQuantity;
        
        error_log("Material: $componentKey = $totalQuantity units");
    }
    
    error_log("Final checkbox status: " . print_r($checkboxStatus, true));
    error_log("Final quantities: " . print_r($quantities, true));
    
    echo json_encode([
        'success' => true,
        'classID' => $classID,
        'learnerID' => $learnerParam ?? ($internal_learner_id_str ?: $id_number_str),
        'checkboxStatus' => $checkboxStatus,
        'quantities' => $quantities,
        'totalRecords' => $result->num_rows
    ]);
    
} catch (Exception $e) {
    error_log('Get Logistics Checkbox Status Error: ' . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
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
