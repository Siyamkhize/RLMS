<?php
/**
 * Create remedial records for learner 11515 on the server database
 * This will allow us to test the remedial functionality
 */

echo "=== CREATING REMEDIAL RECORDS FOR LEARNER 11515 ===\n\n";

// We'll use the local connection for now, but this logic can be adapted for server
include_once 'connection.php';

if (!$conn) {
    echo "❌ Database connection failed\n";
    exit;
}

$learnerID = 11515;

echo "1. CHECKING EXISTING REMEDIAL RECORDS\n";
echo "====================================\n";

$query = "SELECT COUNT(*) as count FROM poe WHERE learnerID = ? AND type LIKE '%Remedial%'";
$stmt = $conn->prepare($query);
$stmt->bind_param('i', $learnerID);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();
$existingCount = $row['count'];

echo "Existing remedial records for learner $learnerID: $existingCount\n\n";

if ($existingCount > 0) {
    echo "✅ Remedial records already exist. No need to create new ones.\n";
    echo "The issue might be with the server database not having these records.\n\n";
} else {
    echo "❌ No remedial records found. Creating test records...\n\n";
}

echo "2. CREATING TEST REMEDIAL RECORDS\n";
echo "=================================\n";

// Create sample remedial records based on the format we saw in local database
$remedialRecords = [
    [
        'exercise' => 'FormativeRemedial - 9964 - Apply health and safety to a work area',
        'type' => 'FormativeRemedial',
        'filePath' => 'TEST_REMEDIAL_' . time() . '_F1'
    ],
    [
        'exercise' => 'FormativeRemedial - 9986 - Apply quality principles on a construction site',
        'type' => 'FormativeRemedial', 
        'filePath' => 'TEST_REMEDIAL_' . time() . '_F2'
    ],
    [
        'exercise' => 'SummativeRemedial - 9964 - Apply health and safety to a work area',
        'type' => 'SummativeRemedial',
        'filePath' => 'TEST_REMEDIAL_' . time() . '_S1'
    ],
    [
        'exercise' => 'SummativeRemedial - 9986 - Apply quality principles on a construction site',
        'type' => 'SummativeRemedial',
        'filePath' => 'TEST_REMEDIAL_' . time() . '_S2'
    ]
];

$insertQuery = "INSERT INTO poe (learnerID, exercise, type, filePath, submitted_at, synced) VALUES (?, ?, ?, ?, NOW(), 1)";
$insertStmt = $conn->prepare($insertQuery);

$createdCount = 0;
foreach ($remedialRecords as $record) {
    $insertStmt->bind_param('isss', $learnerID, $record['exercise'], $record['type'], $record['filePath']);
    
    if ($insertStmt->execute()) {
        echo "✅ Created: {$record['type']} - {$record['exercise']}\n";
        $createdCount++;
    } else {
        echo "❌ Failed to create: {$record['type']} - " . $insertStmt->error . "\n";
    }
}

echo "\n📊 Created $createdCount new remedial records\n\n";

echo "3. VERIFYING CREATED RECORDS\n";
echo "============================\n";

$query = "SELECT poe_id, exercise, type, filePath FROM poe WHERE learnerID = ? AND type LIKE '%Remedial%' ORDER BY poe_id DESC LIMIT 10";
$stmt = $conn->prepare($query);
$stmt->bind_param('i', $learnerID);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo "✅ Remedial records for learner $learnerID:\n";
    while ($row = $result->fetch_assoc()) {
        echo "ID: {$row['poe_id']}, Type: {$row['type']}, Exercise: {$row['exercise']}\n";
    }
} else {
    echo "❌ No remedial records found after creation\n";
}

echo "\n4. TESTING LOCAL API RESPONSE\n";
echo "=============================\n";

// Test the local API to see if remedial data appears
$_SERVER['REQUEST_METHOD'] = 'GET';
$_GET['learnerId'] = (string)$learnerID;

ob_start();
try {
    include 'mobile/poe.php';
    $response = ob_get_clean();
    
    $populatedFormative = substr_count($response, '"formativeremedial":[{');
    $populatedSummative = substr_count($response, '"summativeremedial":[{');
    
    echo "Local API test results:\n";
    echo "- Populated formativeremedial arrays: $populatedFormative\n";
    echo "- Populated summativeremedial arrays: $populatedSummative\n";
    
    if ($populatedFormative > 0 || $populatedSummative > 0) {
        echo "🎉 SUCCESS: Local API now returns remedial data!\n";
        echo "Next step: Sync these records to the server database\n";
    } else {
        echo "❌ Local API still returns empty remedial arrays\n";
        echo "Check the JOIN logic or database structure\n";
    }
    
} catch (Exception $e) {
    ob_end_clean();
    echo "❌ Error testing local API: " . $e->getMessage() . "\n";
}

$conn->close();

echo "\n=== SUMMARY ===\n";
echo "Created test remedial records for learner $learnerID\n";
echo "These records should now appear in the assessor interface\n";
echo "To activate on server: sync these records to server database\n";
?>