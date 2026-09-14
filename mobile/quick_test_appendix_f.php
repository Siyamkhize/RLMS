<?php
/**
 * QUICK TEST - Appendix F Endpoint
 * Simple check to verify everything is working
 */

header('Content-Type: application/json');

// Test 1: Check if connection.php exists
if (!file_exists('connection.php')) {
    die(json_encode([
        'status' => 'ERROR',
        'message' => 'connection.php not found in /mobile/ folder',
        'fix' => 'Check file location'
    ]));
}

require_once 'connection.php';

// Test 2: Check database connection
if (!$conn || $conn->connect_error) {
    die(json_encode([
        'status' => 'ERROR',
        'message' => 'Database connection failed',
        'error' => $conn->connect_error ?? 'No connection object'
    ]));
}

// Test 3: Check activities table
$table = 'arplappxe_bricklaying_activities';
$check = $conn->query("SHOW TABLES LIKE '$table'");

if ($check->num_rows === 0) {
    die(json_encode([
        'status' => 'ERROR',
        'message' => "Table '$table' does not exist",
        'fix' => 'Create the activities table first'
    ]));
}

// Test 4: Count activities
$result = $conn->query("SELECT COUNT(*) as total FROM $table");
$count = $result->fetch_assoc();

if ($count['total'] == 0) {
    die(json_encode([
        'status' => 'WARNING',
        'message' => "Table '$table' exists but is EMPTY",
        'fix' => 'Populate the activities table with data'
    ]));
}

// Test 5: Get sample data
$sample = $conn->query("
    SELECT 
        activity_id,
        activity_name,
        ofo_number
    FROM $table
    LIMIT 3
");

$activities = [];
while ($row = $sample->fetch_assoc()) {
    $activities[] = $row;
}

// Test 6: Check Appendix F tables
$tables = [
    'arpl_appendix_f_knowledge',
    'arpl_appendix_f_practical_tasks',
    'arpl_appendix_f_workplace_observations'
];

$tableStatus = [];
$missingTables = [];
foreach ($tables as $t) {
    $check = $conn->query("SHOW TABLES LIKE '$t'");
    $exists = $check->num_rows > 0;
    $tableStatus[$t] = $exists;
    if (!$exists) {
        $missingTables[] = $t;
    }
}

// Test 7: Simulate actual query
$learnerID = 11701;
$ofoNumber = '641201';

$query = "
    SELECT 
        a.activity_id,
        a.activity_name as task_observed
    FROM $table a
    WHERE a.ofo_number = ?
    LIMIT 5
";

$stmt = $conn->prepare($query);
$stmt->bind_param('s', $ofoNumber);
$stmt->execute();
$result = $stmt->get_result();

$observations = [];
while ($row = $result->fetch_assoc()) {
    $observations[] = [
        'activity_id' => $row['activity_id'],
        'task_observed' => $row['task_observed']
    ];
}

$stmt->close();
$conn->close();

// Final Result
$status = 'SUCCESS';
$message = 'All checks passed! Workplace observations should work.';

if (!empty($missingTables)) {
    $status = 'WARNING';
    $message = 'Activities table OK, but Appendix F tables missing. Run create_appendix_f_redesign_tables.sql';
}

echo json_encode([
    'status' => $status,
    'message' => $message,
    'checks' => [
        'connection' => 'OK',
        'activities_table' => 'EXISTS',
        'activities_count' => $count['total'],
        'sample_activities' => $activities,
        'appendix_f_tables' => $tableStatus,
        'missing_tables' => $missingTables,
        'test_query_results' => count($observations) . ' observations found',
        'sample_observations' => $observations
    ]
], JSON_PRETTY_PRINT);
?>
