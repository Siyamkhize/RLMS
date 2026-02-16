<?php
// get_facilitator_profile.php

// Include database connection
include 'connection.php';

// Enable error reporting for debugging (disable in production)
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Set headers for CORS and JSON response
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Create database connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    echo json_encode(["success" => false, "message" => "Connection failed: " . $conn->connect_error]);
    exit();
}

// Check if classID is provided
if (!isset($_GET['classID']) || empty($_GET['classID'])) {
    echo json_encode(["success" => false, "message" => "classID parameter is required"]);
    exit();
}

$classID = $conn->real_escape_string($_GET['classID']);

// Base URL for image paths (must match Flutter's Config.baseUrl)
$baseUrl = 'https://rlms.rlms.co.za/mobile';

// Get facilitator profile data
$stmt = $conn->prepare("
    SELECT f.facilitator_id, f.firstName, f.lastName, f.role, f.email, f.classID,
           f.phoneNumber, f.IDNumber, f.assessorNo, f.assessorExpiryDate, f.workNumber, f.serial_number, 
           f.f_signature, f.f_profile, c.className
    FROM facilitator f
    LEFT JOIN class c ON f.classID = c.classID
    WHERE f.classID = ?
");
$stmt->bind_param("s", $classID);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $facilitator = $result->fetch_assoc();
    
    // Debugging: Log raw database values
    $debug = [
        'raw_f_profile' => $facilitator['f_profile'],
        'raw_f_signature' => $facilitator['f_signature'],
        'script_dir' => __DIR__
    ];
    
    // Handle profile image
    $profileExists = false;
    $profileUrl = null;
    if (!empty($facilitator['f_profile'])) {
        $profilePath = $facilitator['f_profile']; // e.g., facilitatorProfiles/1751100967_3_profile.jpg
        $fullProfilePath = __DIR__ . '/' . $profilePath; // e.g., /home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/facilitatorProfiles/1751100967_3_profile.jpg
        $debug['full_profile_path'] = $fullProfilePath;
        $debug['profile_file_exists'] = file_exists($fullProfilePath) ? 'yes' : 'no';
        if (file_exists($fullProfilePath)) {
            $profileExists = true;
            $profileUrl = $baseUrl . '/' . $profilePath; // e.g., https://rlms.rlms.co.za/mobile/facilitatorProfiles/1751100967_3_profile.jpg
        }
    }
    
    // Handle signature image
    $signatureExists = false;
    $signatureUrl = null;
    if (!empty($facilitator['f_signature'])) {
        $signaturePath = $facilitator['f_signature']; // e.g., facilitatorSignatures/1751100972_3_signature.png
        $fullSignaturePath = __DIR__ . '/' . $signaturePath; // e.g., /home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/facilitatorSignatures/1751100972_3_signature.png
        $debug['full_signature_path'] = $fullSignaturePath;
        $debug['signature_file_exists'] = file_exists($fullSignaturePath) ? 'yes' : 'no';
        if (file_exists($fullSignaturePath)) {
            $signatureExists = true;
            $signatureUrl = $baseUrl . '/' . $signaturePath; // e.g., https://rlms.rlms.co.za/mobile/facilitatorSignatures/1751100972_3_signature.png
        }
    }
    
    echo json_encode([
        "success" => true,
        "message" => "Facilitator data retrieved successfully",
        "data" => [
            "facilitator_id" => $facilitator['facilitator_id'],
            "firstName" => $facilitator['firstName'],
            "lastName" => $facilitator['lastName'],
            "fullName" => trim(($facilitator['firstName'] ?? '') . ' ' . ($facilitator['lastName'] ?? '')),
            "email" => $facilitator['email'],
            "phoneNumber" => $facilitator['phoneNumber'],
            "IDNumber" => $facilitator['IDNumber'],
            "role" => $facilitator['role'] ?? '',
            "className" => $facilitator['className'] ?? '',
            "assessorNo" => $facilitator['assessorNo'],
            "assessorExpiryDate" => $facilitator['assessorExpiryDate'] ?? '',
            "workNumber" => $facilitator['workNumber'] ?? '',
            "serial_number" => $facilitator['serial_number'] ?? '',
            "classID" => $classID
        ],
        "profile_exists" => $profileExists,
        "profile_url" => $profileUrl,
        "signature_exists" => $signatureExists,
        "signature_url" => $signatureUrl,
        "debug" => $debug // Include debug info in response
    ]);
} else {
    echo json_encode([
        "success" => false,
        "message" => "No facilitator found with the provided classID",
        "profile_exists" => false,
        "profile_url" => null,
        "signature_exists" => false,
        "signature_url" => null,
        "debug" => ['classID' => $classID]
    ]);
}

$stmt->close();
$conn->close();
?>