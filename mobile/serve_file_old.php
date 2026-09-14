<?php
ini_set('display_errors', 0);
ini_set('log_errors', 1);
error_reporting(0);

require_once __DIR__ . '/connection.php';

$allowedOrigins = [
    'https://rlms.rlms.co.za',
    'http://localhost',
];
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (in_array($origin, $allowedOrigins, true)) {
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Vary: Origin');
} else {
    header('Access-Control-Allow-Origin: *');
}
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: private, no-store, no-cache, must-revalidate');
header('Pragma: no-cache');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    header('Content-Type: application/json');
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

function safeResolvePath(string $relativePath)
{
    $allowedBase = realpath(__DIR__);
    if ($allowedBase === false) return false;

    $relativePath = str_replace("\0", '', $relativePath);
    $relativePath = ltrim($relativePath, '/\\');

    $real = realpath($allowedBase . DIRECTORY_SEPARATOR . $relativePath);
    if ($real === false) {
        $real = realpath($allowedBase . DIRECTORY_SEPARATOR . '../' . $relativePath);
    }
    
    if ($real === false) {
        return false;
    }

    return $real;
}

$fileMeta = null;

if (isset($_GET['poe_id'])) {
    $poeId = filter_var($_GET['poe_id'], FILTER_VALIDATE_INT);
    if ($poeId && $poeId > 0) {
        $stmt = $conn->prepare("SELECT poe_id, learner_id, file_path FROM poe WHERE poe_id = ? LIMIT 1");
        if ($stmt) {
            $stmt->bind_param('i', $poeId);
            $stmt->execute();
            $result = $stmt->get_result();
            if ($result && $row = $result->fetch_assoc()) {
                $fileMeta = [
                    'learner_id' => (int)($row['learner_id'] ?? 0),
                    'relative_path' => $row['file_path'],
                ];
            }
            $stmt->close();
        }
    }
}

if (!$fileMeta && isset($_GET['file'])) {
    $fileMeta = [
        'learner_id' => isset($_GET['learner_id']) ? (int)$_GET['learner_id'] : 0,
        'relative_path' => (string)$_GET['file'],
    ];
}

if (!$fileMeta) {
    header('Content-Type: application/json');
    http_response_code(400);
    echo json_encode(['error' => 'Missing poe_id or file']);
    exit;
}

$file = safeResolvePath((string)$fileMeta['relative_path']);
if ($file === false || !is_file($file) || !is_readable($file)) {
    header('Content-Type: application/json');
    http_response_code(404);
    echo json_encode(['error' => 'File not found']);
    exit;
}

$allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
$ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
if (!in_array($ext, $allowedExtensions, true)) {
    header('Content-Type: application/json');
    http_response_code(403);
    echo json_encode(['error' => 'File type not allowed']);
    exit;
}

$mimeTypes = [
    'pdf' => 'application/pdf',
    'jpg' => 'image/jpeg',
    'jpeg' => 'image/jpeg',
    'png' => 'image/png',
];

header('Content-Type: ' . $mimeTypes[$ext]);
header('Content-Length: ' . filesize($file));
header('Content-Disposition: inline; filename="' . addslashes(basename($file)) . '"');
header('X-Content-Type-Options: nosniff');

$fp = fopen($file, 'rb');
if ($fp === false) {
    header('Content-Type: application/json');
    http_response_code(500);
    echo json_encode(['error' => 'Unable to open file']);
    exit;
}
fpassthru($fp);
fclose($fp);
exit;
