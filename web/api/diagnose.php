<?php
// Diagnostic script to help troubleshoot path issues

header('Content-Type: application/json; charset=utf-8');
ini_set('display_errors', 0);

$diagnostics = [
    'current_file' => __FILE__,
    'current_dir' => __DIR__,
    'php_script_filename' => $_SERVER['SCRIPT_FILENAME'] ?? 'N/A',
    'php_script_name' => $_SERVER['SCRIPT_NAME'] ?? 'N/A',
    'request_uri' => $_SERVER['REQUEST_URI'] ?? 'N/A',
    'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? 'N/A',
    'realpath_current' => realpath(__DIR__),
];

// Check for connection file at various paths
$paths_to_check = [
    '__DIR__ . /../../connection.php' => __DIR__ . '/../../connection.php',
    '__DIR__ . /../../../connection.php' => __DIR__ . '/../../../connection.php',
    '__DIR__ . /../../../../connection.php' => __DIR__ . '/../../../../connection.php',
    'realpath ../connection.php' => realpath(__DIR__ . '/../connection.php'),
    'realpath ../../connection.php' => realpath(__DIR__ . '/../../connection.php'),
    'realpath ../../../connection.php' => realpath(__DIR__ . '/../../../connection.php'),
];

$file_checks = [];
foreach ($paths_to_check as $label => $path) {
    $file_checks[$label] = [
        'path' => $path,
        'exists' => file_exists($path),
        'is_file' => is_file($path),
        'is_readable' => is_readable($path),
    ];
}

$diagnostics['connection_file_checks'] = $file_checks;

// Try to find connection.php
$found_connection = false;
foreach ($paths_to_check as $path) {
    if (file_exists($path)) {
        $diagnostics['found_connection_at'] = $path;
        $found_connection = true;
        break;
    }
}

if (!$found_connection) {
    $diagnostics['found_connection_at'] = 'NOT FOUND';
}

http_response_code(200);
echo json_encode($diagnostics, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
?>
