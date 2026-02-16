<?php
/**
 * Direct ZIP file download - bypasses bulk_down_register.php
 */

// Clear any output buffers
while (ob_get_level()) {
    ob_end_clean();
}

$filename = isset($_GET['file']) ? basename($_GET['file']) : '';
$filePath = __DIR__ . '/temp_reports/' . $filename;

if (empty($filename)) {
    http_response_code(400);
    die('No file specified');
}

if (!file_exists($filePath)) {
    http_response_code(404);
    die('File not found: ' . $filename);
}

$fileSize = filesize($filePath);

// Set headers for ZIP download
header('Content-Type: application/zip');
header('Content-Disposition: attachment; filename="' . $filename . '"');
header('Content-Length: ' . $fileSize);
header('Cache-Control: no-cache, no-store, must-revalidate');
header('Pragma: no-cache');
header('Expires: 0');

// Read file in chunks for large files
if ($fileSize > 10 * 1024 * 1024) { // If larger than 10MB
    $handle = fopen($filePath, 'rb');
    while (!feof($handle)) {
        echo fread($handle, 8192);
        flush();
    }
    fclose($handle);
} else {
    readfile($filePath);
}

exit();
