<?php
// Get Unit Standard IDs for learner 11515
echo "=== UNIT STANDARD IDs FOR LEARNER 11515 ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Get data from API
$apiUrl = 'http://192.168.68.160:8080/assessorReport2/mobile/poe.php';
$postData = http_build_query(['learnerID' => '11515']);
$context = stream_context_create([
    'http' => [
        'method' => 'POST',
        'header' => 'Content-Type: application/x-www-form-urlencoded',
        'content' => $postData,
        'timeout' => 10
    ]
]);

$response = @file_get_contents($apiUrl, false, $context);

if ($response === false) {
    echo "❌ Could not retrieve API data\n";
    exit;
}

$data = json_decode($response, true);
if (!isset($data['pathways'])) {
    echo "❌ No pathways data found\n";
    exit;
}

echo "✅ API DATA RETRIEVED\n\n";

$unitStandardCount = 0;
$totalFormative = 0;
$totalSummative = 0;
$totalLogbook = 0;

foreach ($data['pathways'] as $pathwayName => $pathway) {
    echo "PATHWAY: $pathwayName\n";
    echo str_repeat("=", 50) . "\n";
    
    if (isset($pathway['qualifications'])) {
        foreach ($pathway['qualifications'] as $qualName => $qual) {
            echo "\nQUALIFICATION: $qualName\n";
            echo str_repeat("-", 40) . "\n";
            
            if (isset($qual['unitstandards'])) {
                foreach ($qual['unitstandards'] as $unitName => $unit) {
                    $unitStandardCount++;
                    
                    // Extract unit standard ID from name (usually the number at the beginning)
                    preg_match('/^(\d+)/', $unitName, $matches);
                    $unitStandardId = isset($matches[1]) ? $matches[1] : 'N/A';
                    
                    $formativeCount = count($unit['formative'] ?? []);
                    $summativeCount = count($unit['summative'] ?? []);
                    $logbookCount = count($unit['logbook'] ?? []);
                    
                    $totalFormative += $formativeCount;
                    $totalSummative += $summativeCount;
                    $totalLogbook += $logbookCount;
                    
                    echo "\nUNIT STANDARD #$unitStandardCount:\n";
                    echo "  ID: $unitStandardId\n";
                    echo "  Name: $unitName\n";
                    echo "  Formative Questions: $formativeCount\n";
                    echo "  Summative Questions: $summativeCount\n";
                    echo "  Logbook Items: $logbookCount\n";
                    
                    // Show first few formative questions as examples
                    if ($formativeCount > 0) {
                        echo "  Sample Formative Questions:\n";
                        $sampleCount = min(3, $formativeCount);
                        for ($i = 0; $i < $sampleCount; $i++) {
                            $question = $unit['formative'][$i]['exercise'] ?? 'N/A';
                            $questionNum = $unit['formative'][$i]['question_number'] ?? 'N/A';
                            echo "    [$questionNum] " . substr($question, 0, 60) . "...\n";
                        }
                        if ($formativeCount > 3) {
                            echo "    ... and " . ($formativeCount - 3) . " more\n";
                        }
                    }
                    
                    // Show first few summative questions as examples
                    if ($summativeCount > 0) {
                        echo "  Sample Summative Questions:\n";
                        $sampleCount = min(3, $summativeCount);
                        for ($i = 0; $i < $sampleCount; $i++) {
                            $question = $unit['summative'][$i]['exercise'] ?? 'N/A';
                            $questionNum = $unit['summative'][$i]['question_number'] ?? 'N/A';
                            echo "    [$questionNum] " . substr($question, 0, 60) . "...\n";
                        }
                        if ($summativeCount > 3) {
                            echo "    ... and " . ($summativeCount - 3) . " more\n";
                        }
                    }
                    
                    // Show logbook items
                    if ($logbookCount > 0) {
                        echo "  Logbook Items:\n";
                        foreach ($unit['logbook'] as $logItem) {
                            $logExercise = $logItem['exercise'] ?? 'N/A';
                            $logQuestionNum = $logItem['question_number'] ?? 'N/A';
                            echo "    [$logQuestionNum] " . substr($logExercise, 0, 60) . "...\n";
                        }
                    }
                    
                    echo "\n";
                }
            }
        }
    }
}

echo "\n" . str_repeat("=", 60) . "\n";
echo "SUMMARY:\n";
echo "Total Unit Standards: $unitStandardCount\n";
echo "Total Formative Questions: $totalFormative\n";
echo "Total Summative Questions: $totalSummative\n";
echo "Total Logbook Items: $totalLogbook\n";
echo "Grand Total Assessments: " . ($totalFormative + $totalSummative + $totalLogbook) . "\n";

// Also check database for completed unit standards
echo "\n" . str_repeat("=", 60) . "\n";
echo "COMPLETED UNIT STANDARDS IN DATABASE:\n";

try {
    $pdo = new PDO('mysql:host=localhost;dbname=rlmsrlmsco_ezxcmacd_rlms', 'root', '');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Get unique exercises from POE table to see what's been completed
    $stmt = $pdo->prepare("
        SELECT 
            exercise,
            type,
            COUNT(*) as count
        FROM poe 
        WHERE learnerID = ? 
        GROUP BY exercise, type
        ORDER BY type, exercise
    ");
    $stmt->execute(['11515']);
    $completedExercises = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $completedByType = [];
    foreach ($completedExercises as $exercise) {
        $type = $exercise['type'];
        if (!isset($completedByType[$type])) {
            $completedByType[$type] = [];
        }
        $completedByType[$type][] = $exercise['exercise'];
    }
    
    foreach ($completedByType as $type => $exercises) {
        echo "\n$type Completed (" . count($exercises) . " exercises):\n";
        foreach (array_slice($exercises, 0, 5) as $exercise) {
            echo "  - " . substr($exercise, 0, 80) . "...\n";
        }
        if (count($exercises) > 5) {
            echo "  ... and " . (count($exercises) - 5) . " more\n";
        }
    }
    
} catch (Exception $e) {
    echo "❌ Database error: " . $e->getMessage() . "\n";
}

echo "\n=== UNIT STANDARD ID ANALYSIS COMPLETE ===\n";
?>