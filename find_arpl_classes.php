<?php
include_once 'mobile/connection.php';

echo "=== SEARCHING FOR ARPL CLASSES ===\n\n";

$stmt = $conn->prepare("
    SELECT 
        c.classID,
        c.className,
        c.siteID,
        s.siteName,
        s.Project_pathway,
        CASE 
            WHEN s.Project_pathway LIKE '%ARPL%' THEN 'Has ARPL'
            WHEN s.Project_pathway LIKE '%Electrician%' THEN 'Has Electrician (ARPL)'
            WHEN s.Project_pathway LIKE '%Bricklayer%' THEN 'Has Bricklayer (ARPL)'
            ELSE 'Not ARPL'
        END as pathway_type
    FROM class c
    JOIN sites s ON c.siteID = s.siteID
    WHERE s.Project_pathway LIKE '%ARPL%'
       OR s.Project_pathway LIKE '%Electrician%'
       OR s.Project_pathway LIKE '%Bricklayer%'
    ORDER BY c.classID
");

$stmt->execute();
$result = $stmt->get_result();
$classes = $result->fetch_all(MYSQLI_ASSOC);
$stmt->close();

if (count($classes) > 0) {
    echo "Found " . count($classes) . " ARPL class(es):\n\n";
    
    foreach ($classes as $c) {
        echo "ClassID: " . $c['classID'] . "\n";
        echo "  Class Name: " . $c['className'] . "\n";
        echo "  Site ID: " . $c['siteID'] . " (" . $c['siteName'] . ")\n";
        echo "  Pathway Type: " . $c['pathway_type'] . "\n";
        echo "  Pathway: " . substr($c['Project_pathway'], 0, 80) . "...\n";
        echo "\n";
    }
} else {
    echo "No ARPL classes found!\n";
}

echo "\n=== CURRENT FACILITATOR 6 ASSIGNMENT ===\n\n";

$stmt = $conn->prepare("
    SELECT 
        f.facilitator_id,
        f.firstName,
        f.lastName,
        f.role,
        f.classID as assigned_classIDs,
        c.classID,
        c.className,
        c.siteID,
        s.siteName,
        s.Project_pathway
    FROM facilitator f
    LEFT JOIN class c ON FIND_IN_SET(c.classID, f.classID) > 0
    LEFT JOIN sites s ON c.siteID = s.siteID
    WHERE f.facilitator_id = 6
    ORDER BY c.classID
");

$stmt->execute();
$result = $stmt->get_result();
$assignments = $result->fetch_all(MYSQLI_ASSOC);
$stmt->close();

if (count($assignments) > 0) {
    $first = $assignments[0];
    echo "Facilitator: " . $first['firstName'] . " " . $first['lastName'] . "\n";
    echo "Role: " . $first['role'] . "\n";
    echo "ClassIDs: " . $first['assigned_classIDs'] . "\n";
    echo "\nAssigned Classes:\n";
    
    foreach ($assignments as $a) {
        if ($a['classID']) {
            echo "\n  ClassID: " . $a['classID'] . " (" . $a['className'] . ")\n";
            echo "  Site: " . $a['siteName'] . " (ID: " . $a['siteID'] . ")\n";
            echo "  Pathway: " . substr($a['Project_pathway'], 0, 60) . "...\n";
            
            $pathway_upper = strtoupper($a['Project_pathway']);
            if (strpos($pathway_upper, 'ARPL') !== false || strpos($pathway_upper, 'ELECTRICIAN') !== false) {
                echo "  ARPL Detection: YES ✓\n";
            } else {
                echo "  ARPL Detection: NO ✗\n";
            }
        }
    }
}

$conn->close();
?>
