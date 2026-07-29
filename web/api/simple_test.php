<?php
// SIMPLE DIRECT TEST - No complexity, just output JSON

header('Content-Type: application/json; charset=utf-8');
ini_set('display_errors', 0);

// Test 1: Can we write JSON?
echo json_encode([
    'test' => 'simple',
    'status' => 'success',
    'message' => 'If you see this JSON, the API endpoint is working'
]);
?>
