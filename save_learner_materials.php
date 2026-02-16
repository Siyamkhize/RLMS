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

    // Get JSON input
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);

    if (!$data) {
        echo json_encode([
            'success' => false,
            'error' => 'Invalid JSON input'
        ]);
        exit();
    }

    $classID = $data['classID'] ?? null;
    $learnerID = $data['learnerID'] ?? null;
    $learnerName = $data['learnerName'] ?? null;
    $selections = $data['selections'] ?? [];
    $quantities = $data['quantities'] ?? [];
    $timestamp = $data['timestamp'] ?? date('Y-m-d H:i:s');

    if (!$classID || !$learnerID) {
        echo json_encode([
            'success' => false,
            'error' => 'Missing required fields'
        ]);
        exit();
    }

    // Start transaction
    $conn->beginTransaction();

    // Process each selection
    $insertedCount = 0;
    foreach ($selections as $key => $isSelected) {
        if (!$isSelected) {
            continue; // Skip unselected items
        }

        // Parse the key (format: "9962_LG", "9962_FORM", "9962_SUM")
        $parts = explode('_', $key);
        if (count($parts) < 2) {
            continue;
        }

        $unitStandardId = $parts[0];
        $subcategory = $parts[1]; // LG, FORM, or SUM
        
        // Map subcategory to full name
        $typeMap = [
            'LG' => 'Learner Guide',
            'FORM' => 'Formative',
            'SUM' => 'Summative'
        ];
        
        $typeName = $typeMap[$subcategory] ?? $subcategory;
        $subDescription = "{$unitStandardId} - {$typeName}";
        
        // Get quantity for this item
        $quantity = $quantities[$key] ?? 1;

        // Insert into material_forms table (matching acknoledge.php structure)
        $insertStmt = $conn->prepare("
            INSERT INTO material_forms (
                classID,
                facilitator_full_name,
                representative_full_name,
                qualification_name,
                facilitator_signature,
                representative_signature,
                description,
                sub_description,
                quantity,
                is_synced,
                created_at,
                updated_at
            ) VALUES (
                :classID,
                'System',
                :learnerName,
                'N/A',
                '',
                '',
                'Learning Material',
                :subDescription,
                :quantity,
                1,
                :timestamp,
                :timestamp
            )
        ");
        
        $insertStmt->execute([
            ':classID' => $classID,
            ':learnerName' => $learnerName,
            ':subDescription' => $subDescription,
            ':quantity' => $quantity,
            ':timestamp' => $timestamp
        ]);

        $insertedCount++;
    }

    // Commit transaction
    $conn->commit();

    echo json_encode([
        'success' => true,
        'message' => 'Materials saved successfully',
        'recordsProcessed' => $insertedCount
    ]);

} catch (PDOException $e) {
    // Rollback on error
    if ($conn->inTransaction()) {
        $conn->rollBack();
    }
    
    echo json_encode([
        'success' => false,
        'error' => 'Database error: ' . $e->getMessage()
    ]);
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => 'Error: ' . $e->getMessage()
    ]);
}
?>
