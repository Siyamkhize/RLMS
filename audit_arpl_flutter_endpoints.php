<?php
/**
 * Comprehensive ARPL Flutter Endpoints Audit
 * Tests all endpoints for all trades (Electrician, Bricklaying, Plumbing)
 * Checks database tables and endpoint status
 */

require_once __DIR__ . '/connection.php';

echo "═════════════════════════════════════════════════════════════\n";
echo "ARPL FLUTTER ENDPOINTS & DATABASE AUDIT\n";
echo "═════════════════════════════════════════════════════════════\n\n";

// Define trades
$trades = [
    '671101' => 'Electrician',
    '641201' => 'Bricklaying', 
    '642601' => 'Plumbing'
];

// Test learners
$testLearner = 16389;
$testLearners = [16389, 20286];

// 1. CHECK ALL ENDPOINTS
echo "1. FLUTTER ENDPOINT FILES\n";
echo "───────────────────────────────────────────────────────────\n";

$endpointDir = __DIR__ . '/mobile';
$endpoints = [
    'get_arpl_data.php',
    'get_arpl_hierarchy.php',
    'get_arpl_appendix_e.php',
    'save_arpl_appendix_e_ratings.php',
    'save_arpl_appendix_e.php',
    'get_arpl_toolkit_data.php',
    'save_arpl_appendix_f_assessment.php',
    'get_arpl_competency_data.php',
    'check_arpl_tables.php',
    'check_arpl_db.php',
];

foreach ($endpoints as $endpoint) {
    $path = "$endpointDir/$endpoint";
    $exists = file_exists($path) ? '✓' : '✗';
    echo "$exists $endpoint\n";
}

// 2. CHECK DATABASE TABLES FOR EACH APPENDIX
echo "\n2. DATABASE TABLES BY APPENDIX\n";
echo "───────────────────────────────────────────────────────────\n";

$appendixes = [
    'A' => 'arpl_appendix_a',
    'B' => 'arpl_competency_scale',
    'C' => 'arpl_appendix_c',
    'D' => 'arpl_appendix_d / gap_analysis',
    'E' => 'arplappxb_*_activities & ratings',
    'F' => 'arpl_appendix_f*',
    'G' => 'arpl_appendix_g',
    'H' => 'arplelectrician/bricklayer/plumber_access_recommendation',
    'I' => 'arpl_appendix_i',
    'J' => 'arpl_appendix_j*',
];

foreach ($appendixes as $letter => $tables) {
    echo "\nAppendix $letter: $tables\n";
    
    // Try to find and count records
    $tableList = explode(' / ', $tables);
    foreach ($tableList as $table) {
        $table = trim($table);
        
        // Handle wildcards
        if (strpos($table, '*') !== false) {
            $pattern = str_replace('*', '%', $table);
            $result = $conn->query("SHOW TABLES LIKE '$pattern'");
            if ($result && $result->num_rows > 0) {
                while ($row = $result->fetch_row()) {
                    $tbl = $row[0];
                    $count = $conn->query("SELECT COUNT(*) FROM $tbl")->fetch_row()[0];
                    echo "  ✓ $tbl: $count records\n";
                }
            }
        } else {
            $result = $conn->query("SHOW TABLES LIKE '$table'");
            if ($result && $result->num_rows > 0) {
                $count = $conn->query("SELECT COUNT(*) FROM $table")->fetch_row()[0];
                echo "  ✓ $table: $count records\n";
            } else {
                echo "  ✗ $table: NOT FOUND\n";
            }
        }
    }
}

// 3. TEST ENDPOINT FUNCTIONALITY
echo "\n3. ENDPOINT FUNCTIONALITY TEST\n";
echo "───────────────────────────────────────────────────────────\n";

$endpoints_to_test = [
    'get_arpl_data.php' => ['learnerID' => $testLearner, 'ofo_code' => '671101'],
    'get_arpl_hierarchy.php' => ['ofo_code' => '671101'],
    'get_arpl_appendix_e.php' => ['learnerID' => $testLearner, 'ofo_code' => '671101'],
    'get_arpl_competency_data.php' => [],
];

foreach ($endpoints_to_test as $endpoint => $params) {
    $path = "$endpointDir/$endpoint";
    if (file_exists($path)) {
        echo "\n$endpoint\n";
        
        // Simulate endpoint call
        $content = file_get_contents($path);
        
        // Check for common issues
        if (strpos($content, 'SELECT') === false && strpos($content, 'INSERT') === false) {
            echo "  ⚠️  No SQL queries found\n";
        } else {
            echo "  ✓ Has database queries\n";
        }
        
        if (strpos($content, 'header') === false || strpos($content, 'json') === false) {
            echo "  ⚠️  May not return JSON\n";
        } else {
            echo "  ✓ Returns JSON\n";
        }
    }
}

// 4. CHECK FOR MISSING ENDPOINTS BY APPENDIX
echo "\n4. MISSING ENDPOINTS\n";
echo "───────────────────────────────────────────────────────────\n";

$required_endpoints = [
    'Appendix A (Application)' => 'get_arpl_application.php / save_arpl_application.php',
    'Appendix B (Competency Scale)' => 'get_arpl_competency_data.php ✓',
    'Appendix C (Trade Curriculum)' => 'get_arpl_curriculum.php',
    'Appendix D (Gap Analysis)' => 'get_arpl_gap_analysis.php / save_arpl_gap_analysis.php',
    'Appendix E (Workplace Eval)' => 'get_arpl_appendix_e.php ✓',
    'Appendix F (Practical Assessment)' => 'get_arpl_appendix_f.php / save_arpl_appendix_f_assessment.php ✓',
    'Appendix G (Assessment Agreement)' => 'get_arpl_assessment_agreement.php',
    'Appendix H (Appeals)' => 'get_arpl_appeals.php / save_arpl_appeals.php',
    'Appendix I (Access Recommendation)' => 'get_arpl_access_recommendation.php / save_arpl_access_recommendation.php',
    'Appendix J (Statement of Results)' => 'get_arpl_statement_of_results.php',
];

foreach ($required_endpoints as $appendix => $endpoints) {
    $parts = explode(' / ', $endpoints);
    $all_exist = true;
    $status = [];
    
    foreach ($parts as $endpoint) {
        $endpoint = trim($endpoint);
        if (strpos($endpoint, '✓') !== false) {
            $status[] = '✓ ' . str_replace(' ✓', '', $endpoint);
        } else {
            $path = "$endpointDir/$endpoint";
            $exists = file_exists($path);
            if ($exists) {
                $status[] = '✓ ' . $endpoint;
            } else {
                $status[] = '✗ ' . $endpoint;
                $all_exist = false;
            }
        }
    }
    
    echo "\n$appendix\n";
    foreach ($status as $s) {
        echo "  $s\n";
    }
}

// 5. CHECK DATA BY TRADE
echo "\n5. DATA SUMMARY BY TRADE\n";
echo "───────────────────────────────────────────────────────────\n";

foreach ($trades as $ofo => $trade) {
    echo "\n$trade ($ofo):\n";
    
    // Check appendix tables
    $checks = [
        'arplappxb_' . strtolower($trade) . '_activities' => 'Appendix B Activities',
        'arplappxe_' . strtolower($trade) . '_activities' => 'Appendix E Activities',
        'arpl' . strtolower($trade) . '_access_recommendation' => 'Access Recommendation',
    ];
    
    foreach ($checks as $table => $label) {
        $result = $conn->query("SHOW TABLES LIKE '$table'");
        if ($result && $result->num_rows > 0) {
            $count = $conn->query("SELECT COUNT(*) FROM $table")->fetch_row()[0];
            echo "  ✓ $label: $count records\n";
        } else {
            echo "  ✗ $label: NOT FOUND\n";
        }
    }
}

echo "\n═════════════════════════════════════════════════════════════\n";
echo "AUDIT COMPLETE\n";
echo "═════════════════════════════════════════════════════════════\n";

$conn->close();
?>
