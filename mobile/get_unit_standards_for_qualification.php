<?php
header('Content-Type: application/json');
require_once('connection.php');

if (!isset($_GET['qualification_id'])) {
    echo json_encode(['success' => false, 'message' => 'Missing qualification_id']);
    exit;
}

$qualification_id = intval($_GET['qualification_id']);

// Get unit standards for this qualification
$query = "SELECT 
    id,
    qualification_id,
    Module_Code,
    unit_standard_name,
    module_type,
    level,
    credits
FROM occupational_unit_standards 
WHERE qualification_id = ?
ORDER BY module_type, Module_Code";

$stmt = mysqli_prepare($conn, $query);
mysqli_stmt_bind_param($stmt, 'i', $qualification_id);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);

if (!$result) {
    echo json_encode(['success' => false, 'message' => 'Database error: ' . mysqli_error($conn)]);
    exit;
}

$unit_standards = [];
while ($row = mysqli_fetch_assoc($result)) {
    $unit_standards[] = $row;
}

echo json_encode([
    'success' => true,
    'qualification_id' => $qualification_id,
    'unit_standards' => $unit_standards,
    'total_count' => count($unit_standards)
], JSON_PRETTY_PRINT);

mysqli_close($conn);
?>
