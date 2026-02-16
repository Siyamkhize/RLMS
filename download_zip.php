<?php
/**
 * Dedicated ZIP file download handler
 * Serves ZIP files from temp_reports directory
 */

// Clean all output buffers
while (ob_get_level()) {
    ob_end_clean();
}

// Disable output buffering
ini_set('output_buffering', 'off');
ini_set('zlib.output_compression', 'Off');

// Get filename from query parameter
$filename = isset($_GET['file']) ? basename($_GET['file']) : '';

if (empty($filename)) {
    http_response_code(400);
    die('Error: No file specified');
}

// Construct file path
$filePath = __DIR__ . '/temp_reports/' . $filename;

// Log the request
error_log("ZIP Download Request: $filename");
error_log("File path: $filePath");
error_log("File exists: " . (file_exists($filePath) ? 'YES' : 'NO'));

// Check if file exists
if (!file_exists($filePath)) {
    http_response_code(404);
    error_log("ZIP file not found: $filePath");
    die('Error: File not found');
}

// Verify it's a ZIP file
if (pathinfo($filename, PATHINFO_EXTENSION) !== 'zip') {
    http_response_code(403);
    error_log("Invalid file type requested: $filename");
    die('Error: Invalid file type');
}

// Get file size
$fileSize = filesize($filePath);
error_log("ZIP file size: $fileSize bytes");

// Set headers for ZIP download
header('Content-Type: application/zip');
header('Content-Disposition: attachment; filename="' . $filename . '"');
header('Content-Length: ' . $fileSize);
header('Content-Transfer-Encoding: binary');
header('Cache-Control: no-cache, no-store, must-revalidate');
header('Pragma: no-cache');
header('Expires: 0');

// Disable Apache compression if available
if (function_exists('apache_setenv')) {
    @apache_setenv('no-gzip', '1');
}

// Set execution time for large files
set_time_limit(300); // 5 minutes

// Output file in chunks to handle large files
$handle = fopen($filePath, 'rb');
if ($handle === false) {
    http_response_code(500);
    error_log("Failed to open ZIP file: $filePath");
    die('Error: Failed to open file');
}

// Read and output file in 8KB chunks
while (!feof($handle)) {
    $buffer = fread($handle, 8192);
    echo $buffer;
    flush();
}

fclose($handle);

error_log("ZIP file served successfully: $filename");

// Optional: Delete file after download (uncomment if desired)
// unlink($filePath);

exit();
?>
