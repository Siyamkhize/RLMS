<?php
http_response_code(403);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
echo json_encode([
    'error' => 'Access denied'
]);
exit;
