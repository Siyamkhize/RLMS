<?php
header('Content-Type: application/json');
include_once 'connection.php';

$facilitator_id = $_GET['facilitator_id'] ?? 6;

// Step 1: Check facilitator
echo json_encode([
    'step' => '1_check_facilitator',
    'facilitator_id' => $facilitator_id
], JSON_PRETTY_PRINT);
echo "\n\n";

$stmt = $conn->prepare("SELECT facilitator_id, firstName, lastName, role, classID FROM facilitator WHERE facilitator_id = ?");
$stmt->bind_param("i", $facilitator_id);
$stmt->execute();
$result = $stmt->get_result();
$facilitator = $result->fetch_assoc();

echo json_encode([
    'step' => '2_facilitator_data',
    'data' => $facilitator
], JSON_PRETTY_PRINT);
echo "\n\n";

if ($facilitator) {
    // Step 2: Get classes
    $facilitator_id_str = $facilitator['facilitator_id'];
    $query = "
        SELECT 
            s.project_id, 
            s.Project_pathway,
            c.classID,
            c.className,
            c.siteID,
            c.numberOfLearners
        FROM class c
        JOIN sites s ON s.siteID = c.siteID
        JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
        WHERE f.facilitator_id = ?
        ORDER BY c.className
    ";

    $stmt = $conn->prepare($query);
    $stmt->bind_param("i", $facilitator_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $classes = [];
    while ($row = $result->fetch_assoc()) {
        $classes[] = $row;
    }

    echo json_encode([
        'step' => '3_classes_returned',
        'total_classes' => count($classes),
        'first_class_pathway_raw' => $classes[0]['Project_pathway'] ?? 'NULL',
        'first_class_pathway_uppercase' => strtoupper($classes[0]['Project_pathway'] ?? ''),
        'detection_arpl' => strpos(strtoupper($classes[0]['Project_pathway'] ?? ''), 'ARPL') !== false,
        'detection_bricklayer' => strpos(strtoupper($classes[0]['Project_pathway'] ?? ''), 'BRICKLAYER') !== false
    ], JSON_PRETTY_PRINT);
    echo "\n\n";

    // Step 3: Show all classes
    echo json_encode([
        'step' => '4_all_classes',
        'classes' => $classes
    ], JSON_PRETTY_PRINT);
}

$stmt->close();
$conn->close();
?>
