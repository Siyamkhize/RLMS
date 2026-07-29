<?php
require_once 'connection.php';

// Check the actual trade for both learners
$learners = [16389, 20286];

foreach ($learners as $learnerID) {
    $result = $conn->query("
        SELECT 
            ld.LearnerID,
            ld.FirstName,
            ld.LastName,
            c.classID,
            c.className,
            s.siteID,
            s.qualification_id,
            p.Project_name
        FROM learnerdetails ld
        LEFT JOIN class c ON ld.classID = c.classID
        LEFT JOIN sites s ON c.siteID = s.siteID
        LEFT JOIN project p ON s.project_id = p.project_id
        WHERE ld.LearnerID = $learnerID
        LIMIT 1
    ");
    
    if ($result && $row = $result->fetch_assoc()) {
        echo "Learner ID: {$row['LearnerID']} ({$row['FirstName']} {$row['LastName']})\n";
        echo "  Class: {$row['className']} (ID: {$row['classID']})\n";
        echo "  Qualification ID: {$row['qualification_id']}\n";
        echo "  Project: {$row['Project_name']}\n";
        echo "\n";
    }
}

// Also check what trade qualifications exist
echo "Available Qualifications:\n";
$result = $conn->query("SELECT DISTINCT qualification_id FROM sites WHERE qualification_id IS NOT NULL ORDER BY qualification_id");
while ($row = $result->fetch_assoc()) {
    echo "  - {$row['qualification_id']}\n";
}
?>
