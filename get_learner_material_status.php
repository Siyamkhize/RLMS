<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Database connection
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "rlmsrlmsco_ezxcmacd_rlms";

try {
    $conn = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $classID = $_GET['classID'] ?? null;
    $learnerID = $_GET['learnerID'] ?? null;

    if (!$classID || !$learnerID) {
        echo json_encode([
            'success' => false,
            'error' => 'Missing classID or learnerID parameter'
        ]);
        exit();
    }

    // Query to get all material submissions for this specific learner from material_forms table
    // Using correct column names: representative_full_name, sub_description, created_at
    $stmt = $conn->prepare("
        SELECT 
            sub_description,
            quantity,
            representative_full_name
        FROM material_forms
        WHERE classID = :classID 
          AND representative_full_name = :learnerName
          AND description = 'Learning Material'
          AND DATE(created_at) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    ");
    
    // Get learner name from IDNumber
    $learnerStmt = $conn->prepare("SELECT Name, Surname FROM learnerdetails WHERE IDNumber = :learnerID");
    $learnerStmt->execute([':learnerID' => $learnerID]);
    $learnerData = $learnerStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$learnerData) {
        echo json_encode([
            'success' => false,
            'error' => 'Learner not found'
        ]);
        exit();
    }
    
    $learnerName = trim($learnerData['Name'] . ' ' . $learnerData['Surname']);
    
    $stmt->execute([
        ':classID' => $classID,
        ':learnerName' => $learnerName
    ]);

    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Build the response with checkbox status, quantities, and representatives
    $checkboxStatus = [];
    $quantities = [];
    $representatives = [];
    
    foreach ($results as $row) {
        $subDesc = $row['sub_description'];
        
        // Parse sub_description format: "9962 - Learner Guide", "9962 - Formative", "9962 - Summative"
        if (preg_match('/^(\d+)\s*-\s*(.+)$/', $subDesc, $matches)) {
            $usId = $matches[1];
            $type = trim($matches[2]);
            
            $key = '';
            if (stripos($type, 'Learner Guide') !== false) {
                $key = "{$usId}_LG";
            } elseif (stripos($type, 'Formative') !== false) {
                $key = "{$usId}_FORM";
            } elseif (stripos($type, 'Summative') !== false) {
                $key = "{$usId}_SUM";
            }
            
            if ($key) {
                $checkboxStatus[$key] = true;
                $quantities[$key] = (int)$row['quantity'];
                $representatives[$key] = $row['representative_full_name'];
            }
        }
    }

    echo json_encode([
        'success' => true,
        'checkboxStatus' => $checkboxStatus,
        'quantities' => $quantities,
        'representatives' => $representatives,
        'count' => count($results)
    ]);

} catch (PDOException $e) {
    echo json_encode([
        'success' => false,
        'error' => 'Database error: ' . $e->getMessage()
    ]);
}
?>
