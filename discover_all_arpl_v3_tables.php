<?php
/**
 * Discover and Verify ALL ARPL v3 Tables
 * Auto-discovers tables matching pattern: arpl%v3
 * Verifies schema, naming, and data relationships
 */

include('connection.php');
header('Content-Type: text/html; charset=utf-8');

echo "<h1>🔍 ARPL v3 Tables Discovery & Verification</h1>";
echo "<p><strong>Test Date:</strong> " . date('Y-m-d H:i:s') . "</p>";
echo "<hr>";

// ==================== STEP 1: DISCOVER ALL ARPL v3 TABLES ====================
echo "<h2>📋 Step 1: Discovering All ARPL v3 Tables</h2>";

$discoverQuery = "SHOW TABLES LIKE 'arpl%v3'";
$result = $conn->query($discoverQuery);

$discoveredTables = [];
if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_array()) {
        $tableName = $row[0];
        $discoveredTables[] = $tableName;
    }
}

echo "<p><strong>Found " . count($discoveredTables) . " tables matching pattern 'arpl%v3':</strong></p>";
echo "<ul style='background:#f0f0f0; padding:15px; border-left:4px solid #006341'>";
foreach ($discoveredTables as $table) {
    echo "<li><code>$table</code></li>";
}
echo "</ul>";

if (empty($discoveredTables)) {
    echo "<p style='color:red'>❌ <strong>NO TABLES FOUND!</strong> This is critical.</p>";
    exit;
}

echo "<hr>";

// ==================== STEP 2: ANALYZE EACH TABLE ====================
echo "<h2>🔬 Step 2: Analyzing Each Table</h2>";

$tableAnalysis = [];

foreach ($discoveredTables as $tableName) {
    echo "<h3>Table: <code>$tableName</code></h3>";
    
    // Get columns
    $columnsQuery = "SHOW COLUMNS FROM $tableName";
    $columnsResult = $conn->query($columnsQuery);
    
    $columns = [];
    $hasLearnerID = false;
    $hasOfoCode = false;
    $hasCreatedAt = false;
    $hasApplicationId = false;
    
    while ($col = $columnsResult->fetch_assoc()) {
        $columns[] = $col;
        $fieldName = strtolower($col['Field']);
        
        if ($fieldName === 'learnerid') $hasLearnerID = true;
        if (in_array($fieldName, ['ofo_code', 'ofonumber'])) $hasOfoCode = true;
        if ($fieldName === 'created_at') $hasCreatedAt = true;
        if ($fieldName === 'application_id') $hasApplicationId = true;
    }
    
    // Count records
    $countQuery = "SELECT COUNT(*) as cnt FROM $tableName";
    $countResult = $conn->query($countQuery);
    $recordCount = $countResult->fetch_assoc()['cnt'];
    
    // Determine table purpose based on name
    $purpose = 'Unknown';
    $expectedRelationship = '';
    
    if (strpos($tableName, 'applications') !== false) {
        $purpose = 'Main Application Form (Appendix A)';
        $expectedRelationship = 'One record per learner per OFO';
    } elseif (strpos($tableName, 'work_experience') !== false) {
        $purpose = 'Work Experience History (Appendix A)';
        $expectedRelationship = 'Multiple records per application (employment history)';
    } elseif (strpos($tableName, 'references') !== false) {
        $purpose = 'Professional References (Appendix A)';
        $expectedRelationship = 'Multiple records per application (3 references)';
    } elseif (strpos($tableName, 'eligibility') !== false) {
        $purpose = 'Eligibility Matrix (Appendix A)';
        $expectedRelationship = 'One record per application (assessment criteria)';
    } elseif (strpos($tableName, 'qualifications') !== false) {
        $purpose = 'Qualifications & Certificates (Appendix A)';
        $expectedRelationship = 'Multiple records per learner';
    } elseif (strpos($tableName, 'training') !== false) {
        $purpose = 'Training History (Appendix A)';
        $expectedRelationship = 'Multiple records per learner';
    } elseif (strpos($tableName, 'competency') !== false) {
        $purpose = 'Competency Assessment (Appendix B/E)';
        $expectedRelationship = 'Multiple records per learner (ratings)';
    }
    
    // Store analysis
    $tableAnalysis[$tableName] = [
        'purpose' => $purpose,
        'relationship' => $expectedRelationship,
        'column_count' => count($columns),
        'record_count' => $recordCount,
        'has_learnerID' => $hasLearnerID,
        'has_ofo_code' => $hasOfoCode,
        'has_created_at' => $hasCreatedAt,
        'has_application_id' => $hasApplicationId,
        'columns' => $columns
    ];
    
    // Display info
    echo "<div style='background:#f9f9f9; padding:15px; margin:10px 0; border-left:4px solid #006341'>";
    echo "<p><strong>Purpose:</strong> $purpose</p>";
    echo "<p><strong>Expected Relationship:</strong> $expectedRelationship</p>";
    echo "<p><strong>Columns:</strong> " . count($columns) . "</p>";
    echo "<p><strong>Records:</strong> $recordCount " . ($recordCount > 0 ? "✅" : "⚠️ No data") . "</p>";
    
    echo "<p><strong>Key Fields:</strong></p>";
    echo "<ul>";
    echo "<li>learnerID: " . ($hasLearnerID ? "✅ Found" : "❌ Missing") . "</li>";
    echo "<li>ofo_code: " . ($hasOfoCode ? "✅ Found" : "⚠️ Missing") . "</li>";
    echo "<li>application_id: " . ($hasApplicationId ? "✅ Found (related table)" : "N/A (main table)") . "</li>";
    echo "<li>created_at: " . ($hasCreatedAt ? "✅ Found" : "⚠️ Missing") . "</li>";
    echo "</ul>";
    
    // Show columns
    echo "<details><summary><strong>View Column Details (" . count($columns) . " columns)</strong></summary>";
    echo "<table border='1' cellpadding='5' style='margin:10px 0; font-size:12px'>";
    echo "<tr style='background:#006341; color:white'>";
    echo "<th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th><th>Extra</th>";
    echo "</tr>";
    
    foreach ($columns as $col) {
        // Highlight important columns
        $isImportant = in_array(strtolower($col['Field']), 
            ['id', 'learnerid', 'ofo_code', 'ofonumber', 'application_id', 'created_at', 'updated_at']);
        $rowStyle = $isImportant ? 'background:#d4edda; font-weight:bold' : '';
        
        echo "<tr style='$rowStyle'>";
        echo "<td><code>{$col['Field']}</code></td>";
        echo "<td>{$col['Type']}</td>";
        echo "<td>{$col['Null']}</td>";
        echo "<td>{$col['Key']}</td>";
        echo "<td>" . ($col['Default'] ?? 'NULL') . "</td>";
        echo "<td>{$col['Extra']}</td>";
        echo "</tr>";
    }
    echo "</table>";
    echo "</details>";
    echo "</div>";
    echo "<hr>";
}

// ==================== STEP 3: DATA RELATIONSHIP VERIFICATION ====================
echo "<h2>🔗 Step 3: Data Relationship Verification</h2>";

$testLearnerID = 11701; // Anele Cele
$testOFO = '641201'; // Bricklayer

echo "<p><strong>Test Learner:</strong> ID $testLearnerID (Anele Cele)</p>";
echo "<p><strong>Test OFO:</strong> $testOFO (Bricklayer)</p>";
echo "<hr>";

// Check main application
if (in_array('arpl_applications_v3', $discoveredTables)) {
    echo "<h3>Main Application (arpl_applications_v3)</h3>";
    $appQuery = "SELECT * FROM arpl_applications_v3 WHERE learnerID = $testLearnerID AND ofo_code = '$testOFO' LIMIT 1";
    $appResult = $conn->query($appQuery);
    
    if ($appResult && $appResult->num_rows > 0) {
        $app = $appResult->fetch_assoc();
        $applicationId = $app['id'];
        echo "<p style='color:green'>✅ <strong>Application Found</strong> (ID: $applicationId)</p>";
        
        echo "<table border='1' cellpadding='5' style='margin:10px 0'>";
        echo "<tr><th>Field</th><th>Value</th></tr>";
        foreach ($app as $key => $value) {
            if (!in_array($key, ['id', 'learnerID', 'ofo_code'])) {
                $displayValue = strlen($value) > 50 ? substr($value, 0, 50) . '...' : $value;
                echo "<tr><td>$key</td><td><code>" . htmlspecialchars($displayValue) . "</code></td></tr>";
            }
        }
        echo "</table>";
    } else {
        echo "<p style='color:red'>❌ No application found for this learner</p>";
        $applicationId = null;
    }
}

// Check related tables
$relatedTables = ['arpl_work_experience_v3', 'arpl_references_v3', 'arpl_eligibility_matrix_v3'];

foreach ($relatedTables as $relTable) {
    if (in_array($relTable, $discoveredTables)) {
        echo "<h3>" . str_replace('_', ' ', ucwords($relTable, '_')) . "</h3>";
        
        // Try different query patterns
        $queries = [
            "SELECT * FROM $relTable WHERE learnerID = $testLearnerID AND ofo_code = '$testOFO'",
            "SELECT * FROM $relTable WHERE learnerID = $testLearnerID",
        ];
        
        if (isset($applicationId)) {
            array_unshift($queries, "SELECT * FROM $relTable WHERE application_id = $applicationId");
        }
        
        $found = false;
        foreach ($queries as $query) {
            $result = $conn->query($query);
            if ($result && $result->num_rows > 0) {
                $found = true;
                echo "<p style='color:green'>✅ <strong>Found " . $result->num_rows . " record(s)</strong></p>";
                
                echo "<table border='1' cellpadding='5' style='margin:10px 0; font-size:12px'>";
                $firstRow = true;
                while ($row = $result->fetch_assoc()) {
                    if ($firstRow) {
                        echo "<tr style='background:#006341; color:white'>";
                        foreach (array_keys($row) as $colName) {
                            echo "<th>$colName</th>";
                        }
                        echo "</tr>";
                        $firstRow = false;
                    }
                    echo "<tr>";
                    foreach ($row as $value) {
                        $displayValue = strlen($value) > 30 ? substr($value, 0, 30) . '...' : $value;
                        echo "<td>" . htmlspecialchars($displayValue) . "</td>";
                    }
                    echo "</tr>";
                }
                echo "</table>";
                break;
            }
        }
        
        if (!found) {
            echo "<p style='color:orange'>⚠️ No records found for this learner</p>";
        }
        echo "<hr>";
    }
}

// ==================== STEP 4: SUMMARY & RECOMMENDATIONS ====================
echo "<h2>📊 Step 4: Summary & Recommendations</h2>";

echo "<h3>Discovered Tables Summary</h3>";
echo "<table border='1' cellpadding='8' style='width:100%; border-collapse:collapse'>";
echo "<tr style='background:#006341; color:white'>";
echo "<th>Table Name</th><th>Purpose</th><th>Columns</th><th>Records</th><th>Has learnerID</th><th>Has OFO</th><th>Status</th>";
echo "</tr>";

foreach ($tableAnalysis as $tableName => $analysis) {
    $statusIcon = "✅";
    $statusColor = "#d4edda";
    
    if (!$analysis['has_learnerID']) {
        $statusIcon = "❌";
        $statusColor = "#f8d7da";
    } elseif ($analysis['record_count'] == 0) {
        $statusIcon = "⚠️";
        $statusColor = "#fff3cd";
    }
    
    echo "<tr style='background:$statusColor'>";
    echo "<td><code>$tableName</code></td>";
    echo "<td>{$analysis['purpose']}</td>";
    echo "<td>{$analysis['column_count']}</td>";
    echo "<td>{$analysis['record_count']}</td>";
    echo "<td>" . ($analysis['has_learnerID'] ? "✅" : "❌") . "</td>";
    echo "<td>" . ($analysis['has_ofo_code'] ? "✅" : "⚠️") . "</td>";
    echo "<td>$statusIcon</td>";
    echo "</tr>";
}
echo "</table>";

echo "<h3>Naming Convention Analysis</h3>";
echo "<p><strong>Expected Pattern:</strong> <code>arpl_{section}_{subsection}_v3</code></p>";
echo "<ul>";
foreach ($discoveredTables as $table) {
    $isCorrect = preg_match('/^arpl_[a-z_]+_v3$/', $table);
    echo "<li><code>$table</code> - " . ($isCorrect ? "✅ Correct" : "⚠️ Check naming") . "</li>";
}
echo "</ul>";

echo "<h3>Recommendations</h3>";
echo "<div style='background:#fff3cd; padding:15px; border-left:4px solid #ffc107'>";
echo "<ol>";

// Check for missing learnerID
$missingLearnerID = array_filter($tableAnalysis, function($a) { return !$a['has_learnerID']; });
if (!empty($missingLearnerID)) {
    echo "<li style='color:red'><strong>CRITICAL:</strong> These tables are missing 'learnerID' field:<ul>";
    foreach ($missingLearnerID as $table => $info) {
        echo "<li><code>$table</code></li>";
    }
    echo "</ul></li>";
}

// Check for empty tables
$emptyTables = array_filter($tableAnalysis, function($a) { return $a['record_count'] == 0; });
if (!empty($emptyTables)) {
    echo "<li><strong>WARNING:</strong> These tables have no data:<ul>";
    foreach ($emptyTables as $table => $info) {
        echo "<li><code>$table</code> - {$info['purpose']}</li>";
    }
    echo "</ul></li>";
}

// Check application_id relationships
$needsApplicationId = ['arpl_work_experience_v3', 'arpl_references_v3', 'arpl_eligibility_matrix_v3'];
foreach ($needsApplicationId as $table) {
    if (in_array($table, $discoveredTables)) {
        if (!$tableAnalysis[$table]['has_application_id']) {
            echo "<li style='color:orange'><strong>IMPORTANT:</strong> <code>$table</code> should have 'application_id' to link to main application</li>";
        }
    }
}

echo "<li>Ensure Flutter app saves data to correct tables based on purpose</li>";
echo "<li>Verify <code>arpl_work_experience_v3</code> saves employment history</li>";
echo "<li>Verify <code>arpl_references_v3</code> saves professional references</li>";
echo "<li>Verify <code>arpl_eligibility_matrix_v3</code> saves eligibility assessment</li>";
echo "</ol>";
echo "</div>";

$conn->close();
?>
