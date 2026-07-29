<?php
require_once 'web/connection.php';

echo "=== Finding Learner Documents ===\n\n";

$learnerID = 16389;

// Check with learner_id column
$sql = "SELECT * FROM learner_document WHERE learner_id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param('s', $learnerID);
$stmt->execute();
$result = $stmt->get_result();

echo "Documents for learner_id = $learnerID:\n";
echo "Count: " . $result->num_rows . "\n\n";

while ($row = $result->fetch_assoc()) {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    echo "Document ID: " . $row['document_id'] . "\n";
    echo "Name: " . $row['documentName'] . "\n";
    echo "Type: " . $row['document_type'] . "\n";
    echo "File Path: " . $row['learner_document'] . "\n";
    echo "Status: " . $row['status'] . "\n";
    echo "Upload Date: " . $row['upload_date'] . "\n";
}
$stmt->close();

// Try string version of learnerID
$learnerID_str = (string)16389;
$sql = "SELECT * FROM learner_document WHERE learner_id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param('s', $learnerID_str);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    // Try with just the number
    echo "\nTrying different formats...\n";
    $sql = "SELECT * FROM learner_document LIMIT 5";
    $result = $conn->query($sql);
    if ($result->num_rows > 0) {
        echo "\nFirst 5 documents in database:\n";
        while ($row = $result->fetch_assoc()) {
            echo "  learner_id: " . $row['learner_id'] . " | documentName: " . $row['documentName'] . " | document_type: " . $row['document_type'] . "\n";
        }
    }
}

$conn->close();
?>
