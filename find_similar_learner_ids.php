<?php
// Find learner IDs similar to 11453 and 11559
echo "<h2>Finding Similar Learner IDs</h2>";

include_once('connection.php');

// Look for learner IDs starting with 115
echo "<h3>Learner IDs starting with 115:</h3>";
$query115 = "SELECT LearnerID, FirstName, LastName FROM learnerdetails WHERE LearnerID LIKE '115%' ORDER BY LearnerID LIMIT 20";
$result115 = $conn->query($query115);

if ($result115 && $result115->num_rows > 0) {
    echo "<table border='1' style='border-collapse: collapse;'>";
    echo "<tr><th>Learner ID</th><th>Name</th></tr>";
    
    while ($row = $result115->fetch_assoc()) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($row['LearnerID']) . "</td>";
        echo "<td>" . htmlspecialchars($row['FirstName'] . ' ' . $row['LastName']) . "</td>";
        echo "</tr>";
    }
    echo "</table>";
} else {
    echo "<p>No learners found starting with 115</p>";
}

// Look for learner IDs starting with 114
echo "<h3>Learner IDs starting with 114:</h3>";
$query114 = "SELECT LearnerID, FirstName, LastName FROM learnerdetails WHERE LearnerID LIKE '114%' ORDER BY LearnerID LIMIT 20";
$result114 = $conn->query($query114);

if ($result114 && $result114->num_rows > 0) {
    echo "<table border='1' style='border-collapse: collapse;'>";
    echo "<tr><th>Learner ID</th><th>Name</th></tr>";
    
    while ($row = $result114->fetch_assoc()) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($row['LearnerID']) . "</td>";
        echo "<td>" . htmlspecialchars($row['FirstName'] . ' ' . $row['LastName']) . "</td>";
        echo "</tr>";
    }
    echo "</table>";
} else {
    echo "<p>No learners found starting with 114</p>";
}

// Show learners with the most marks (who would be good for testing)
echo "<h3>Learners with Most Marks (Good for Testing):</h3>";
$marksQuery = "
    SELECT m.learnerID, COUNT(*) as mark_count, ld.FirstName, ld.LastName
    FROM marks m 
    LEFT JOIN learnerdetails ld ON m.learnerID = ld.LearnerID 
    GROUP BY m.learnerID 
    ORDER BY mark_count DESC 
    LIMIT 10
";
$marksResult = $conn->query($marksQuery);

if ($marksResult && $marksResult->num_rows > 0) {
    echo "<table border='1' style='border-collapse: collapse;'>";
    echo "<tr><th>Learner ID</th><th>Name</th><th>Mark Count</th><th>Test URL</th></tr>";
    
    while ($row = $marksResult->fetch_assoc()) {
        $testUrl = "http://rlms.rlms.co.za/mobile/get_poe.php?learnerId=" . $row['learnerID'];
        echo "<tr>";
        echo "<td>" . htmlspecialchars($row['learnerID']) . "</td>";
        echo "<td>" . htmlspecialchars(($row['FirstName'] ?? 'Unknown') . ' ' . ($row['LastName'] ?? '')) . "</td>";
        echo "<td>" . htmlspecialchars($row['mark_count']) . "</td>";
        echo "<td><a href='$testUrl' target='_blank'>Test</a></td>";
        echo "</tr>";
    }
    echo "</table>";
} else {
    echo "<p>No marks data found</p>";
}

// Check the highest learner IDs to see the range
echo "<h3>Highest Learner IDs in System:</h3>";
$highQuery = "SELECT LearnerID, FirstName, LastName FROM learnerdetails ORDER BY LearnerID DESC LIMIT 10";
$highResult = $conn->query($highQuery);

if ($highResult && $highResult->num_rows > 0) {
    echo "<table border='1' style='border-collapse: collapse;'>";
    echo "<tr><th>Learner ID</th><th>Name</th></tr>";
    
    while ($row = $highResult->fetch_assoc()) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($row['LearnerID']) . "</td>";
        echo "<td>" . htmlspecialchars($row['FirstName'] . ' ' . $row['LastName']) . "</td>";
        echo "</tr>";
    }
    echo "</table>";
}

$conn->close();
?>