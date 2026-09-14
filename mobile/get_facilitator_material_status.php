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

// Enhanced logging for debugging
$debug_log = 'facilitator_material_debug.log';
$timestamp = date('Y-m-d H:i:s');

try {
    // Get classID from query parameter
    $classID = isset($_GET['classID']) ? intval($_GET['classID']) : 0;
    
    file_put_contents($debug_log, "[$timestamp] GET STATUS REQUEST - classID: $classID\n", FILE_APPEND | LOCK_EX);
    
    if ($classID <= 0) {
        throw new Exception('Invalid or missing classID parameter');
    }
    
    // Query to get all material issues for this class from material_forms table
    // Group by both description and sub_description to handle different material types
    $sql = "SELECT 
                description,
                sub_description,
                SUM(quantity) as total_quantity,
                GROUP_CONCAT(DISTINCT representative_full_name SEPARATOR ', ') as representatives,
                MAX(created_at) as last_issued
            FROM material_forms
            WHERE classID = ?
            GROUP BY description, sub_description
            ORDER BY created_at DESC";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $classID);
    $stmt->execute();
    $result = $stmt->get_result();
    
    file_put_contents($debug_log, "[$timestamp] Query returned " . $result->num_rows . " records\n", FILE_APPEND | LOCK_EX);
    
    // Build response arrays
    $checkboxStatus = [];
    $quantities = [];
    $representatives = [];
    $regularMaterials = [];
    
    while ($row = $result->fetch_assoc()) {
        $description = $row['description'];
        $subDesc = $row['sub_description'];
        $quantity = intval($row['total_quantity']);
        
        file_put_contents($debug_log, "[$timestamp]   - description: $description, sub_description: $subDesc, quantity: $quantity\n", FILE_APPEND | LOCK_EX);
        
        // Check if it's a unit standard (format: "9964 - Apply health and safety")
        if (strpos($subDesc, ' - ') !== false) {
            // It's a unit standard
            $parts = explode(' - ', $subDesc, 2);
            $usId = trim($parts[0]);
            
            // Check if it's a Learner Guide
            if (strpos($description, 'Learner Guide') !== false || strpos($subDesc, 'Learner Guide') !== false) {
                $lgId = $usId . '_LG';
                $checkboxStatus[$lgId] = true;
                $quantities[$lgId] = $quantity;
                $representatives[$lgId] = $row['representatives'];
                file_put_contents($debug_log, "[$timestamp]     -> Mapped to Learner Guide: $lgId\n", FILE_APPEND | LOCK_EX);
            } else {
                // Regular unit standard
                $checkboxStatus[$usId] = true;
                $quantities[$usId] = $quantity;
                $representatives[$usId] = $row['representatives'];
                file_put_contents($debug_log, "[$timestamp]     -> Mapped to Unit Standard: $usId\n", FILE_APPEND | LOCK_EX);
            }
        } else {
            // It's a regular material (ToolKit, PPE, etc.)
            // Use description as the key for regular materials
            $materialKey = !empty($description) ? $description : $subDesc;
            $regularMaterials[$materialKey] = [
                'description' => $description,
                'sub_description' => $subDesc,
                'quantity' => $quantity,
                'representatives' => $row['representatives'],
                'last_issued' => $row['last_issued']
            ];
            file_put_contents($debug_log, "[$timestamp]     -> Mapped to Regular Material: $materialKey\n", FILE_APPEND | LOCK_EX);
        }
    }
    
    $response = [
        'success' => true,
        'classID' => $classID,
        'checkboxStatus' => $checkboxStatus,
        'quantities' => $quantities,
        'representatives' => $representatives,
        'regularMaterials' => $regularMaterials,
        'total_records' => $result->num_rows
    ];
    
    file_put_contents($debug_log, "[$timestamp] Response: " . json_encode($response) . "\n", FILE_APPEND | LOCK_EX);
    
    echo json_encode($response);
    
} catch (Exception $e) {
    $error_msg = $e->getMessage();
    file_put_contents($debug_log, "[$timestamp] ERROR: $error_msg\n", FILE_APPEND | LOCK_EX);
    
    echo json_encode([
        'success' => false,
        'error' => $error_msg
    ]);
}

// Close connection
if (isset($conn)) {
    $conn->close();
}
?>
