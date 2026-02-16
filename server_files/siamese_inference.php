<?php
// siamese_inference.php
header('Content-Type: application/json');

// --- Configuration ---
$python_server_url = 'http://127.0.0.1:5001/verify';

// --- Get Input Data ---
$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid JSON input']);
    exit;
}

// --- Forward Request to Python/Flask Server ---
$ch = curl_init($python_server_url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($input));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_TIMEOUT, 30); // 30-second timeout

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

// --- Return Response ---
if ($response === false) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to connect to the model server.']);
} else {
    http_response_code($http_code);
    echo $response;
}
?> 