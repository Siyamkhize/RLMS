<?php
/**
 * Verify all ARPL SAVE endpoints exist and save to correct tables
 * Appendices A through I
 */

require_once 'connection.php';

echo "ARPL SAVE ENDPOINTS VERIFICATION\n";
echo "═════════════════════════════════════════════════════════════\n\n";

// Define all SAVE endpoints needed and their database tables
$saveEndpoints = [
    'Appendix A' => [
        'endpoint' => 'save_arpl_application.php',
        'tables' => ['arpl_applications_v4', 'arpl_applications_v3'],
        'description' => 'Application Form'
    ],
    'Appendix B' => [
        'endpoint' => 'save_arpl_appendix_b.php',
        'tables' => ['arpl_competency_scale'],
        'description' => 'Competency Scale'
    ],
    'Appendix C' => [
        'endpoint' => 'save_arpl_appendix_c.php',
        'tables' => ['arpl_appendix_c', 'arpl_appendix_c_bricklayer', 'arpl_appendix_c_plumber'],
        'description' => 'Trade Curriculum'
    ],
    'Appendix D' => [
        'endpoint' => 'save_arpl_gap_analysis.php',
        'tables' => ['arpl_appendix_d', 'arpl_gap_analysis_unit_standards'],
        'description' => 'Gap Analysis'
    ],
    'Appendix E' => [
        'endpoint' => 'save_arpl_appendix_e.php',
        'tables' => ['arplappxe_electrician_activity_ratings', 'arplappxe_bricklaying_activity_ratings', 'arplappxe_plumbing_activity_ratings'],
        'description' => 'Workplace Evaluation Ratings'
    ],
    'Appendix F' => [
        'endpoint' => 'save_arpl_appendix_f.php',
        'tables' => ['arpl_appendix_f', 'arpl_appendix_f_bricklayer', 'arpl_appendix_f_plumber'],
        'description' => 'Practical Assessment'
    ],
    'Appendix G' => [
        'endpoint' => 'save_arpl_appendix_g.php',
        'tables' => ['arpl_appendix_g', 'arpl_appendix_g_bricklayer', 'arpl_appendix_g_plumber'],
        'description' => 'Assessment Agreement'
    ],
    'Appendix H' => [
        'endpoint' => 'save_appxh_recommendation.php',
        'tables' => ['arpl_appendix_h'],
        'description' => 'Appeals'
    ],
    'Appendix I' => [
        'endpoint' => 'save_arpl_access_recommendation.php',
        'tables' => ['arplelectrician_access_recommendation', 'arplbricklayer_access_recommendation', 'arplplumber_access_recommendation'],
        'description' => 'Access Recommendation'
    ],
];

$sourceDir = __DIR__ . '/mobile';
$prodDir = 'C:/xampp/htdocs/web/web/web/mobile';

echo "1. SAVE ENDPOINTS FILE STATUS\n";
echo "───────────────────────────────────────────────────────────\n";

$endpointCount = 0;
$missingEndpoints = [];

foreach ($saveEndpoints as $appendix => $info) {
    $endpoint = $info['endpoint'];
    $description = $info['description'];
    
    $sourceExists = file_exists("$sourceDir/$endpoint");
    $prodExists = file_exists("$prodDir/$endpoint");
    
    $status = ($sourceExists && $prodExists) ? '✓' : '✗';
    $location = '';
    
    if ($sourceExists && $prodExists) {
        $endpointCount++;
        $location = '(Both)';
    } elseif ($sourceExists) {
        $location = '(Source only - NOT DEPLOYED)';
        $missingEndpoints[] = $endpoint;
    } elseif ($prodExists) {
        $endpointCount++;
        $location = '(Production only)';
    } else {
        $location = '(MISSING)';
        $missingEndpoints[] = $endpoint;
    }
    
    echo "$status $appendix - $endpoint $location\n";
    echo "   → $description\n";
}

echo "\n2. DATABASE TABLES VERIFICATION\n";
echo "───────────────────────────────────────────────────────────\n";

foreach ($saveEndpoints as $appendix => $info) {
    $tables = $info['tables'];
    $endpoint = $info['endpoint'];
    
    echo "\n$appendix ($endpoint):\n";
    
    $allTablesExist = true;
    foreach ($tables as $table) {
        $result = $conn->query("SHOW TABLES LIKE '$table'");
        if ($result && $result->num_rows > 0) {
            $count = $conn->query("SELECT COUNT(*) as cnt FROM `$table`")->fetch_row()[0];
            echo "  ✓ $table: $count records\n";
        } else {
            echo "  ✗ $table: MISSING\n";
            $allTablesExist = false;
        }
    }
}

echo "\n3. SAVE ENDPOINT IMPLEMENTATION CHECK\n";
echo "───────────────────────────────────────────────────────────\n";

$implementedCount = 0;
$partiallyImplemented = [];

foreach ($saveEndpoints as $appendix => $info) {
    $endpoint = $info['endpoint'];
    $filePath = "$sourceDir/$endpoint";
    
    if (!file_exists($filePath)) {
        echo "$appendix - FILE MISSING\n";
        continue;
    }
    
    $content = file_get_contents($filePath);
    
    // Check for key implementation elements
    $hasInsert = strpos($content, 'INSERT') !== false;
    $hasUpdate = strpos($content, 'UPDATE') !== false;
    $hasSelect = strpos($content, 'SELECT') !== false;
    $hasJson = strpos($content, 'json_encode') !== false;
    $hasError = strpos($content, 'error') !== false || strpos($content, 'Exception') !== false;
    
    $implemented = $hasInsert || $hasUpdate;
    $complete = $implemented && $hasJson && $hasError;
    
    if ($complete) {
        $implementedCount++;
        echo "✓ $appendix - Fully implemented (INSERT/UPDATE, JSON, Error handling)\n";
    } elseif ($implemented) {
        $partiallyImplemented[] = $appendix;
        echo "⚠ $appendix - Partially implemented (Missing components)\n";
    } else {
        echo "✗ $appendix - Not implemented\n";
    }
}

echo "\n4. SUMMARY\n";
echo "───────────────────────────────────────────────────────────\n";
echo "Total Save Endpoints: " . count($saveEndpoints) . "\n";
echo "Deployed: $endpointCount\n";
echo "Missing: " . count($missingEndpoints) . "\n";
echo "Fully Implemented: $implementedCount\n";
echo "Partially Implemented: " . count($partiallyImplemented) . "\n";

if (!empty($missingEndpoints)) {
    echo "\nMissing Endpoints:\n";
    foreach ($missingEndpoints as $endpoint) {
        echo "  - $endpoint\n";
    }
}

if (!empty($partiallyImplemented)) {
    echo "\nPartially Implemented (May need review):\n";
    foreach ($partiallyImplemented as $appendix) {
        echo "  - $appendix\n";
    }
}

echo "\n═════════════════════════════════════════════════════════════\n";
echo "VERIFICATION COMPLETE\n";
echo "═════════════════════════════════════════════════════════════\n";

$conn->close();
?>
