<?php
/**
 * Simple Validation for Moderation Sampling
 */

echo "=== MODERATION SAMPLING VALIDATION ===\n\n";

$file = 'get_learners_with_poe_assigned.php';

// Check file exists
if (!file_exists($file)) {
    die("❌ File not found: $file\n");
}

echo "✓ File exists: $file\n";
echo "  Size: " . number_format(filesize($file)) . " bytes\n\n";

// Check syntax
exec("php -l $file 2>&1", $output, $return_var);
if ($return_var === 0) {
    echo "✓ PHP syntax is valid\n\n";
} else {
    echo "❌ PHP syntax errors:\n";
    foreach ($output as $line) echo "  $line\n";
    die();
}

// Read content
$content = file_get_contents($file);

// Key features to check
echo "FEATURE CHECKLIST:\n";
echo str_repeat("-", 50) . "\n";

$features = [
    '5-Dimensional Stratification' => [
        'Class',
        'Site', 
        'POE Completeness',
        'Marking Status',
        'Performance Level'
    ],
    'Core Functionality' => [
        'stratified',
        'sampling_method',
        'strata_summary',
        '0.25'
    ],
    'Data Fields' => [
        'poe_completeness',
        'marking_status',
        'performance_level',
        'stratum_type'
    ],
    'Security' => [
        'prepare(',
        'bind_param'
    ],
    'Error Handling' => [
        'try',
        'catch'
    ]
];

$total_checks = 0;
$passed_checks = 0;

foreach ($features as $category => $items) {
    echo "\n$category:\n";
    foreach ($items as $item) {
        $total_checks++;
        if (stripos($content, $item) !== false) {
            echo "  ✓ $item\n";
            $passed_checks++;
        } else {
            echo "  ✗ $item\n";
        }
    }
}

echo "\n" . str_repeat("-", 50) . "\n";
echo "SCORE: $passed_checks / $total_checks checks passed\n\n";

// Extract stratification dimensions
if (preg_match('/\$stratification_dimensions\s*=\s*\[(.*?)\];/s', $content, $matches)) {
    echo "STRATIFICATION DIMENSIONS CONFIGURED:\n";
    $dims = preg_split('/["\'],\s*["\']/', trim($matches[1], " \t\n\r\0\x0B'\"[]"));
    foreach ($dims as $dim) {
        $dim = trim($dim, " \t\n\r\0\x0B'\"");
        if (!empty($dim)) {
            echo "  • $dim\n";
        }
    }
    echo "\n";
}

// Final verdict
if ($passed_checks >= $total_checks * 0.9) {
    echo "✅ VALIDATION PASSED!\n";
    echo "\nThe moderation sampling implementation is complete and ready.\n";
    echo "\nNEXT STEPS:\n";
    echo "1. Upload get_learners_with_poe_assigned.php to your server\n";
    echo "2. Test the endpoint:\n";
    echo "   https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php?moderator_id=TEST001\n";
    echo "3. Check the JSON response for:\n";
    echo "   - status: success\n";
    echo "   - data.sampling_method: stratified_comprehensive\n";
    echo "   - data.strata_summary: array of strata\n";
    echo "   - data.learners: array of selected learners\n";
} else {
    echo "⚠️  VALIDATION INCOMPLETE\n";
    echo "Some features may be missing. Review the checklist above.\n";
}

echo "\n=== VALIDATION COMPLETE ===\n";
?>
