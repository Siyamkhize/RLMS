<?php
/**
 * Simple PDF Server - Optimized for speed
 */
set_time_limit(15);
ob_start();

require_once '../connection.php';

$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
$verify = trim($_GET['verify'] ?? '');

// Log for debugging
error_log("Serve Agreement PDF - ID: $id, Verify: $verify");

if (!$id || empty($verify)) {
    ob_end_clean();
    http_response_code(400);
    die('Bad request - missing parameters');
}

// Quick query - id is the agreement record ID, learner_id stores the ID Number
$stmt = $conn->prepare("SELECT pdf_path FROM stored_agreement_pdfs WHERE id = ? AND learner_id = ? LIMIT 1");
$stmt->bind_param('is', $id, $verify);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    $file = $row['pdf_path'];
    
    // Try multiple path resolutions
    $paths = [
        $file,
        __DIR__ . '/' . $file,
        dirname(__DIR__) . '/' . $file,
        $_SERVER['DOCUMENT_ROOT'] . '/' . $file,
        str_replace('mobile/', '', $file)
    ];
    
    foreach ($paths as $p) {
        if (@file_exists($p) && is_readable($p)) {
            ob_end_clean();
            header('Content-Type: application/pdf');
            header('Content-Length: ' . filesize($p));
            header('Cache-Control: public, max-age=3600');
            header('Accept-Ranges: bytes');
            readfile($p);
            exit;
        }
    }
    
    ob_end_clean();
    http_response_code(404);
    error_log("PDF not found. Checked paths for: $file");
    die('File not found on server');
}

ob_end_clean();
http_response_code(404);
die('Agreement not found');
?>
