<?php
// Find learners who have marks for unit standard 9964 assessments
echo "<h2>Finding Learners with Unit Standard 9964 Marks</h2>";

include_once('connection.php');

// Get all exercises for unit standard 9964
$exerciseQuery = "SELECT DISTINCT exercise, assessment_type FROM assessments WHERE unit_standard_id = 9964";
$exerciseResult = $conn->query($exerciseQuery);

$exercises = [];
while ($row = $exerciseResult->fetch_assoc()) {
    $exercises[] = $row['exercise'];
}

if (count($exercises) > 0) {
    echo "<h3>Unit Standard 9964 has " . count($exercises) . " exercises</h3>";
    
    // Find learners who have marks for any of these exercises
    $exerciseList = "'" . implode("','", array_map(function($ex) { return addslashes($ex); }, $exercises)) . "'";
    
    $marksQuery = "
        SELECT 
            m.learnerID, 
            ld.FirstName, 
            ld.LastName,
            m.exercise,
            m.type,
            m.marks_scored,
            m.marks,
            COUNT(*) as mark_count
        FROM marks m
        LEFT JOIN learnerdetails ld ON m.learnerID = ld.LearnerID
        WHERE m.exercise IN ($exerciseList)
        GROUP BY m.learnerID, m.exercise, m.type
        ORDER BY m.learnerID, m.exercise
        LIMIT 50
    ";
    
    $marksResult = $conn->query($marksQuery);
    
    if ($marksResult && $marksResult->num_rows > 0) {
        echo "<h3>Learners with Unit Standard 9964 marks:</h3>";
        echo "<table border='1' style='border-collapse: collapse;'>";
        echo "<tr><th>Learner ID</th><th>Name</th><th>Exercise</th><th>Type</th><th>Marks</th><th>Test URL</th></tr>";
        
        $currentLearner = null;
        while ($row = $marksResult->fetch_assoc()) {
            $testUrl = "http://rlms.rlms.co.za/mobile/get_poe.php?learnerId=" . $row['learnerID'];
            
            echo "<tr>";
            echo "<td>" . htmlspecialchars($row['learnerID']) . "</td>";
            echo "<td>" . htmlspecialchars(($row['FirstName'] ?? 'Unknown') . ' ' . ($row['LastName'] ?? '')) . "</td>";
            echo "<td>" . htmlspecialchars($row['exercise']) . "</td>";
            echo "<td><strong>" . htmlspecialchars($row['type']) . "</strong></td>";
            echo "<td>" . htmlspecialchars($row['marks_scored']) . "/" . htmlspecialchars($row['marks']) . "</td>";
            
            if ($currentLearner !== $row['learnerID']) {
                echo "<td><a href='$testUrl' target='_blank'>Test</a></td>";
                $currentLearner = $row['learnerID'];
            } else {
                echo "<td></td>";
            }
            echo "</tr>";
        }
        echo "</table>";
        
        // Get summary by learner
        echo "<h3>Summary by Learner:</h3>";
        $summaryQuery = "
            SELECT 
                m.learnerID, 
                ld.FirstName, 
                ld.LastName,
                COUNT(DISTINCT m.exercise) as exercise_count,
                COUNT(DISTINCT CASE WHEN m.type = 'Formative' THEN m.exercise END) as formative_count,
                COUNT(DISTINCT CASE WHEN m.type = 'Summative' THEN m.exercise END) as summative_count
            FROM marks m
            LEFT JOIN learnerdetails ld ON m.learnerID = ld.LearnerID
            WHERE m.exercise IN ($exerciseList)
            GROUP BY m.learnerID
            ORDER BY exercise_count DESC
            LIMIT 10
        ";
        
        $summaryResult = $conn->query($summaryQuery);
        
        if ($summaryResult && $summaryResult->num_rows > 0) {
            echo "<table border='1' style='border-collapse: collapse;'>";
            echo "<tr><th>Learner ID</th><th>Name</th><th>Total Exercises</th><th>Formative</th><th>Summative</th><th>Test URL</th></tr>";
            
            while ($row = $summaryResult->fetch_assoc()) {
                $testUrl = "http://rlms.rlms.co.za/mobile/get_poe.php?learnerId=" . $row['learnerID'];
                
                echo "<tr>";
                echo "<td>" . htmlspecialchars($row['learnerID']) . "</td>";
                echo "<td>" . htmlspecialchars(($row['FirstName'] ?? 'Unknown') . ' ' . ($row['LastName'] ?? '')) . "</td>";
                echo "<td>" . htmlspecialchars($row['exercise_count']) . "</td>";
                echo "<td>" . htmlspecialchars($row['formative_count']) . "</td>";
                echo "<td>" . htmlspecialchars($row['summative_count']) . "</td>";
                echo "<td><a href='$testUrl' target='_blank'>Test</a></td>";
                echo "</tr>";
            }
            echo "</table>";
        }
        
    } else {
        echo "<p style='color: red;'>❌ No learners found with marks for Unit Standard 9964 exercises</p>";
    }
    
} else {
    echo "<p style='color: red;'>❌ No exercises found for Unit Standard 9964</p>";
}

// Also check if there might be a typo in the learner ID - look for similar IDs
echo "<h3>Checking for similar learner IDs to 11559:</h3>";
$similarQuery = "
    SELECT LearnerID, FirstName, LastName 
    FROM learnerdetails 
    WHERE LearnerID LIKE '1155%' 
       OR LearnerID LIKE '1156%' 
       OR LearnerID LIKE '1154%'
       OR LearnerID IN (11559, 1155, 1156, 11560, 11558)
    ORDER BY LearnerID
";

$similarResult = $conn->query($similarQuery);

if ($similarResult && $similarResult->num_rows > 0) {
    echo "<table border='1' style='border-collapse: collapse;'>";
    echo "<tr><th>Learner ID</th><th>Name</th><th>Test URL</th></tr>";
    
    while ($row = $similarResult->fetch_assoc()) {
        $testUrl = "http://rlms.rlms.co.za/mobile/get_poe.php?learnerId=" . $row['LearnerID'];
        
        echo "<tr>";
        echo "<td>" . htmlspecialchars($row['LearnerID']) . "</td>";
        echo "<td>" . htmlspecialchars($row['FirstName'] . ' ' . $row['LastName']) . "</td>";
        echo "<td><a href='$testUrl' target='_blank'>Test</a></td>";
        echo "</tr>";
    }
    echo "</table>";
} else {
    echo "<p>No similar learner IDs found</p>";
}

$conn->close();
?>