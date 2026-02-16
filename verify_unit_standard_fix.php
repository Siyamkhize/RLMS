<?php
/**
 * Verify Unit Standard Extraction Fix
 * Quick diagnostic to check if the fix is working
 */

include('connection.php');

$moderatorId = isset($_GET['moderator_id']) ? $_GET['moderator_id'] : '77';

echo "<h2>Unit Standard Extraction Fix Verification</h2>";
echo "<p>Moderator ID: $moderatorId</p>";
echo "<hr>";

// Step 1: Check MySQL version
echo "<h3>Step 1: MySQL Version</h3>";
$result = $conn->query("SELECT VERSION() as version");
$row = $result->fetch_assoc();
echo "<p>Version: <strong>{$row['version']}</strong></p>";

// Step 2: Check if REGEXP_SUBSTR is available
echo "<h3>Step 2: REGEXP_SUBSTR Support</h3>";
$testQuery = "SELECT REGEXP_SUBSTR('Test 9964 String', '[0-9]{4,5}') as extracted";
$result = $conn->query($testQuery);
if ($result) {
    $row = $result->fetch_assoc();
    if ($row['extracted'] == '9964') {
        echo "<p>✅ REGEXP_SUBSTR is SUPPORTED (MySQL 8.0+)</p>";
        $method = "REGEXP_SUBSTR";
    } else {
        echo "<p>⚠️ REGEXP_SUBSTR not available (MySQL 5.7/MariaDB)</p>";
        $method = "Alternative";
    }
} else {
    echo "<p>⚠️ REGEXP_SUBSTR not available (MySQL 5.7/MariaDB)</p>";
    $method = "Alternative";
}

// Step 3: Test extraction on sample data
echo "<h3>Step 3: Test Extraction</h3>";
$testStrings = [
    "All Questions - 9964 - Apply health and safety to a work area",
    "All Formative Questions - 14555 - Description",
    "Define a safe site",
    "13958 - Unit standard title"
];

echo "<table border='1' cellpadding='5'>";
echo "<tr><th>Original String</th><th>Contains Number?</th><th>Extracted ID</th></tr>";

foreach ($testStrings as $str) {
    $query = "SELECT 
                '" . $conn->real_escape_string($str) . "' REGEXP '[0-9]{4,5}' as has_number,
                REGEXP_SUBSTR('" . $conn->real_escape_string($str) . "', '[0-9]{4,5}') as extracted";
    $result = $conn->query($query);
    if ($result) {
        $row = $result->fetch_assoc();
        echo "<tr>";
        echo "<td>$str</td>";
        echo "<td>" . ($row['has_number'] ? '✅ Yes' : '❌ No') . "</td>";
        echo "<td>" . ($row['extracted'] ?? 'NULL') . "</td>";
        echo "</tr>";
    }
}
echo "</table>";

// Step 4: Check actual data from database
echo "<h3>Step 4: Sample Data from Database</h3>";

// Get a sample learner from moderator's classes
$sql = "SELECT DISTINCT l.LearnerID, l.Name, l.Surname, l.classID
        FROM facilitator f
        INNER JOIN learnerdetails l ON f.classID = l.classID
        WHERE f.facilitator_id = ?
        LIMIT 1";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $moderatorId);
$stmt->execute();
$result = $stmt->get_result();
$learner = $result->fetch_assoc();
$stmt->close();

if ($learner) {
    $learnerId = $learner['LearnerID'];
    echo "<p>Testing with Learner: {$learner['Name']} {$learner['Surname']} (ID: $learnerId)</p>";
    
    // Check POE table
    $sql = "SELECT COUNT(*) as total,
                   SUM(CASE WHEN exercise REGEXP '[0-9]{4,5}' THEN 1 ELSE 0 END) as with_unit_standard
            FROM poe
            WHERE learnerID = ?
            AND exercise IS NOT NULL
            AND exercise != ''";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $learnerId);
    $stmt->execute();
    $result = $stmt->get_result();
    $poeStats = $result->fetch_assoc();
    $stmt->close();
    
    echo "<p><strong>POE Table:</strong></p>";
    echo "<ul>";
    echo "<li>Total exercises: {$poeStats['total']}</li>";
    echo "<li>With unit standard ID: {$poeStats['with_unit_standard']}</li>";
    echo "</ul>";
    
    // Check marks table
    $sql = "SELECT COUNT(*) as total,
                   SUM(CASE WHEN exercise REGEXP '[0-9]{4,5}' THEN 1 ELSE 0 END) as with_unit_standard,
                   SUM(CASE WHEN type = 'Summative' AND exercise REGEXP '[0-9]{4,5}' THEN 1 ELSE 0 END) as summative_with_unit_standard
            FROM marks
            WHERE learnerID = ?
            AND exercise IS NOT NULL
            AND exercise != ''";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $learnerId);
    $stmt->execute();
    $result = $stmt->get_result();
    $marksStats = $result->fetch_assoc();
    $stmt->close();
    
    echo "<p><strong>Marks Table:</strong></p>";
    echo "<ul>";
    echo "<li>Total exercises: {$marksStats['total']}</li>";
    echo "<li>With unit standard ID: {$marksStats['with_unit_standard']}</li>";
    echo "<li>Summative with unit standard ID: {$marksStats['summative_with_unit_standard']}</li>";
    echo "</ul>";
    
    // Check logbook_marks table
    $sql = "SELECT COUNT(*) as total,
                   SUM(CASE WHEN unit_standard_id REGEXP '^[0-9]{4,5}$' THEN 1 ELSE 0 END) as with_unit_standard
            FROM logbook_marks
            WHERE learner_id = ?
            AND unit_standard_id IS NOT NULL
            AND unit_standard_id != ''";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $learnerId);
    $stmt->execute();
    $result = $stmt->get_result();
    $logbookStats = $result->fetch_assoc();
    $stmt->close();
    
    echo "<p><strong>Logbook Marks Table:</strong></p>";
    echo "<ul>";
    echo "<li>Total records: {$logbookStats['total']}</li>";
    echo "<li>With unit standard ID: {$logbookStats['with_unit_standard']}</li>";
    echo "</ul>";
    
} else {
    echo "<p>⚠️ No learners found for moderator $moderatorId</p>";
}

// Step 5: Summary
echo "<hr>";
echo "<h3>Summary</h3>";
echo "<p><strong>Extraction Method:</strong> $method</p>";

if ($learner) {
    $totalWithUnitStandard = $poeStats['with_unit_standard'] + $marksStats['with_unit_standard'] + $logbookStats['with_unit_standard'];
    
    echo "<p><strong>Expected Results for Learner $learnerId:</strong></p>";
    echo "<ul>";
    echo "<li>POE Count: Should be > 0 (found $totalWithUnitStandard records with unit standards)</li>";
    echo "<li>Marking Status: " . ($marksStats['summative_with_unit_standard'] > 0 ? 'Marked ✅' : 'Not Marked ❌') . "</li>";
    echo "<li>Performance Level: " . ($marksStats['summative_with_unit_standard'] > 0 ? 'Should be calculated from summative marks' : 'Not Assessed') . "</li>";
    echo "</ul>";
    
    if ($totalWithUnitStandard == 0) {
        echo "<p>⚠️ <strong>WARNING:</strong> No unit standards found! This learner may not have proper data.</p>";
        echo "<p>Try testing with a different learner or check the database.</p>";
    } else {
        echo "<p>✅ <strong>Data looks good!</strong> The fix should work correctly.</p>";
    }
}

echo "<hr>";
echo "<h3>Next Steps</h3>";
echo "<ol>";
echo "<li>If everything looks good, test the full API: <a href='test_temp_tables_logic.php?moderator_id=$moderatorId'>test_temp_tables_logic.php?moderator_id=$moderatorId</a></li>";
echo "<li>Then test the actual endpoint: <a href='get_learners_with_poe_assigned.php?moderator_id=$moderatorId'>get_learners_with_poe_assigned.php?moderator_id=$moderatorId</a></li>";
echo "<li>If POE count is still 0, you may need to reset assignments: <code>DELETE FROM moderator_assignments WHERE moderator_id = '$moderatorId';</code></li>";
echo "</ol>";

?>
