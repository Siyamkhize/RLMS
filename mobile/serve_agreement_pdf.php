<?php
/**
 * Serve Agreement PDF for iframe viewing
 * Standalone file that only outputs the PDF - No authentication required (public portal)
 */

// Set timeout to 30 seconds
set_time_limit(30);
ini_set('max_execution_time', 30);

// Start output buffering to prevent accidental output before headers
ob_start();

// Mobile directory - connection.php is in parent directory
require_once '../connection.php';

// Get parameters
$agreement_id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
$id_number_verify = trim($_GET['verify'] ?? '');

if (!$agreement_id || !$id_number_verify) {
    ob_end_clean();
    http_response_code(400);
    die('Invalid parameters');
}

// Query the database
// NOTE: learner_id in stored_agreement_pdfs contains the ID Number
$stmt = $conn->prepare("
    SELECT 
        pdf_path,
        pdf_filename,
        learner_id,
        learner_name
    FROM stored_agreement_pdfs
    WHERE id = ? AND learner_id = ?
");

if (!$stmt) {
    ob_end_clean();
    http_response_code(500);
    die('Database error');
}

$stmt->bind_param('is', $agreement_id, $id_number_verify);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    ob_end_clean();
    http_response_code(404);
    die('Agreement not found or access denied');
}

$pdf = $result->fetch_assoc();
$file_path = $pdf['pdf_path'];
$filename = $pdf['pdf_filename'];
$stmt->close();
$conn->close();

// Try different path variations to find the file
$file_found = false;
$actual_file_path = '';

$path_variations = [
    $file_path,
    str_replace('\\', '/', $file_path),
    str_replace('/', '\\', $file_path),
    // Try with different base paths
    __DIR__ . '/' . $file_path,
    __DIR__ . '/' . str_replace('\\', '/', $file_path),
    // Try just the filename with common directories
    'mobile/agreement/pdfs/' . basename($file_path),
    __DIR__ . '/mobile/agreement/pdfs/' . basename($file_path),
    'mobile/agreements/pdfs/' . basename($file_path),
    __DIR__ . '/mobile/agreements/pdfs/' . basename($file_path),
    'agreements/pdfs/' . basename($file_path),
    __DIR__ . '/agreements/pdfs/' . basename($file_path),
];

// Remove duplicates
$path_variations = array_unique($path_variations);

foreach ($path_variations as $path) {
    if (file_exists($path)) {
        $file_found = true;
        $actual_file_path = $path;
        break;
    }
}

if (!$file_found) {
    ob_end_clean();
    http_response_code(404);
    header('Content-Type: text/plain');
    echo "PDF file not found\n";
    echo "Agreement ID: $agreement_id\n";
    echo "Stored path: $file_path\n";
    exit;
}

// Clean output buffer before sending PDF
ob_end_clean();

// Set headers for PDF viewing
header('Content-Type: application/pdf');
header('Content-Disposition: inline; filename="' . basename($filename) . '"');
header('Content-Length: ' . filesize($actual_file_path));
header('Cache-Control: public, max-age=3600');
header('Pragma: public');
header('Accept-Ranges: bytes');
header('X-Agreement-Info: ' . json_encode([
    'agreement_id' => $agreement_id,
    'learner_name' => $pdf['learner_name'],
    'filename' => basename($filename)
]));

// Output the PDF file
readfile($actual_file_path);
exit;
?>
