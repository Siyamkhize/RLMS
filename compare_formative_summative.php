<?php
// Compare formative vs summative data structure
$testLearnerID = 11559;

$url = "https://rlms.rlms.co.za/mobile/get_poe.php?learnerId=" . $testLearnerID;

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
$response = curl_exec($ch);
curl_close($ch);

echo "=== FORMATIVE vs SUMMATIVE COMPARISON ===\n\n";

$data = json_decode($response, true);

foreach ($data['pathways'] ?? [] as $pathwayName => $pathway) {
    foreach ($pathway['qualifications'] ?? [] as $qualName => $qualification) {
        foreach ($qualification['unitstandards'] ?? [] as $unitName => $unitStandard) {
            
            $formative = $unitStandard['formative'] ?? [];
            $summative = $unitStandard['summative'] ?? [];
            
            if (!empty($formative) && !empty($summative)) {
                echo "Unit Standard: $unitName\n\n";
                
                // Find exercises with marks in each type
                $formativeWithMarks = array_filter($formative, function($ex) {
                    return $ex['marks_scored'] !== null;
                });
                
                $summativeWithMarks = array_filter($summative, function($ex) {
                    return $ex['marks_scored'] !== null;
                });
                
                echo "FORMATIVE exercises with marks: " . count($formativeWithMarks) . "\n";
                foreach ($formativeWithMarks as $ex) {
                    echo "  - '{$ex['exercise']}' = {$ex['marks_scored']}\n";
                }
                
                echo "\nSUMMATIVE exercises with marks: " . count($summativeWithMarks) . "\n";
                foreach ($summativeWithMarks as $ex) {
                    echo "  - '{$ex['exercise']}' = {$ex['marks_scored']}\n";
                }
                
                // Compare structure of first exercise from each
                if (!empty($formative) && !empty($summative)) {
                    echo "\nSTRUCTURE COMPARISON:\n";
                    echo "Formative keys: " . implode(', ', array_keys($formative[0])) . "\n";
                    echo "Summative keys: " . implode(', ', array_keys($summative[0])) . "\n";
                    
                    $formativeKeys = array_keys($formative[0]);
                    $summativeKeys = array_keys($summative[0]);
                    
                    $diff1 = array_diff($formativeKeys, $summativeKeys);
                    $diff2 = array_diff($summativeKeys, $formativeKeys);
                    
                    if (!empty($diff1)) {
                        echo "Keys only in formative: " . implode(', ', $diff1) . "\n";
                    }
                    if (!empty($diff2)) {
                        echo "Keys only in summative: " . implode(', ', $diff2) . "\n";
                    }
                    if (empty($diff1) && empty($diff2)) {
                        echo "✅ Both have identical structure\n";
                    }
                }
                
                exit; // Only check first unit standard with both types
            }
        }
    }
}

echo "No unit standard found with both formative and summative data.\n";
?>