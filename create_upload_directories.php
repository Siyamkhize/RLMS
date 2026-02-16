<?php
/**
 * Create necessary upload directories
 */

$directories = [
    'uploads',
    'uploads/temp',
    'uploads/learner_documents'
];

foreach ($directories as $dir) {
    if (!is_dir($dir)) {
        if (mkdir($dir, 0755, true)) {
            echo "✓ Created directory: $dir\n";
        } else {
            echo "✗ Failed to create directory: $dir\n";
        }
    } else {
        echo "✓ Directory already exists: $dir\n";
    }
}

echo "\nUpload directories setup complete!\n";
?>