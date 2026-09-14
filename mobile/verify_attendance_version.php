<?php
// Verify which version of get_attendance.php is running on the server
header('Content-Type: text/plain');

echo "=== ATTENDANCE FILE VERSION CHECK ===\n\n";

// Check if file exists
if (file_exists('get_attendance.php')) {
    echo "✓ File exists: get_attendance.php\n\n";
    
    // Read the file content
    $content = file_get_contents('get_attendance.php');
    
    // Check for the NEW version (with clock_in_time and clock_out_time)
    if (strpos($content, 'clock_in_time IS NOT NULL') !== false && 
        strpos($content, 'clock_out_time IS NOT NULL') !== false) {
        echo "✓ NEW VERSION DETECTED (Fixed version)\n";
        echo "  - Uses: clock_in_time and clock_out_time\n";
        echo "  - Only counts complete clock in/out pairs\n\n";
    } 
    // Check for the OLD version (without the fix)
    else if (strpos($content, 'GROUP BY DATE(clock_date)') !== false) {
        echo "✗ OLD VERSION DETECTED (Needs update)\n";
        echo "  - Missing validation for complete clock in/out\n";
        echo "  - Will count incomplete records\n\n";
    } else {
        echo "? UNKNOWN VERSION\n\n";
    }
    
    // Show the actual query being used
    echo "=== CURRENT CLOCKING QUERY ===\n";
    preg_match('/clockingQuery = "(SELECT.*?FROM learner_clocking.*?)";/s', $content, $matches);
    if (isset($matches[1])) {
        echo $matches[1] . "\n\n";
    }
    
    // File modification time
    $modTime = filemtime('get_attendance.php');
    echo "Last modified: " . date('Y-m-d H:i:s', $modTime) . "\n";
    
} else {
    echo "✗ File NOT found: get_attendance.php\n";
}

echo "\n=== CACHE CLEARING INSTRUCTIONS ===\n";
echo "If OLD version is detected:\n";
echo "1. Re-upload get_attendance.php\n";
echo "2. Clear PHP OPcache (see below)\n";
echo "3. Clear browser cache (Ctrl+Shift+R)\n\n";

echo "To clear PHP OPcache, run:\n";
echo "<?php opcache_reset(); ?>\n";
?>
