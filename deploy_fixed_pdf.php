<?php
$source = 'c:\\projects\\rlmss\\web\\arpl_pdf.php';
$dest = 'C:\\xampp\\htdocs\\web\\web\\web\\arpl_pdf.php';

// First, backup existing file
if (file_exists($dest)) {
    copy($dest, $dest . '.backup');
    echo "✓ Backed up existing file\n";
}

// Copy the file
if (copy($source, $dest)) {
    echo "✓ Deployed fixed arpl_pdf.php\n";
    echo "  Source: $source\n";
    echo "  Dest: $dest\n";
    echo "  Size: " . filesize($dest) . " bytes\n";
} else {
    echo "✗ Failed to copy: " . error_get_last()['message'] . "\n";
}
?>
