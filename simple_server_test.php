<?php
/**
 * Simple test of server API to check remedial data
 */

echo "=== SIMPLE SERVER API TEST ===\n\n";

$apiUrl = "http://192.168.68.160:8080/assessorReport2/mobile/poe.php?learnerId=11515";
echo "Testing: $apiUrl\n\n";

$response = file_get_contents($apiUrl);
if ($response === false) {
    echo "❌ Cannot connect to server\n";
    exit;
}

echo "✅ Got response (" . strlen($response) . " bytes)\n\n";

// Check for remedial arrays in the raw response
$formativeRemedialCount = substr_count($response, '"formativeremedial"');
$summativeRemedialCount = substr_count($response, '"summativeremedial"');

echo "🔍 Found in response:\n";
echo "- 'formativeremedial' appears: $formativeRemedialCount times\n";
echo "- 'summativeremedial' appears: $summativeRemedialCount times\n\n";

// Check for empty arrays
$emptyFormativeRemedial = substr_count($response, '"formativeremedial":[]');
$emptySummativeRemedial = substr_count($response, '"summativeremedial":[]');

echo "📊 Empty arrays:\n";
echo "- Empty 'formativeremedial': $emptyFormativeRemedial\n";
echo "- Empty 'summativeremedial': $emptySummativeRemedial\n\n";

// Check for populated arrays (contains objects)
$populatedFormative = substr_count($response, '"formativeremedial":[{');
$populatedSummative = substr_count($response, '"summativeremedial":[{');

echo "✅ Populated arrays:\n";
echo "- Populated 'formativeremedial': $populatedFormative\n";
echo "- Populated 'summativeremedial': $populatedSummative\n\n";

if ($populatedFormative > 0 || $populatedSummative > 0) {
    echo "🎉 SUCCESS: Server has remedial data!\n";
    echo "The assessor interface should show remedial sections.\n";
} else {
    echo "❌ ISSUE: All remedial arrays are empty\n";
    echo "Need to deploy the fixed mobile/poe.php file to server.\n";
}

// Show a sample of the response
echo "\n=== RESPONSE SAMPLE ===\n";
echo substr($response, 0, 1000) . "...\n";
?>