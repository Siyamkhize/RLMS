<?php
include 'connection.php';

$learnerID = 16389;

echo "=== VERIFYING PAPER PATH FIX ===\n\n";

// Simulate what the production PDF generator will do
$filePath = "assessorReport2/mobile/ARPL_POE/All_Questions_Basic_Electrical_Safety_Electrician_theory.pdf";

// Calculate htdocs root (same logic as in fixed arpl_pdf.php)
$htdocsRoot = dirname(dirname(dirname(__DIR__)));
if (strpos($htdocsRoot, 'web') !== false) {
    $htdocsRoot = dirname($htdocsRoot);
    if (strpos($htdocsRoot, 'web') !== false) {
        $htdocsRoot = dirname($htdocsRoot);
    }
}

echo "Current script dir: " . __DIR__ . "\n";
echo "Calculated htdocs root: $htdocsRoot\n\n";

// Test all path variations
$possiblePaths = [
    $htdocsRoot . '/' . $filePath,                                    // From htdocs root
    dirname(__DIR__) . '/' . $filePath,                               // Parent of current dir
    __DIR__ . '/' . $filePath,                                        // Current dir
    'ARPL_POE/' . $filePath,                                          // Relative
    'ARPL_POE/' . basename($filePath),                                // Relative with just filename
    $filePath,                                                        // As-is
];

echo "Testing all paths:\n";
$found = false;
$actualFile = null;
foreach ($possiblePaths as $i => $path) {
    $exists = file_exists($path);
    echo "\nPath " . ($i+1) . ":\n";
    echo "  $path\n";
    echo "  Status: " . ($exists ? "✓ FOUND" : "✗ NOT FOUND") . "\n";
    
    if ($exists && !$found) {
        $found = true;
        $actualFile = $path;
        echo "  Action: WILL USE THIS PATH\n";
    }
}

if ($actualFile) {
    echo "\n\n=== RESULT: SUCCESS ✓ ===\n";
    echo "File will be found at: $actualFile\n";
    echo "File size: " . round(filesize($actualFile) / 1024, 2) . " KB\n";
    echo "Status: PDF embedding should work now\n";
} else {
    echo "\n\n=== RESULT: FAILED ✗ ===\n";
    echo "File still not found with any path\n";
}

?>
