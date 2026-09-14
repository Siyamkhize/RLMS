<?php
/**
 * Download Agreement PDF
 */
set_time_limit(15);
ob_start();

require_once '../connection.php';

// Get and validate parameters
$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
$verify = trim($_GET['verify'] ?? '');

// Log for debugging
error_log("Download Agreement PDF - ID: $id, Verify: $verify");

if (!$id || empty($verify)) {
    ob_end_clean();
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'error' => 'Learner ID is required',
        'debug' => "ID: $id, Verify: " . (empty($verify) ? 'empty' : 'present')
    ]);
    exit;
}

// Query to get PDF - id is the agreement record ID, learner_id stores the ID Number
$stmt = $conn->prepare("SELECT pdf_path, pdf_filename FROM stored_agreement_pdfs WHERE id = ? AND learner_id = ? LIMIT 1");
$stmt->bind_param('is', $id, $verify);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    $file = $row['pdf_path'];
    $filename = $row['pdf_filename'];
    
    // Try multiple path resolutions
    // The path in DB is relative (e.g., mobile/agreement/pdfs/...)
    // We need to find the actual file location
    $paths = [
        $file,                                    // Relative from current working directory
        __DIR__ . '/' . $file,                    // From this script's directory
        dirname(__DIR__) . '/' . $file,           // From parent directory (web root)
        $_SERVER['DOCUMENT_ROOT'] . '/' . $file,  // From document root
        // Handle case where path already starts with 'mobile/' and we're in mobile dir
        str_replace('mobile/', '', $file)
    ];
    
    foreach ($paths as $p) {
        if (@file_exists($p) && is_readable($p)) {
            ob_end_clean();
            header('Content-Type: application/pdf');
            header('Content-Disposition: attachment; filename="' . basename($filename) . '"');
            header('Content-Length: ' . filesize($p));
            header('Cache-Control: no-cache, must-revalidate');
            header('Pragma: public');
            readfile($p);
            exit;
        }
    }
    
    // File not found - return JSON error with debug info
    ob_end_clean();
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'error' => 'PDF file not found on server',
        'debug' => [
            'stored_path' => $file,
            'checked_paths' => array_slice($paths, 0, 4), // Don't expose all internal paths
            'filename' => $filename
        ]
    ]);
    exit;
}

ob_end_clean();
header('Content-Type: application/json');
echo json_encode([
    'success' => false,
    'error' => 'Agreement not found or access denied',
    'debug' => [
        'id' => $id,
        'verify_length' => strlen($verify)
    ]
]);
exit;
?>
