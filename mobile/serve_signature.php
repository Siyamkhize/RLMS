<?php
$file = isset($_GET['file']) ? basename($_GET['file']) : '';
if (empty($file)) {
    header('HTTP/1.1 400 Bad Request');
    die('No file specified');
}

$filepath = __DIR__ . '/signatures/' . $file;
if (!file_exists($filepath)) {
    header('HTTP/1.1 404 Not Found');
    die('File not found');
}

if (!preg_match('/\.(png|jpg|jpeg|gif)$/i', $file)) {
    header('HTTP/1.1 403 Forbidden');
    die('Invalid file type');
}

header('Content-Type: image/png');
header('Content-Length: ' . filesize($filepath));
header('Cache-Control: public, max-age=86400');
readfile($filepath);