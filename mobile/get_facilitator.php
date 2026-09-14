<?php
// get_facilitator.php

// Include database connection
include 'connection.php';

// Disable error reporting in production
error_reporting(0);
ini_set('display_errors', 0);

// Set headers for CORS and JSON response
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: ' . (getenv('ALLOWED_ORIGINS') ?: '*')); // Restrict in production
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Create database connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database connection failed'
    ]);
    exit();
}

// Check if classID is provided and valid
if (!isset($_GET['classID']) || empty($_GET['classID']) || !is_numeric($_GET['classID'])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Valid classID parameter is required'
    ]);
    exit();
}

$classID = $conn->real_escape_string($_GET['classID']);
$baseUrl = getenv('BASE_URL') ?: 'https://rlms.rlms.co.za/mobile'; // Use environment variable

// Get facilitator profile data
$stmt = $conn->prepare("
    SELECT f.facilitator_id, f.firstName, f.lastName, f.role, f.email, f.classID,
           f.phoneNumber, f.f_IDNumber, f.assessorNo, f.workNumber, f.serial_number,
           f.f_signature, f.f_profile, c.className
    FROM facilitator f
    LEFT JOIN class c ON f.classID = c.classID
    WHERE f.classID = ?
");
$stmt->bind_param('i', $classID); // Use 'i' for integer if classID is numeric

if (!$stmt->execute()) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Query execution failed'
    ]);
    $stmt->close();
    $conn->close();
    exit();
}

$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $facilitator = $result->fetch_assoc();

    // Prepare image URLs
    $profileUrl = null;
    if ($facilitator['f_profile'] && file_exists(__DIR__ . '/' . $facilitator['f_profile'])) {
        $profileUrl = $baseUrl . '/' . $facilitator['f_profile'];
    }

    $signatureUrl = null;
    if ($facilitator['f_signature'] && file_exists(__DIR__ . '/' . $facilitator['f_signature'])) {
        $signatureUrl = $baseUrl . '/' . $facilitator['f_signature'];
    }

    // Prepare response data (exclude password)
    $responseData = [
        'facilitator_id' => $facilitator['facilitator_id'],
        'firstName' => $facilitator['firstName'] ?? '',
        'lastName' => $facilitator['lastName'] ?? '',
        'fullName' => trim(($facilitator['firstName'] ?? '') . ' ' . ($facilitator['lastName'] ?? '')),
        'email' => $facilitator['email'] ?? '',
        'phoneNumber' => $facilitator['phoneNumber'] ?? '',
        'f_IDNumber' => $facilitator['f_IDNumber'] ?? '',
        'assessorNo' => $facilitator['assessorNo'] ?? '',
        'classID' => $facilitator['classID'],
        'role' => $facilitator['role'] ?? '',
        'className' => $facilitator['className'] ?? '',
        'f_profile' => $profileUrl,
        'f_signature' => $signatureUrl
    ];

    echo json_encode([
        'success' => true,
        'message' => 'Facilitator data retrieved successfully',
        'data' => $responseData
    ], JSON_UNESCAPED_SLASHES);
} else {
    http_response_code(404);
    echo json_encode([
        'success' => false,
        'message' => 'No facilitator found with the provided classID',
        'data' => null
    ], JSON_UNESCAPED_SLASHES);
}

$stmt->close();
$conn->close();
?>