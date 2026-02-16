<?php
// Script to replace the problematic save_marks.php with the fixed version
header('Content-Type: text/plain; charset=UTF-8');

echo "=== REPLACING SAVE_MARKS.PHP WITH FIXED VERSION ===\n\n";

// Check if files exist
if (!file_exists('save_marks.php')) {
    echo "❌ save_marks.php not found\n";
    exit;
}

if (!file_exists('save_marks_fixed.php')) {
    echo "❌ save_marks_fixed.php not found\n";
    exit;
}

// Create backup of original
$backupName = 'save_marks_backup_' . date('Y-m-d_H-i-s') . '.php';
if (copy('save_marks.php', $backupName)) {
    echo "✅ Created backup: $backupName\n";
} else {
    echo "❌ Failed to create backup\n";
    exit;
}

// Replace with fixed version
if (copy('save_marks_fixed.php', 'save_marks.php')) {
    echo "✅ Replaced save_marks.php with fixed version\n";
} else {
    echo "❌ Failed to replace save_marks.php\n";
    exit;
}

echo "\n=== REPLACEMENT COMPLETE ===\n";
echo "✅ save_marks.php has been replaced with the fixed version\n";
echo "✅ Original backed up as: $backupName\n";
echo "✅ The 500 error should now be resolved\n\n";

echo "=== KEY IMPROVEMENTS IN FIXED VERSION ===\n";
echo "1. Removed problematic assessments table query\n";
echo "2. Simplified type determination logic\n";
echo "3. Better error handling\n";
echo "4. Correct parameter types for database\n";
echo "5. Robust fallback mechanisms\n\n";

echo "=== TEST THE FIX ===\n";
echo "Try saving marks in your Flutter app now.\n";
echo "The 500 error should be resolved!\n";

echo "\n=== IF ISSUES PERSIST ===\n";
echo "1. Check your web server error logs\n";
echo "2. Test with save_marks_simple.php first\n";
echo "3. Verify database connection and table structure\n";
echo "4. Restore backup if needed: cp $backupName save_marks.php\n";
?>