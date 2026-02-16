<?php
header('Content-Type: text/plain; charset=utf-8');
include('connection.php');

echo "=== QUICK IMAGE CHECK ===\n\n";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die("❌ Connection failed: " . $conn->connect_error . "\n");
}

// 1. Check upload directory
echo "1. Upload Directory:\n";
$dir = 'uploads/pothole_evidence/';
if (file_exists($dir)) {
    $files = array_diff(scandir($dir), ['.', '..']);
    echo "   ✓ Directory exists\n";
    echo "   ✓ Files in directory: " . count($files) . "\n";
    if (count($files) > 0) {
        echo "   Latest files:\n";
        $latest = array_slice($files, -3);
        foreach ($latest as $file) {
            $size = filesize($dir . $file);
            echo "     - $file (" . round($size/1024, 2) . " KB)\n";
        }
    }
} else {
    echo "   ❌ Directory does not exist!\n";
}
echo "\n";

// 2. Check database entries
echo "2. Database Entries:\n";
$result = $conn->query("SELECT COUNT(*) as count FROM poe WHERE type='LogBook' AND exercise LIKE '%Pothole%'");
$row = $result->fetch_assoc();
$count = $row['count'];

if ($count > 0) {
    echo "   ✓ Found $count pothole image entries\n";
    
    // Show latest 3
    $latest = $conn->query("SELECT learnerID, exercise, filePath FROM poe WHERE type='LogBook' AND exercise LIKE '%Pothole%' ORDER BY exercise DESC LIMIT 3");
    echo "   Latest entries:\n";
    while ($entry = $latest->fetch_assoc()) {
        $fileExists = file_exists($entry['filePath']) ? '✓' : '❌';
        echo "     $fileExists Learner: {$entry['learnerID']}, File: {$entry['filePath']}\n";
    }
} else {
    echo "   ❌ No pothole image entries in database!\n";
    echo "   This is the problem - images are not being saved to database.\n";
}
echo "\n";

// 3. Compare files vs database
echo "3. Files vs Database:\n";
if (file_exists($dir)) {
    $filesInDir = count(array_diff(scandir($dir), ['.', '..']));
    $filesInDB = $count;
    
    echo "   Files in directory: $filesInDir\n";
    echo "   Entries in database: $filesInDB\n";
    
    if ($filesInDir > $filesInDB) {
        echo "   ⚠️  WARNING: More files than database entries!\n";
        echo "   This means uploads are working but database inserts are failing.\n";
    } elseif ($filesInDB > $filesInDir) {
        echo "   ⚠️  WARNING: More database entries than files!\n";
        echo "   Some files may have been deleted.\n";
    } elseif ($filesInDir == 0 && $filesInDB == 0) {
        echo "   ❌ No files and no database entries.\n";
        echo "   Images have not been uploaded yet, or upload is completely failing.\n";
    } else {
        echo "   ✓ Files and database entries match!\n";
    }
}
echo "\n";

// 4. Check recent PHP errors
echo "4. Recent PHP Errors:\n";
$logFile = '/home/username/public_html/logs/php_error_log';
if (file_exists($logFile)) {
    $lines = file($logFile);
    $recent = array_slice($lines, -50);
    $uploadErrors = array_filter($recent, function($line) {
        return stripos($line, 'pothole') !== false || 
               stripos($line, 'upload_pothole') !== false ||
               stripos($line, 'FILES') !== false;
    });
    
    if (count($uploadErrors) > 0) {
        echo "   ⚠️  Found " . count($uploadErrors) . " upload-related errors:\n";
        foreach (array_slice($uploadErrors, -3) as $error) {
            echo "   " . trim($error) . "\n";
        }
    } else {
        echo "   ✓ No recent upload errors\n";
    }
} else {
    echo "   ⚠️  Error log not found\n";
}
echo "\n";

// 5. Recommendation
echo "=== RECOMMENDATION ===\n";
if ($count == 0 && (!file_exists($dir) || count(array_diff(scandir($dir), ['.', '..'])) == 0)) {
    echo "❌ No images uploaded yet.\n";
    echo "\nAction: Try uploading images from the app now.\n";
    echo "Then run this script again to verify.\n";
} elseif (file_exists($dir) && count(array_diff(scandir($dir), ['.', '..'])) > 0 && $count == 0) {
    echo "❌ Files exist but no database entries!\n";
    echo "\nAction: Check upload_pothole_evidence.php for database insert errors.\n";
    echo "Run: tail -f /home/username/public_html/logs/php_error_log\n";
    echo "Then try uploading again and watch for errors.\n";
} else {
    echo "✓ Everything looks good!\n";
    echo "\nIf images still don't appear in the app:\n";
    echo "1. Check get_pothole_images.php is working\n";
    echo "2. Verify Flutter is calling the correct API\n";
    echo "3. Check Flutter console for errors\n";
}

$conn->close();
?>
