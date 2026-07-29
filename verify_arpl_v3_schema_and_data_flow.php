<?php
/**
 * ARPL v3 Schema Verification and Data Flow Test
 * Checks all ARPL tables, verifies fields exist, tests save/retrieve for all appendices
 */

include('connection.php');
header('Content-Type: text/html; charset=utf-8');

echo "<h1>ARPL v3 Schema & Data Flow Verification</h1>";
echo "<p><strong>Test Date:</strong> " . date('Y-m-d H:i:s') . "</p>";
echo "<hr>";

// ==================== SECTION 1: TABLE SCHEMA VERIFICATION ====================
echo "<h2>📋 Section 1: Table Schema Verification</h2>";

$tables = [
    'arpl_applications_v3' => [
        'appendix' => 'A (Main Application)',
        'required_fields' => [
            'id', 'learnerID', 'ofo_code', 'classID',
            'full_name', 'id_number', 'contact_number', 'email_address',
            'residential_address', 'qualification_title',
            'currently_employed', 'self_employed',
            'candidate_signature', 'signature_date', 'assessor_signature',
            'created_at', 'updated_at'
        ]
    ],
    'arpl_work_experience_v3' => [
        'appendix' => 'A (Work Experience)',
        'required_fields' => [
            'id', 'application_id', 'learnerID', 'ofo_code',
            'company_name', 'position_title', 'period_from', 'period_to',
            'contact_person', 'contact_tel', 'responsibilities',
            'created_at', 'updated_at'
        ]
    ],
    'arpl_references_v3' => [
        'appendix' => 'A (References)',
        'required_fields' => [
            'id', 'application_id', 'learnerID', 'ofo_code',
            'reference_name', 'reference_company', 'reference_position',
            'reference_tel', 'reference_email', 'relationship',
            'created_at', 'updated_at'
        ]
    ],
    'arpl_eligibility_matrix_v3' => [
        'appendix' => 'A (Eligibility Matrix)',
        'required_fields' => [
            'id', 'application_id', 'learnerID', 'ofo_code',
            'years_of_experience', 'relevant_qualification',
            'trade_certificate', 'meets_requirements',
            'assessor_comments', 'created_at', 'updated_at'
        ]
    ],
    'arpl_competency_scale' => [
        'appendix' => 'B',
        'required_fields' => [
            'id', 'learnerID', 'ofo_code', 'activity_id',
            'rating', 'comments', 'created_at', 'updated_at'
        ]
    ],
    'arpl_appendix_c_bricklayer' => [
        'appendix' => 'C (641201)',
        'required_fields' => ['id', 'learnerID', 'created_at']
    ],
    'arpl_appendix_c_electrician' => [
        'appendix' => 'C (671101)',
        'required_fields' => ['id', 'learnerID', 'created_at']
    ],
    'arpl_appendix_c_plumber' => [
        'appendix' => 'C (642601)',
        'required_fields' => ['id', 'learnerID', 'created_at']
    ],
    'arpl_appendix_d' => [
        'appendix' => 'D',
        'required_fields' => [
            'id', 'learnerID', 'ofo_code', 'question_key',
            'answer', 'created_at', 'updated_at'
        ]
    ],
    'arpl_appendix_e_ratings' => [
        'appendix' => 'E',
        'required_fields' => [
            'id', 'learnerID', 'ofo_code', 'activity_id',
            'rating', 'comments', 'created_at', 'updated_at'
        ]
    ],
    'appendix_f_knowledge_questions' => [
        'appendix' => 'F (Knowledge)',
        'required_fields' => [
            'id', 'learnerID', 'ofoNumber', 'question_number',
            'question_text', 'candidate_score', 'percentage', 'created_at'
        ]
    ],
    'practical_tasks' => [
        'appendix' => 'F (Practical)',
        'required_fields' => [
            'id', 'learnerID', 'ofoNumber', 'task_number',
            'task_name', 'candidate_score', 'percentage',
            'assessor_id', 'created_at'
        ]
    ],
    'workplace_observations' => [
        'appendix' => 'F (Workplace)',
        'required_fields' => [
            'id', 'learnerID', 'ofoNumber', 'activity_id',
            'task_observed', 'technical_knowledge',
            'interpretation_of_instructions', 'team_work_attitude', 'created_at'
        ]
    ],
    'arpl_assessment_agreement' => [
        'appendix' => 'G',
        'required_fields' => [
            'id', 'learnerID', 'ofo_code', 'created_at'
        ]
    ],
    'arpl_statement_of_results' => [
        'appendix' => 'J',
        'required_fields' => [
            'id', 'learnerID', 'ofo_code', 'created_at'
        ]
    ]
];

$schemaResults = [];
foreach ($tables as $tableName => $info) {
    echo "<h3>Table: <code>$tableName</code> (Appendix {$info['appendix']})</h3>";
    
    // Check if table exists
    $checkTable = $conn->query("SHOW TABLES LIKE '$tableName'");
    if ($checkTable->num_rows == 0) {
        echo "<p style='color:red'>❌ <strong>TABLE DOES NOT EXIST</strong></p>";
        $schemaResults[$tableName] = ['exists' => false];
        continue;
    }
    
    echo "<p style='color:green'>✅ Table exists</p>";
    
    // Get actual columns
    $columnsResult = $conn->query("SHOW COLUMNS FROM $tableName");
    $actualColumns = [];
    while ($col = $columnsResult->fetch_assoc()) {
        $actualColumns[] = $col['Field'];
    }
    
    // Check required fields
    $missingFields = [];
    $foundFields = [];
    foreach ($info['required_fields'] as $field) {
        if (in_array($field, $actualColumns)) {
            $foundFields[] = $field;
        } else {
            $missingFields[] = $field;
        }
    }
    
    echo "<p><strong>Required Fields:</strong> " . count($info['required_fields']) . "</p>";
    echo "<p><strong>Found:</strong> " . count($foundFields) . " ✅</p>";
    
    if (!empty($missingFields)) {
        echo "<p style='color:red'><strong>Missing:</strong> " . count($missingFields) . " ❌</p>";
        echo "<ul style='color:red'>";
        foreach ($missingFields as $field) {
            echo "<li>$field</li>";
        }
        echo "</ul>";
    }
    
    // Show actual schema
    echo "<details><summary>View Full Schema (" . count($actualColumns) . " columns)</summary>";
    echo "<table border='1' cellpadding='5' style='margin:10px 0'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th></tr>";
    $columnsResult = $conn->query("SHOW COLUMNS FROM $tableName");
    while ($col = $columnsResult->fetch_assoc()) {
        $inRequired = in_array($col['Field'], $info['required_fields']) ? ' style="background:#d4edda"' : '';
        echo "<tr$inRequired>";
        echo "<td><code>{$col['Field']}</code></td>";
        echo "<td>{$col['Type']}</td>";
        echo "<td>{$col['Null']}</td>";
        echo "<td>{$col['Key']}</td>";
        echo "<td>{$col['Default']}</td>";
        echo "</tr>";
    }
    echo "</table></details>";
    
    // Count records
    $countResult = $conn->query("SELECT COUNT(*) as cnt FROM $tableName");
    $count = $countResult->fetch_assoc()['cnt'];
    echo "<p><strong>Total Records:</strong> $count</p>";
    
    $schemaResults[$tableName] = [
        'exists' => true,
        'found_fields' => count($foundFields),
        'missing_fields' => $missingFields,
        'record_count' => $count
    ];
    
    echo "<hr>";
}

// ==================== SECTION 2: ENDPOINTS VERIFICATION ====================
echo "<h2>🔌 Section 2: Save/Get Endpoints Verification</h2>";

$endpoints = [
    'A' => [
        'save' => 'mobile/save_arpl_application.php',
        'get' => 'mobile/get_arpl_application.php',
        'table' => 'arpl_applications_v3'
    ],
    'B' => [
        'save' => 'mobile/save_arpl_toolkit_edits.php',
        'get' => 'mobile/get_arpl_toolkit_data.php',
        'table' => 'arpl_competency_scale'
    ],
    'D' => [
        'save' => 'mobile/save_arpl_toolkit_edits.php',
        'get' => 'mobile/get_arpl_toolkit_data.php',
        'table' => 'arpl_appendix_d'
    ],
    'E' => [
        'save' => 'mobile/save_arpl_toolkit_edits.php',
        'get' => 'mobile/get_arpl_toolkit_data.php',
        'table' => 'arpl_appendix_e_ratings'
    ],
    'F' => [
        'save' => 'mobile/save_appendix_f_data.php',
        'get' => 'mobile/get_arpl_toolkit_data.php',
        'table' => 'appendix_f_knowledge_questions'
    ],
    'G' => [
        'save' => 'mobile/save_arpl_assessment_agreement.php',
        'get' => 'mobile/get_arpl_assessment_agreement.php',
        'table' => 'arpl_assessment_agreement'
    ],
    'J' => [
        'save' => 'mobile/save_arpl_statement_of_results.php',
        'get' => 'mobile/get_arpl_statement_of_results.php',
        'table' => 'arpl_statement_of_results'
    ]
];

foreach ($endpoints as $appendix => $files) {
    echo "<h3>Appendix $appendix</h3>";
    
    $saveExists = file_exists($files['save']);
    $getExists = file_exists($files['get']);
    
    echo "<p><strong>Save Endpoint:</strong> <code>{$files['save']}</code> ";
    echo $saveExists ? "✅" : "<span style='color:red'>❌ FILE NOT FOUND</span>";
    echo "</p>";
    
    echo "<p><strong>Get Endpoint:</strong> <code>{$files['get']}</code> ";
    echo $getExists ? "✅" : "<span style='color:red'>❌ FILE NOT FOUND</span>";
    echo "</p>";
    
    echo "<p><strong>Target Table:</strong> <code>{$files['table']}</code></p>";
    echo "<hr>";
}

// ==================== SECTION 3: DATA FLOW TEST ====================
echo "<h2>🔄 Section 3: Data Flow Test (Sample Learner)</h2>";

$testLearnerID = 11701; // Anele Cele
$testOFO = '641201'; // Bricklayer

echo "<p><strong>Test Learner ID:</strong> $testLearnerID</p>";
echo "<p><strong>OFO Code:</strong> $testOFO (Bricklayer)</p>";
echo "<hr>";

// Check Appendix A data
echo "<h3>Appendix A - Application Form (v3 Tables)</h3>";

// Main application table
$appQuery = "SELECT * FROM arpl_applications_v3 WHERE learnerID = $testLearnerID AND ofo_code = '$testOFO' LIMIT 1";
$appResult = $conn->query($appQuery);
if ($appResult && $appResult->num_rows > 0) {
    $app = $appResult->fetch_assoc();
    echo "<p style='color:green'>✅ <strong>Main Application Record Found</strong> (ID: {$app['id']})</p>";
    
    // Check key fields
    $keyFields = [
        'full_name' => 'Full Name',
        'id_number' => 'ID Number',
        'contact_number' => 'Contact Number',
        'email_address' => 'Email',
        'currently_employed' => 'Currently Employed',
        'candidate_signature' => 'Candidate Signature'
    ];
    
    echo "<table border='1' cellpadding='5' style='margin:10px 0'>";
    echo "<tr><th>Field</th><th>Value</th><th>Status</th></tr>";
    foreach ($keyFields as $field => $label) {
        $value = isset($app[$field]) ? $app[$field] : 'N/A';
        $isEmpty = empty($value) || $value === 'N/A';
        $status = $isEmpty ? "❌ Empty" : "✅ Has data";
        $color = $isEmpty ? "color:red" : "color:green";
        echo "<tr>";
        echo "<td>$label</td>";
        echo "<td><code>" . htmlspecialchars(substr($value, 0, 50)) . "</code></td>";
        echo "<td style='$color'>$status</td>";
        echo "</tr>";
    }
    echo "</table>";
    
    $applicationId = $app['id'];
} else {
    echo "<p style='color:red'>❌ No main application record found</p>";
    $applicationId = null;
}

// Work Experience table
$weQuery = "SELECT COUNT(*) as cnt FROM arpl_work_experience_v3 WHERE learnerID = $testLearnerID AND ofo_code = '$testOFO'";
$weResult = $conn->query($weQuery);
$weCount = $weResult->fetch_assoc()['cnt'];
echo "<p><strong>Work Experience Records:</strong> $weCount " . ($weCount > 0 ? "✅" : "⚠️") . "</p>";

if ($weCount > 0) {
    $weDetails = $conn->query("SELECT company_name, position_title, period_from, period_to FROM arpl_work_experience_v3 WHERE learnerID = $testLearnerID AND ofo_code = '$testOFO' LIMIT 3");
    echo "<table border='1' cellpadding='5' style='margin:10px 0'>";
    echo "<tr><th>Company</th><th>Position</th><th>Period</th></tr>";
    while ($we = $weDetails->fetch_assoc()) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($we['company_name']) . "</td>";
        echo "<td>" . htmlspecialchars($we['position_title']) . "</td>";
        echo "<td>{$we['period_from']} - {$we['period_to']}</td>";
        echo "</tr>";
    }
    echo "</table>";
}

// References table
$refQuery = "SELECT COUNT(*) as cnt FROM arpl_references_v3 WHERE learnerID = $testLearnerID AND ofo_code = '$testOFO'";
$refResult = $conn->query($refQuery);
$refCount = $refResult->fetch_assoc()['cnt'];
echo "<p><strong>Reference Records:</strong> $refCount " . ($refCount > 0 ? "✅" : "⚠️") . "</p>";

if ($refCount > 0) {
    $refDetails = $conn->query("SELECT reference_name, reference_company, reference_tel FROM arpl_references_v3 WHERE learnerID = $testLearnerID AND ofo_code = '$testOFO' LIMIT 3");
    echo "<table border='1' cellpadding='5' style='margin:10px 0'>";
    echo "<tr><th>Name</th><th>Company</th><th>Tel</th></tr>";
    while ($ref = $refDetails->fetch_assoc()) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($ref['reference_name']) . "</td>";
        echo "<td>" . htmlspecialchars($ref['reference_company']) . "</td>";
        echo "<td>" . htmlspecialchars($ref['reference_tel']) . "</td>";
        echo "</tr>";
    }
    echo "</table>";
}

// Eligibility Matrix table
$eligQuery = "SELECT * FROM arpl_eligibility_matrix_v3 WHERE learnerID = $testLearnerID AND ofo_code = '$testOFO' LIMIT 1";
$eligResult = $conn->query($eligQuery);
if ($eligResult && $eligResult->num_rows > 0) {
    $elig = $eligResult->fetch_assoc();
    echo "<p style='color:green'>✅ <strong>Eligibility Matrix Record Found</strong></p>";
    echo "<ul>";
    echo "<li><strong>Years of Experience:</strong> " . ($elig['years_of_experience'] ?? 'N/A') . "</li>";
    echo "<li><strong>Relevant Qualification:</strong> " . ($elig['relevant_qualification'] ?? 'N/A') . "</li>";
    echo "<li><strong>Meets Requirements:</strong> " . ($elig['meets_requirements'] ?? 'N/A') . "</li>";
    echo "</ul>";
} else {
    echo "<p style='color:orange'>⚠️ No eligibility matrix record found</p>";
}

echo "<hr>";

// Check Appendix A data
echo "<hr>";

// Check Appendix B data
echo "<h3>Appendix B - Competency Scale</h3>";
$bQuery = "SELECT COUNT(*) as cnt FROM arpl_competency_scale WHERE learnerID = $testLearnerID AND ofo_code = '$testOFO'";
$bResult = $conn->query($bQuery);
$bCount = $bResult->fetch_assoc()['cnt'];
echo "<p><strong>Records:</strong> $bCount " . ($bCount > 0 ? "✅" : "❌") . "</p>";

// Check Appendix E data
echo "<h3>Appendix E - Workplace Observations</h3>";
$eQuery = "SELECT COUNT(*) as cnt FROM arpl_appendix_e_ratings WHERE learnerID = $testLearnerID AND ofo_code = '$testOFO'";
$eResult = $conn->query($eQuery);
$eCount = $eResult->fetch_assoc()['cnt'];
echo "<p><strong>Records:</strong> $eCount " . ($eCount > 0 ? "✅" : "❌") . "</p>";

// Check Appendix F data
echo "<h3>Appendix F - Assessment</h3>";
$fkQuery = "SELECT COUNT(*) as cnt FROM appendix_f_knowledge_questions WHERE learnerID = $testLearnerID AND ofoNumber = '$testOFO'";
$fkResult = $conn->query($fkQuery);
$fkCount = $fkResult->fetch_assoc()['cnt'];
echo "<p><strong>Knowledge Questions:</strong> $fkCount " . ($fkCount > 0 ? "✅" : "❌") . "</p>";

$fpQuery = "SELECT COUNT(*) as cnt FROM practical_tasks WHERE learnerID = $testLearnerID AND ofoNumber = '$testOFO'";
$fpResult = $conn->query($fpQuery);
$fpCount = $fpResult->fetch_assoc()['cnt'];
echo "<p><strong>Practical Tasks:</strong> $fpCount " . ($fpCount > 0 ? "✅" : "❌") . "</p>";

$fwQuery = "SELECT COUNT(*) as cnt FROM workplace_observations WHERE learnerID = $testLearnerID AND ofoNumber = '$testOFO'";
$fwResult = $conn->query($fwQuery);
$fwCount = $fwResult->fetch_assoc()['cnt'];
echo "<p><strong>Workplace Observations:</strong> $fwCount " . ($fwCount > 0 ? "✅" : "❌") . "</p>";

// ==================== SECTION 4: SUMMARY ====================
echo "<hr>";
echo "<h2>📊 Summary</h2>";

$totalTables = count($tables);
$existingTables = array_filter($schemaResults, function($r) { return isset($r['exists']) && $r['exists']; });
$tablesWithMissing = array_filter($schemaResults, function($r) { return !empty($r['missing_fields']); });

echo "<h3>Schema Status</h3>";
echo "<p>✅ <strong>Tables Exist:</strong> " . count($existingTables) . " / $totalTables</p>";
echo "<p>" . (count($tablesWithMissing) > 0 ? "❌" : "✅") . " <strong>Tables With Missing Fields:</strong> " . count($tablesWithMissing) . "</p>";

if (!empty($tablesWithMissing)) {
    echo "<ul style='color:red'>";
    foreach ($tablesWithMissing as $table => $info) {
        echo "<li><strong>$table:</strong> " . count($info['missing_fields']) . " missing fields</li>";
    }
    echo "</ul>";
}

echo "<h3>Recommendations</h3>";
echo "<ol>";
if (!empty($tablesWithMissing)) {
    echo "<li style='color:red'><strong>CRITICAL:</strong> Add missing fields to tables before deployment</li>";
}
echo "<li>Verify employment history fields are properly wired in Flutter app</li>";
echo "<li>Test save/retrieve flow for Appendix A in the app</li>";
echo "<li>Ensure all appendix data flows through proper endpoints</li>";
echo "</ol>";

$conn->close();
?>
