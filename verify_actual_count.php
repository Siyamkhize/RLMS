<?php
/**
 * Verify actual assignment count in database
 */

$serverUrl = "https://rlms.rlms.co.za/mobile";
$moderatorId = 77;

echo "=== Verifying Actual Assignment Count ===\n\n";
echo "Moderator ID: $moderatorId\n\n";

// Create a simple endpoint call to count assignments
$testScript = <<<'PHP'
<?php
include('connection.php');
header('Content-Type: application/json');

$moderatorId = $_GET['moderator_id'] ?? '77';

// Direct count query
$sql = "SELECT COUNT(*) as total FROM moderator_assignments WHERE moderator_id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $moderatorId);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();
$total = $row['total'];
$stmt->close();

// Get sample records
$sql = "SELECT ma.*, l.Name, l.Surname, l.classID 
        FROM moderator_assignments ma
        LEFT JOIN learnerdetails l ON ma.learner_id = l.LearnerID
        WHERE ma.moderator_id = ?
        LIMIT 10";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $moderatorId);
$stmt->execute();
$result = $stmt->get_result();

$samples = [];
while ($row = $result->fetch_assoc()) {
    $samples[] = $row;
}
$stmt->close();

// Get class breakdown
$sql = "SELECT ma.class_id, COUNT(*) as count
        FROM moderator_assignments ma
        WHERE ma.moderator_id = ?
        GROUP BY ma.class_id
        ORDER BY count DESC";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $moderatorId);
$stmt->execute();
$result = $stmt->get_result();

$classCounts = [];
while ($row = $result->fetch_assoc()) {
    $classCounts[] = $row;
}
$stmt->close();

echo json_encode([
    'status' => 'success',
    'data' => [
        'total_count' => $total,
        'sample_records' => $samples,
        'class_breakdown' => $classCounts
    ]
]);
?>
PHP;

// Save test script temporarily
file_put_contents('temp_count_check.php', $testScript);

echo "Calling direct count query...\n";

$ch = curl_init("$serverUrl/temp_count_check.php?moderator_id=$moderatorId");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

if ($curlError) {
    echo "✗ CURL Error: $curlError\n";
    exit(1);
}

echo "HTTP Status: $httpCode\n\n";

$data = json_decode($response, true);

if ($data && $data['status'] === 'success') {
    $result = $data['data'];
    
    echo "✓ ACTUAL COUNT: " . $result['total_count'] . " assignments\n\n";
    
    if ($result['total_count'] == 373) {
        echo "✓ Confirmed: 373 assignments exist in database\n";
        echo "Target: 402\n";
        echo "Need to add: " . (402 - 373) . " more learners\n\n";
    }
    
    if (!empty($result['sample_records'])) {
        echo "Sample assignments (first 10):\n";
        foreach ($result['sample_records'] as $i => $record) {
            echo ($i + 1) . ". " . $record['Name'] . " " . $record['Surname'] . 
                 " (Class: " . ($record['class_id'] ?? $record['classID'] ?? 'N/A') . ")\n";
        }
        echo "\n";
    }
    
    if (!empty($result['class_breakdown'])) {
        echo "Class breakdown (top 10):\n";
        $shown = 0;
        foreach ($result['class_breakdown'] as $class) {
            if ($shown >= 10) break;
            echo "- Class " . ($class['class_id'] ?? 'NULL') . ": " . $class['count'] . " learners\n";
            $shown++;
        }
        echo "\n";
    }
    
} else {
    echo "✗ Failed to get count\n";
    echo "Response: " . json_encode($data, JSON_PRETTY_PRINT) . "\n";
}

// Clean up
@unlink('temp_count_check.php');

?>
