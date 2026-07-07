<?php
// Find any existing marks in the database to understand the data structure
include_once('connection.php');

echo "<h2>Finding Existing Marks in Database</h2>";

// Check if marks table has any data at all
$query = "SELECT COUNT(*) as total_marks FROM marks";
$result = $conn->query($query);
$row = $result->fetch_assoc();
echo "<h3>Total marks in database: " . $row['total_marks'] . "</h3>";

if ($row['total_marks'] > 0) {
    // Get sample marks to see the structure
    echo "<h3>Sample marks (first 10 records):</h3>";
    $sampleQuery = "SELECT learnerID, exercise, type, marks_scored, marks FROM marks LIMIT 10";
    $sampleResult = $conn->query($sampleQuery);
    
    if ($sampleResult && $sampleResult->num_rows > 0) {
        echo "<table border='1' style='border-collapse: collapse;'>";
        echo "<tr><th>Learner ID</th><th>Exercise</th><th>Type</th><th>Marks Scored</th><th>Max Marks</th></tr>";
        
        while ($row = $sampleResult->fetch_assoc()) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($row['learnerID']) . "</td>";
        echo "<td>" . htmlspecialchars($row['exercise']) . "</td>";
        echo "<td><strong>" . htmlspecialchars($row['type']) . "</strong></td>";
        echo "<td>" . htmlspecialchars($row['marks_scored']) . "</td>";
        echo "<td>" . htmlspecialchars($row['marks']) . "</td>";
        echo "</tr>";
    }
    echo "</table>";
    
    // Look for any marks that might be related to "Test Summative Exercise"
    echo "<h3>Searching for 'Test Summative Exercise' marks:</h3>";
    $searchQuery = "SELECT * FROM marks WHERE exercise LIKE '%Test Summative Exercise%' OR exercise LIKE '%summative%'";
    $searchResult = $conn->query($searchQuery);
    
    if ($searchResult->num_rows > 0) {
        echo "<table border='1' style='border-collapse: collapse;'>";
        echo "<tr><th>Learner ID</th><th>Exercise</th><th>Type</th><th>Marks Scored</th><th>Max Marks</th></tr>";
        
        while ($row = $searchResult->fetch_assoc()) {
            echo "<tr>";
            echo "<td>" . htmlspecialchars($row['learnerID']) . "</td>";
            echo "<td>" . htmlspecialchars($row['exercise']) . "</td>";
            echo "<td><strong>" . htmlspecialchars($row['type']) . "</strong></td>";
            echo "<td>" . htmlspecialchars($row['marks_scored']) . "</td>";
            echo "<td>" . htmlspecialchars($row['marks']) . "</td>";
            echo "</tr>";
        }
        echo "</table>";
    } else {
        echo "<p>No sample marks found or query error</p>";
    }
    } else {
        echo "<p>No marks found containing 'Test Summative Exercise' or 'summative'</p>";
    }
    
    // Check what learner IDs have marks
    echo "<h3>Learner IDs with marks:</h3>";
    $learnerQuery = "SELECT learnerID, COUNT(*) as mark_count FROM marks GROUP BY learnerID ORDER BY mark_count DESC LIMIT 10";
    $learnerResult = $conn->query($learnerQuery);
    
    echo "<table border='1' style='border-collapse: collapse;'>";
    echo "<tr><th>Learner ID</th><th>Number of Marks</th></tr>";
    
    while ($row = $learnerResult->fetch_assoc()) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($row['learnerID']) . "</td>";
        echo "<td>" . htmlspecialchars($row['mark_count']) . "</td>";
        echo "</tr>";
    }
    echo "</table>";
}

$conn->close();
?>