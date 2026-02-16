<?php
header('Content-Type: text/plain');

echo "=== CREATE UPLOAD DIRECTORY ===\n\n";

$uploadDir = 'uploads/pothole_evidence/';

echo "Target directory: $uploadDir\n\n";

// Check current status
if (file_exists($uploadDir)) {
    echo "✓ Directory already exists\n";
    echo "  Writable: " . (is_writable($uploadDir) ? 'YES' : 'NO') . "\n";
    
    if (!is_writable($uploadDir)) {
        echo "\nAttempting to fix permissions...\n";
        if (chmod($uploadDir, 0755)) {
            echo "✓ Permissions updated to 0755\n";
        } else {
            echo "✗ Failed to update permissions\n";
            echo "  Run manually: chmod 755 $uploadDir\n";
        }
    }
} else {
    echo "Directory does not exist. Creating...\n";
    
    // Try to create directory
    if (mkdir($uploadDir, 0755, true)) {
        echo "✓ Directory created successfully\n";
        echo "  Path: $uploadDir\n";
        echo "  Permissions: 0755\n";
        echo "  Writable: " . (is_writable($uploadDir) ? 'YES' : 'NO') . "\n";
    } else {
        echo "✗ Failed to create directory\n";
        echo "\nPossible reasons:\n";
        echo "1. Parent directory 'uploads/' doesn't exist\n";
        echo "2. PHP doesn't have permission to create directories\n";
        echo "3. Safe mode or open_basedir restrictions\n";
        
        echo "\nManual fix:\n";
        echo "SSH into your server and run:\n";
        echo "  cd /home/username/public_html/mobile\n";
        echo "  mkdir -p $uploadDir\n";
        echo "  chmod 755 $uploadDir\n";
        
        // Try creating parent directory first
        echo "\nTrying to create parent directory...\n";
        if (!file_exists('uploads/')) {
            if (mkdir('uploads/', 0755, true)) {
                echo "✓ Created 'uploads/' directory\n";
                
                // Try again
                if (mkdir($uploadDir, 0755, true)) {
                    echo "✓ Now successfully created $uploadDir\n";
                } else {
                    echo "✗ Still failed to create $uploadDir\n";
                }
            } else {
                echo "✗ Failed to create 'uploads/' directory\n";
            }
        } else {
            echo "✓ Parent 'uploads/' directory exists\n";
        }
    }
}

// Final verification
echo "\n=== FINAL STATUS ===\n";
if (file_exists($uploadDir) && is_writable($uploadDir)) {
    echo "✓ SUCCESS! Directory is ready for uploads\n";
    echo "  Path: $uploadDir\n";
    echo "  Exists: YES\n";
    echo "  Writable: YES\n";
    
    // Test write
    $testFile = $uploadDir . 'test_' . time() . '.txt';
    if (file_put_contents($testFile, 'test')) {
        echo "  Write test: PASSED\n";
        unlink($testFile);
        echo "  Cleanup: DONE\n";
    } else {
        echo "  Write test: FAILED\n";
    }
    
    echo "\n✓ You can now upload images!\n";
} else {
    echo "✗ FAILED - Directory is not ready\n";
    
    if (!file_exists($uploadDir)) {
        echo "  Issue: Directory doesn't exist\n";
    } elseif (!is_writable($uploadDir)) {
        echo "  Issue: Directory is not writable\n";
    }
    
    echo "\nManual fix required:\n";
    echo "1. SSH into your server\n";
    echo "2. Run: cd /home/username/public_html/mobile\n";
    echo "3. Run: mkdir -p $uploadDir\n";
    echo "4. Run: chmod 755 $uploadDir\n";
    echo "5. Verify: ls -la uploads/\n";
}

echo "\n=== DONE ===\n";
?>
