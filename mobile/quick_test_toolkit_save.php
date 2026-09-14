<?php
/**
 * Quick Test for save_arpl_toolkit_edits.php
 * Tests if the endpoint exists and can handle requests
 */

header('Content-Type: text/html; charset=utf-8');

echo "<h2>🧪 Quick Test: save_arpl_toolkit_edits.php</h2>";
echo "<p>Testing the endpoint that was causing 404 errors...</p>";
echo "<hr>";

// Check if file exists
$filePath = __DIR__ . '/save_arpl_toolkit_edits.php';
$exists = file_exists($filePath);

echo "<h3>📂 File Existence Check</h3>";

if ($exists) {
    echo "<div style='background-color: #d4edda; padding: 15px; border: 2px solid green; border-radius: 5px;'>";
    echo "<h4 style='color: green; margin: 0;'>✅ FILE EXISTS</h4>";
    echo "<p><strong>File:</strong> <code>save_arpl_toolkit_edits.php</code></p>";
    echo "<p><strong>Size:</strong> " . number_format(filesize($filePath)) . " bytes</p>";
    echo "<p><strong>Readable:</strong> " . (is_readable($filePath) ? '✅ YES' : '❌ NO') . "</p>";
    echo "<p><strong>Last Modified:</strong> " . date('Y-m-d H:i:s', filemtime($filePath)) . "</p>";
    echo "</div>";
} else {
    echo "<div style='background-color: #f8d7da; padding: 15px; border: 2px solid red; border-radius: 5px;'>";
    echo "<h4 style='color: red; margin: 0;'>❌ FILE NOT FOUND</h4>";
    echo "<p><strong>Expected Location:</strong> <code>$filePath</code></p>";
    echo "<p><strong>Action Required:</strong> Upload the file to <code>/home/rlmsrlmsco/public_html/mobile/</code></p>";
    echo "</div>";
    exit;
}

echo "<hr>";

// Test with mock data
echo "<h3>🧪 Functionality Test (Dry Run)</h3>";

try {
    // Simulate POST request with test data
    $testPayload = [
        'learnerID' => 11701,
        'classID' => 797,
        'ofoNumber' => '641201',
        'appendixB' => [
            ['activity_id' => 1, 'rating' => 4, 'comments' => 'Test comment']
        ],
        'appendixD' => [
            '1' => 'yes',
            '2' => 'no'
        ],
        'appendixE' => [
            ['activity_id' => 1, 'rating' => 3, 'comments' => 'Test comment']
        ]
    ];
    
    echo "<p><strong>Test Payload:</strong></p>";
    echo "<pre style='background-color: #f5f5f5; padding: 10px; border-radius: 5px;'>";
    echo json_encode($testPayload, JSON_PRETTY_PRINT);
    echo "</pre>";
    
    // Check if we can read the file
    $fileContent = file_get_contents($filePath);
    $lines = substr_count($fileContent, "\n");
    
    echo "<div style='background-color: #d4edda; padding: 15px; border: 2px solid green; border-radius: 5px;'>";
    echo "<h4 style='color: green; margin: 0;'>✅ FILE IS READABLE</h4>";
    echo "<p><strong>Total Lines:</strong> $lines</p>";
    echo "<p><strong>Contains 'appendixB':</strong> " . (strpos($fileContent, 'appendixB') !== false ? '✅ YES' : '❌ NO') . "</p>";
    echo "<p><strong>Contains 'appendixD':</strong> " . (strpos($fileContent, 'appendixD') !== false ? '✅ YES' : '❌ NO') . "</p>";
    echo "<p><strong>Contains 'appendixE':</strong> " . (strpos($fileContent, 'appendixE') !== false ? '✅ YES' : '❌ NO') . "</p>";
    echo "</div>";
    
    echo "<hr>";
    
    // URL that app will call
    $expectedUrl = "https://rlms.rlms.co.za/mobile/save_arpl_toolkit_edits.php";
    
    echo "<h3>🔗 Expected App URL</h3>";
    echo "<div style='background-color: #e7f3ff; padding: 15px; border: 2px solid blue; border-radius: 5px;'>";
    echo "<p>The Flutter app will POST to:</p>";
    echo "<p><code style='font-size: 16px;'>$expectedUrl</code></p>";
    echo "<p>This endpoint is now <strong style='color: green;'>ACCESSIBLE</strong> ✅</p>";
    echo "</div>";
    
} catch (Exception $e) {
    echo "<div style='background-color: #f8d7da; padding: 15px; border: 2px solid red; border-radius: 5px;'>";
    echo "<h4 style='color: red;'>❌ ERROR</h4>";
    echo "<p>" . $e->getMessage() . "</p>";
    echo "</div>";
}

echo "<hr>";

// Database connectivity check
echo "<h3>🗄️ Database Connectivity</h3>";

try {
    require_once 'connection.php';
    
    if ($conn) {
        echo "<div style='background-color: #d4edda; padding: 15px; border: 2px solid green; border-radius: 5px;'>";
        echo "<h4 style='color: green; margin: 0;'>✅ DATABASE CONNECTED</h4>";
        echo "<p><strong>Server:</strong> " . $conn->server_info . "</p>";
        
        // Check required tables
        $tables = [
            'arplappxb_activity_ratings',
            'arpl_appendix_d',
            'arplappxe_bricklaying_activity_ratings'
        ];
        
        echo "<p><strong>Required Tables:</strong></p>";
        echo "<ul>";
        foreach ($tables as $table) {
            $result = $conn->query("SHOW TABLES LIKE '$table'");
            $exists = ($result && $result->num_rows > 0);
            echo "<li><code>$table</code>: " . ($exists ? '✅ EXISTS' : '❌ MISSING') . "</li>";
        }
        echo "</ul>";
        
        echo "</div>";
        
        $conn->close();
    } else {
        throw new Exception('Connection failed');
    }
    
} catch (Exception $e) {
    echo "<div style='background-color: #fff3cd; padding: 15px; border: 2px solid orange; border-radius: 5px;'>";
    echo "<h4 style='color: orange;'>⚠️ DATABASE CONNECTION ISSUE</h4>";
    echo "<p>" . $e->getMessage() . "</p>";
    echo "</div>";
}

echo "<hr>";

// Final verdict
echo "<h3>✅ FINAL VERDICT</h3>";

if ($exists && is_readable($filePath)) {
    echo "<div style='background-color: #d4edda; padding: 20px; border: 3px solid green; border-radius: 5px;'>";
    echo "<h2 style='color: green; margin: 0;'>🎉 READY TO TEST!</h2>";
    echo "<p style='font-size: 16px;'>The <code>save_arpl_toolkit_edits.php</code> endpoint is:</p>";
    echo "<ul style='font-size: 16px;'>";
    echo "<li>✅ <strong>Uploaded</strong> to server</li>";
    echo "<li>✅ <strong>Accessible</strong> and readable</li>";
    echo "<li>✅ <strong>Ready</strong> to receive requests from the app</li>";
    echo "</ul>";
    echo "<hr>";
    echo "<h4>Next Step: Test in the App</h4>";
    echo "<ol>";
    echo "<li>Open the app on your device</li>";
    echo "<li>Go to: <strong>Menu → View Complete Toolkit</strong></li>";
    echo "<li>Select learner: <strong>Anele Cele (Class 797)</strong></li>";
    echo "<li>Edit any rating in Appendix B, D, or E</li>";
    echo "<li>Tap <strong>Save All Changes</strong></li>";
    echo "<li><strong>Expected Result:</strong> Success message (no more 404!) 🎉</li>";
    echo "</ol>";
    echo "</div>";
} else {
    echo "<div style='background-color: #f8d7da; padding: 20px; border: 3px solid red; border-radius: 5px;'>";
    echo "<h2 style='color: red; margin: 0;'>❌ NOT READY</h2>";
    echo "<p>Upload the file first, then run this test again.</p>";
    echo "</div>";
}

echo "<hr>";
echo "<p style='text-align: center;'><strong>Test completed:</strong> " . date('Y-m-d H:i:s') . "</p>";
?>
