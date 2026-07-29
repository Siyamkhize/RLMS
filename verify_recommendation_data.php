<?php
require_once __DIR__ . '/connection.php';

echo "=== ACTUAL RECOMMENDATION DATA IN DATABASE ===\n\n";

$learnerID = 20286;
echo "Checking for Learner $learnerID (Electrician):\n\n";

$result = $conn->query("SELECT * FROM arplelectrician_access_recommendation WHERE LearnerID = $learnerID");
if ($row = $result->fetch_assoc()) {
    echo "✓ RECOMMENDATION FOUND:\n";
    echo "  RecommendationID: {$row['RecommendationID']}\n";
    echo "  LearnerID: {$row['LearnerID']}\n";
    echo "  Trade: {$row['Trade']}\n";
    echo "  OFOCode: {$row['OFOCode']}\n";
    echo "  Status: {$row['Status']}\n";
    echo "  Remarks: {$row['Remarks']}\n";
    echo "  CreatedAt: {$row['CreatedAt']}\n";
    echo "  UpdatedAt: {$row['UpdatedAt']}\n";
} else {
    echo "✗ No recommendation found\n";
}

echo "\n--- All Electrician Recommendations ---\n";
$result = $conn->query("SELECT LearnerID, Status, Trade FROM arplelectrician_access_recommendation LIMIT 10");
$count = 0;
while ($row = $result->fetch_assoc()) {
    echo "  Learner {$row['LearnerID']}: {$row['Status']} ({$row['Trade']})\n";
    $count++;
}
echo "Total: $count records\n";

$conn->close();
?>
