<?php
include_once 'mobile/connection.php';

echo "=== COMPARING FACILITATORS ===\n\n";

echo "LOCAL DATABASE:\n";
echo "===============\n\n";

// Check facilitator 118
echo "Facilitator 118:\n";
$stmt = $conn->prepare("
    SELECT 
        f.facilitator_id,
        f.firstName,
        f.lastName,
        f.role,
        f.classID,
        c.classID,
        c.className,
        c.siteID,
        s.siteName,
        s.Project_pathway,
        CASE 
            WHEN UPPER(s.Project_pathway) LIKE '%ARPL%' THEN 'YES'
            WHEN UPPER(s.Project_pathway) LIKE '%ELECTRICIAN%' THEN 'YES'
            ELSE 'NO'
        END as is_arpl
    FROM facilitator f
    LEFT JOIN class c ON FIND_IN_SET(c.classID, f.classID) > 0
    LEFT JOIN sites s ON c.siteID = s.siteID
    WHERE f.facilitator_id = 118
    ORDER BY c.classID
");
$stmt->execute();
$result = $stmt->get_result();
$rows_118 = $result->fetch_all(MYSQLI_ASSOC);
$stmt->close();

if (count($rows_118) > 0) {
    $first = $rows_118[0];
    echo "  Name: " . $first['firstName'] . " " . $first['lastName'] . "\n";
    echo "  Role: " . $first['role'] . "\n";
    echo "  ClassIDs: " . $first['classID'] . "\n";
    echo "  Classes:\n";
    foreach ($rows_118 as $row) {
        if ($row['classID']) {
            echo "    - ClassID " . $row['classID'] . " (" . $row['className'] . ")\n";
            echo "      Site: " . $row['siteName'] . " (ID: " . $row['siteID'] . ")\n";
            echo "      Pathway: " . substr($row['Project_pathway'], 0, 60) . "...\n";
            echo "      Is ARPL: " . $row['is_arpl'] . "\n";
        }
    }
} else {
    echo "  NOT FOUND\n";
}

echo "\n\nFacilitator 6:\n";
$stmt = $conn->prepare("
    SELECT 
        f.facilitator_id,
        f.firstName,
        f.lastName,
        f.role,
        f.classID,
        c.classID,
        c.className,
        c.siteID,
        s.siteName,
        s.Project_pathway,
        CASE 
            WHEN UPPER(s.Project_pathway) LIKE '%ARPL%' THEN 'YES'
            WHEN UPPER(s.Project_pathway) LIKE '%ELECTRICIAN%' THEN 'YES'
            ELSE 'NO'
        END as is_arpl
    FROM facilitator f
    LEFT JOIN class c ON FIND_IN_SET(c.classID, f.classID) > 0
    LEFT JOIN sites s ON c.siteID = s.siteID
    WHERE f.facilitator_id = 6
    ORDER BY c.classID
");
$stmt->execute();
$result = $stmt->get_result();
$rows_6 = $result->fetch_all(MYSQLI_ASSOC);
$stmt->close();

if (count($rows_6) > 0) {
    $first = $rows_6[0];
    echo "  Name: " . $first['firstName'] . " " . $first['lastName'] . "\n";
    echo "  Role: " . $first['role'] . "\n";
    echo "  ClassIDs: " . $first['classID'] . "\n";
    echo "  Classes:\n";
    foreach ($rows_6 as $row) {
        if ($row['classID']) {
            echo "    - ClassID " . $row['classID'] . " (" . $row['className'] . ")\n";
            echo "      Site: " . $row['siteName'] . " (ID: " . $row['siteID'] . ")\n";
            echo "      Pathway: " . substr($row['Project_pathway'], 0, 60) . "...\n";
            echo "      Is ARPL: " . $row['is_arpl'] . "\n";
        }
    }
} else {
    echo "  NOT FOUND\n";
}

echo "\n\n=== KEY FINDING ===\n";
echo "LOCAL: Facilitator 118 has classID 797\n";
echo "ONLINE: Facilitator 6 has classID 797\n";
echo "\nBoth have the same classID 797, which suggests:\n";
echo "- ClassID 797 is an ARPL class\n";
echo "- Either facilitator 118 should be 6, or\n";
echo "- Different facilitators are assigned on LOCAL vs ONLINE\n";

$conn->close();
?>
