<?php
header('Content-Type: application/json');
require_once('connection.php');

if (!isset($_GET['learner_id'])) {
    echo json_encode(['success' => false, 'message' => 'Missing learner_id']);
    exit;
}

$learner_id = intval($_GET['learner_id']);

// Get all 4 assessment items from appxh_acrelectrician
$query = "SELECT ACRID, AssessmentType FROM appxh_acrelectrician ORDER BY ACRID";
$result = mysqli_query($conn, $query);

if (!$result) {
    echo json_encode(['success' => false, 'message' => 'Database error: ' . mysqli_error($conn)]);
    exit;
}

$assessment_items = [];
while ($row = mysqli_fetch_assoc($result)) {
    $assessment_items[] = $row;
}

// Get existing recommendations for this learner
$query = "SELECT ACRID, Status, Remarks FROM arplelectrician_access_recommendation WHERE LearnerID = ?";
$stmt = mysqli_prepare($conn, $query);
mysqli_stmt_bind_param($stmt, 'i', $learner_id);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);

$existing_recommendations = [];
while ($row = mysqli_fetch_assoc($result)) {
    $existing_recommendations[$row['ACRID']] = [
        'Status' => $row['Status'],
        'Remarks' => $row['Remarks']
    ];
}

// Combine assessment items with existing recommendations
foreach ($assessment_items as &$item) {
    $acrid = $item['ACRID'];
    if (isset($existing_recommendations[$acrid])) {
        $item['Status'] = $existing_recommendations[$acrid]['Status'];
        $item['Remarks'] = $existing_recommendations[$acrid]['Remarks'];
    } else {
        $item['Status'] = null;
        $item['Remarks'] = null;
    }
}

echo json_encode([
    'success' => true,
    'learner_id' => $learner_id,
    'assessment_items' => $assessment_items
], JSON_PRETTY_PRINT);

mysqli_close($conn);
?>
