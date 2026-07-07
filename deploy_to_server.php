<?php
/**
 * Deploy the fixed mobile/poe.php to the server
 */

echo "=== DEPLOYING REMEDIAL FIX TO SERVER ===\n\n";

// Read the local fixed file
$localFile = 'mobile/poe.php';
if (!file_exists($localFile)) {
    echo "❌ Local file not found: $localFile\n";
    exit;
}

$fileContent = file_get_contents($localFile);
echo "✅ Read local file: " . strlen($fileContent) . " bytes\n";

// Server details
$serverUrl = "http://192.168.68.105:8080/assessorReport2/";
$uploadUrl = $serverUrl . "upload_fix.php"; // We'll need to create this endpoint

echo "\n=== CURRENT SERVER STATUS ===\n";

// Test current server API
$testUrl = $serverUrl . "mobile/poe.php?learnerId=11515";
echo "Testing: $testUrl\n";

$response = @file_get_contents($testUrl);
if ($response === false) {
    echo "❌ Cannot connect to server\n";
    exit;
}

$data = json_decode($response, true);
if (json_last_error() !== JSON_ERROR_NONE) {
    echo "❌ Invalid JSON response\n";
    exit;
}

// Check for remedial data
$hasRemedialData = false;
if (isset($data['pathways'])) {
    foreach ($data['pathways'] as $pathway) {
        if (isset($pathway['qualifications'])) {
            foreach ($pathway['qualifications'] as $qualification) {
                if (isset($qualification['unitstandards'])) {
                    foreach ($qualification['unitstandards'] as $unitStandard) {
                        if (isset($unitStandard['formativeremedial']) && isset($unitStandard['summativeremedial'])) {
                            $formativeCount = count($unitStandard['formativeremedial']);
                            $summativeCount = count($unitStandard['summativeremedial']);
                            if ($formativeCount > 0 || $summativeCount > 0) {
                                $hasRemedialData = true;
                                break 3;
                            }
                        }
                    }
                }
            }
        }
    }
}

if ($hasRemedialData) {
    echo "✅ Server already has working remedial data\n";
    echo "💡 The fix may already be deployed\n";
} else {
    echo "❌ Server has empty remedial arrays\n";
    echo "💡 Deployment needed\n";
}

echo "\n=== DEPLOYMENT INSTRUCTIONS ===\n";
echo "To deploy the fix:\n\n";

echo "1. MANUAL UPLOAD METHOD:\n";
echo "   - Copy the local file: mobile/poe.php\n";
echo "   - Upload to server: {$serverUrl}mobile/poe.php\n";
echo "   - Ensure file permissions: 644 or 755\n\n";

echo "2. VERIFICATION:\n";
echo "   - Test API: curl '$testUrl'\n";
echo "   - Look for populated 'formativeremedial' and 'summativeremedial' arrays\n";
echo "   - Test in Flutter app with learner 11515\n\n";

echo "3. EXPECTED RESULTS:\n";
echo "   - Assessor interface will show 'Formative Remedial' sections\n";
echo "   - Assessor interface will show 'Summative Remedial' sections\n";
echo "   - Documents will be viewable and markable\n";
echo "   - Comments and approval workflow will work\n\n";

echo "=== FILE READY FOR DEPLOYMENT ===\n";
echo "Local file: $localFile (" . strlen($fileContent) . " bytes)\n";
echo "Target: {$serverUrl}mobile/poe.php\n";
echo "Status: ✅ READY FOR MANUAL UPLOAD\n";
?>