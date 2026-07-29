<?php
// Find all POE records that might be affecting Unit Standard 14580
echo "<h2>Finding POE Records Affecting Unit Standard 14580</h2>";

include_once('connection.php');

// Check connection
if ($conn->connect_error) {
    echo "<p style='color: red;'>Connection failed: " . htmlspecialchars($conn->connect_error) . "</p>";
    exit;
}

echo "<p>Connected to database successfully.</p>";

// Step 1: Find ALL POE records that contain any reference to construction drawings
echo "<h3>Step 1: Finding POE records related to construction drawings/specifications</h3>";
$poeQuery = "SELECT poe_id, learnerID, exercise, type, filePath, unitStandard 
             FROM poe 
             WHERE exercise LIKE '%construction%' 
             OR exercise LIKE '%drawing%' 
             OR exercise LIKE '%specification%'
             OR exercise LIKE '%interpret%'
             OR exercise LIKE '%read%'
             OR filePath LIKE '%14580%'
             OR filePath LIKE '%construction%'
             OR filePath LIKE '%drawing%'
             ORDER BY learnerID, exercise";

$poeResult = $conn->query($poeQuery);

if ($poeResult && $poeResult->num_rows > 0) {
    echo "<p style='color: green;'>Found " . $poeResult->num_rows . " POE records related to construction drawings</p>";
    
    echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
    echo "<tr><th>POE ID</th><th>Learner ID</th><th>Exercise</th><th>Type</th><th>Unit Standard</th><th>File Path</th></tr>";
    
    $suspiciousRecords = [];
    
    while ($row = $poeResult->fetch_assoc()) {
        $isProblematic = false;
        $bgColor = '';
        
        // Check if this might be incorrectly associated
        if (!empty($row['unitStandard']) && strpos($row['unitStandard'], '14580') === false) {
            // Has a unit standard but it's not 14580, yet the content suggests it should be
            if (stripos($row['exercise'], 'construction') !== false || 
                stripos($row['exercise'], 'drawing') !== false ||
                stripos($row['exercise'], 'interpret') !== false) {
                $isProblematic = true;
                $bgColor = 'background-color: #ffeeee;';
                $suspiciousRecords[] = $row;
            }
        } elseif (empty($row['unitStandard'])) {
            // No unit standard assigned but content suggests it should be 14580
            if (stripos($row['exercise'], 'construction') !== false || 
                stripos($row['exercise'], 'drawing') !== false ||
                stripos($row['exercise'], 'interpret') !== false) {
                $isProblematic = true;
                $bgColor = 'background-color: #fff3cd;';
                $suspiciousRecords[] = $row;
            }
        }
        
        echo "<tr style='$bgColor'>";
        echo "<td>" . htmlspecialchars($row['poe_id']) . "</td>";
        echo "<td>" . htmlspecialchars($row['learnerID']) . "</td>";
        echo "<td>" . htmlspecialchars($row['exercise']) . "</td>";
        echo "<td>" . htmlspecialchars($row['type']) . "</td>";
        echo "<td>" . htmlspecialchars($row['unitStandard'] ?? 'NULL') . "</td>";
        echo "<td>" . htmlspecialchars($row['filePath']) . "</td>";
        echo "</tr>";
    }
    echo "</table>";
    
    if (count($suspiciousRecords) > 0) {
        echo "<p style='color: orange;'>⚠️ Found " . count($suspiciousRecords) . " potentially problematic records</p>";
    }
} else {
    echo "<p style='color: orange;'>No POE records found related to construction drawings</p>";
}

// Step 2: Check for marks that might be incorrectly linking to 14580 assessments
echo "<h3>Step 2: Checking marks that might be incorrectly associated with 14580</h3>";
$marksQuery = "
    SELECT 
        m.mark_id,
        m.learnerID,
        m.exercise,
        m.type,
        m.marks,
        m.total_marks,
        a.unit_standard_id,
        a.assessment_type
    FROM marks m
    LEFT JOIN assessments a ON (
        TRIM(REPLACE(REPLACE(REPLACE(m.exercise, '\r', ''), '\n', ''), ' ', '')) = 
        TRIM(REPLACE(REPLACE(REPLACE(a.exercise, '\r', ''), '\n', ''), ' ', ''))
        OR m.exercise = a.exercise
    )
    WHERE (
        m.exercise LIKE '%construction%' 
        OR m.exercise LIKE '%drawing%' 
        OR m.exercise LIKE '%specification%'
        OR m.exercise LIKE '%interpret%'
        OR a.unit_standard_id = 14580
    )
    ORDER BY m.learnerID, m.exercise
";

$marksResult = $conn->query($marksQuery);

if ($marksResult && $marksResult->num_rows > 0) {
    echo "<p style='color: green;'>Found " . $marksResult->num_rows . " marks records potentially related to 14580</p>";
    
    echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
    echo "<tr><th>Mark ID</th><th>Learner ID</th><th>Exercise</th><th>Type</th><th>Marks</th><th>Total</th><th>Assessment Unit Standard</th><th>Assessment Type</th></tr>";
    
    $crossContamination = [];
    
    while ($row = $marksResult->fetch_assoc()) {
        $bgColor = '';
        
        // Check for cross-contamination
        if (!empty($row['unit_standard_id']) && $row['unit_standard_id'] != 14580) {
            // This mark is associated with a non-14580 assessment but has 14580-related content
            if (stripos($row['exercise'], 'construction') !== false || 
                stripos($row['exercise'], 'drawing') !== false ||
                stripos($row['exercise'], 'interpret') !== false) {
                $bgColor = 'background-color: #ffeeee;';
                $crossContamination[] = $row;
            }
        }
        
        echo "<tr style='$bgColor'>";
        echo "<td>" . htmlspecialchars($row['mark_id']) . "</td>";
        echo "<td>" . htmlspecialchars($row['learnerID']) . "</td>";
        echo "<td>" . htmlspecialchars($row['exercise']) . "</td>";
        echo "<td>" . htmlspecialchars($row['type']) . "</td>";
        echo "<td>" . htmlspecialchars($row['marks']) . "</td>";
        echo "<td>" . htmlspecialchars($row['total_marks']) . "</td>";
        echo "<td>" . htmlspecialchars($row['unit_standard_id'] ?? 'NULL') . "</td>";
        echo "<td>" . htmlspecialchars($row['assessment_type'] ?? 'NULL') . "</td>";
        echo "</tr>";
    }
    echo "</table>";
    
    if (count($crossContamination) > 0) {
        echo "<p style='color: red;'>🚨 Found " . count($crossContamination) . " cross-contamination issues!</p>";
    }
} else {
    echo "<p style='color: orange;'>No marks records found potentially related to 14580</p>";
}

// Step 3: Check for "All Questions" patterns that might be causing issues
echo "<h3>Step 3: Searching for 'All Questions' patterns in POE</h3>";
$allQuestionsQuery = "SELECT poe_id, learnerID, exercise, type, filePath, unitStandard 
                      FROM poe 
                      WHERE exercise LIKE '%All Questions%' 
                      OR exercise LIKE '%all questions%'
                      ORDER BY learnerID, exercise";

$allQuestionsResult = $conn->query($allQuestionsQuery);

if ($allQuestionsResult && $allQuestionsResult->num_rows > 0) {
    echo "<p style='color: green;'>Found " . $allQuestionsResult->num_rows . " 'All Questions' POE records</p>";
    
    echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
    echo "<tr><th>POE ID</th><th>Learner ID</th><th>Exercise</th><th>Type</th><th>Unit Standard</th><th>File Path</th></tr>";
    
    while ($row = $allQuestionsResult->fetch_assoc()) {
        $bgColor = '';
        
        // Highlight records that might be causing unit standard confusion
        if (stripos($row['exercise'], '14580') !== false) {
            $bgColor = 'background-color: #d4edda;'; // Green for 14580
        } elseif (preg_match('/\d{4,6}/', $row['exercise'])) {
            $bgColor = 'background-color: #fff3cd;'; // Yellow for other unit standards
        }
        
        echo "<tr style='$bgColor'>";
        echo "<td>" . htmlspecialchars($row['poe_id']) . "</td>";
        echo "<td>" . htmlspecialchars($row['learnerID']) . "</td>";
        echo "<td>" . htmlspecialchars($row['exercise']) . "</td>";
        echo "<td>" . htmlspecialchars($row['type']) . "</td>";
        echo "<td>" . htmlspecialchars($row['unitStandard'] ?? 'NULL') . "</td>";
        echo "<td>" . htmlspecialchars($row['filePath']) . "</td>";
        echo "</tr>";
    }
    echo "</table>";
} else {
    echo "<p style='color: orange;'>No 'All Questions' POE records found</p>";
}

// Step 4: Generate specific fix recommendations
echo "<h3>Step 4: Specific Fix Recommendations</h3>";

if (isset($suspiciousRecords) && count($suspiciousRecords) > 0) {
    echo "<div style='background-color: #fff3cd; padding: 15px; border: 1px solid #ffeaa7; border-radius: 5px;'>";
    echo "<h4>🔧 Recommended Fixes for POE Records:</h4>";
    echo "<pre>";
    echo "-- Update POE records that should be associated with Unit Standard 14580\n";
    foreach ($suspiciousRecords as $record) {
        if (empty($record['unitStandard'])) {
            echo "UPDATE poe SET unitStandard = '14580 - Read and interpret construction drawings and specifications' WHERE poe_id = " . $record['poe_id'] . ";\n";
        }
    }
    echo "</pre>";
    echo "</div>";
}

if (isset($crossContamination) && count($crossContamination) > 0) {
    echo "<div style='background-color: #f8d7da; padding: 15px; border: 1px solid #f5c6cb; border-radius: 5px; margin-top: 10px;'>";
    echo "<h4>🚨 Cross-Contamination Issues Found:</h4>";
    echo "<p>The following marks are associated with assessments that have different unit standards than expected:</p>";
    echo "<ul>";
    foreach ($crossContamination as $issue) {
        echo "<li>Mark ID " . $issue['mark_id'] . " (Learner " . $issue['learnerID'] . ") - Exercise: '" . htmlspecialchars($issue['exercise']) . "' is linked to Unit Standard " . $issue['unit_standard_id'] . " instead of 14580</li>";
    }
    echo "</ul>";
    echo "<p><strong>This could be causing the 'ticks unit standard that doesn't belong there' issue you mentioned!</strong></p>";
    echo "</div>";
}

$conn->close();
?>