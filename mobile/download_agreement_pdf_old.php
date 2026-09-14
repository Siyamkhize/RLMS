<?php
/**
 * Download Agreement PDF
 */
set_time_limit(15);
ob_start();

require_once '../connection.php';

$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
$verify = trim($_GET['verify'] ?? '');

if (!$id || !$verify) {
    ob_end_clean();
    http_response_code(400);
    die('Bad request');
}

// Quick query
$stmt = $conn->prepare("SELECT pdf_path, pdf_filename FROM stored_agreement_pdfs WHERE id = ? AND learner_id = ? LIMIT 1");
$stmt->bind_param('is', $id, $verify);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    $file = $row['pdf_path'];
    $filename = $row['pdf_filename'];
    
    // Try only most likely paths
    $paths = [
        $file,
        __DIR__ . '/' . $file,
        dirname(__DIR__) . '/' . $file
    ];
    
    foreach ($paths as $p) {
        if (@file_exists($p)) {
            ob_end_clean();
            header('Content-Type: application/pdf');
            header('Content-Disposition: attachment; filename="' . basename($filename) . '"');
            header('Content-Length: ' . filesize($p));
            header('Cache-Control: no-cache, must-revalidate');
            readfile($p);
            exit;
        }
    }
    
    ob_end_clean();
    http_response_code(404);
    die('File not found: ' . basename($file));
}

ob_end_clean();
http_response_code(404);
die('Agreement not found');
?>
