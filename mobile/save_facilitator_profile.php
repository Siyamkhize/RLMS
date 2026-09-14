<?php
// save_facilitator_profile.php

// Include database connection
include 'connection.php';

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Set headers for CORS and JSON response
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle OPTIONS request for CORS preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Create database connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    echo json_encode(["success" => false, "message" => "Connection failed: " . $conn->connect_error]);
    exit();
}

// Directory to save profile images
$profileDir = "facilitatorProfiles/";

// Create directory if it doesn't exist
if (!is_dir($profileDir)) {
    mkdir($profileDir, 0777, true);
}

// Check if required data is provided
if (!isset($_POST['classID']) || !isset($_FILES['f_profile'])) {
    echo json_encode(["success" => false, "message" => "Missing classID or profile image file"]);
    exit();
}

$classID = $conn->real_escape_string($_POST['classID']);
$uploadedFile = $_FILES['f_profile'];

// Validate uploaded file
if ($uploadedFile['error'] !== UPLOAD_ERR_OK) {
    echo json_encode(["success" => false, "message" => "File upload error: " . $uploadedFile['error']]);
    exit();
}

// Validate image file
$allowedTypes = [
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp'
];

$imageInfo = getimagesize($uploadedFile['tmp_name']);
if ($imageInfo === false) {
    echo json_encode(["success" => false, "message" => "Invalid image format"]);
    exit();
}

$mimeType = $imageInfo['mime'];
if (!isset($allowedTypes[$mimeType])) {
    echo json_encode(["success" => false, "message" => "Unsupported image format. Allowed: JPEG, PNG, GIF, WebP"]);
    exit();
}

$extension = $allowedTypes[$mimeType];

// Get facilitator_id for filename generation
$facilitator_id = null;
$facilitatorStmt = $conn->prepare("SELECT facilitator_id FROM facilitator WHERE classID = ?");
$facilitatorStmt->bind_param("s", $classID);
$facilitatorStmt->execute();
$facilitatorResult = $facilitatorStmt->get_result();
if ($facilitatorResult->num_rows > 0) {
    $facilitator_id = $facilitatorResult->fetch_assoc()['facilitator_id'];
}
$facilitatorStmt->close();

// Generate unique filename with facilitator_id or classID
$profileImageName = time() . '_' . ($facilitator_id ?? $classID) . '_profile.' . $extension;
$profileImagePath = $profileDir . $profileImageName;

// Move uploaded file to destination
if (!move_uploaded_file($uploadedFile['tmp_name'], $profileImagePath)) {
    echo json_encode(["success" => false, "message" => "Failed to save profile image to server"]);
    exit();
}

// Set proper file permissions
chmod($profileImagePath, 0644);

// Check if facilitator record exists
$checkStmt = $conn->prepare("SELECT facilitator_id, f_profile FROM facilitator WHERE classID = ?");
$checkStmt->bind_param("s", $classID);
$checkStmt->execute();
$result = $checkStmt->get_result();
$facilitatorExists = $result->num_rows > 0;
$oldProfilePath = null;

if ($facilitatorExists) {
    $row = $result->fetch_assoc();
    $oldProfilePath = $row['f_profile'];
}
$checkStmt->close();

if ($facilitatorExists) {
    // Update existing facilitator record with new profile image
    $stmt = $conn->prepare("UPDATE facilitator SET f_profile = ? WHERE classID = ?");
    $stmt->bind_param("ss", $profileImagePath, $classID);
    
    if ($stmt->execute()) {
        // Delete old profile image if it exists and is different
        if ($oldProfilePath && $oldProfilePath !== $profileImagePath && file_exists($oldProfilePath)) {
            unlink($oldProfilePath);
        }
        
        echo json_encode([
            "success" => true, 
            "message" => "Profile image updated successfully",
            "profile_path" => $profileImagePath,
            "image_url" => $profileImagePath // For frontend display
        ]);
    } else {
        // Clean up uploaded file if database update fails
        if (file_exists($profileImagePath)) {
            unlink($profileImagePath);
        }
        error_log("Database error: " . $stmt->error);
        echo json_encode(["success" => false, "message" => "Database error: " . $stmt->error]);
    }
    $stmt->close();
} else {
    // Create new facilitator record with just classID and profile image
    $stmt = $conn->prepare("INSERT INTO facilitator (classID, f_profile) VALUES (?, ?)");
    $stmt->bind_param("ss", $classID, $profileImagePath);
    
    if ($stmt->execute()) {
        echo json_encode([
            "success" => true, 
            "message" => "New facilitator record created with profile image",
            "profile_path" => $profileImagePath,
            "image_url" => $profileImagePath,
            "facilitator_id" => $conn->insert_id
        ]);
    } else {
        // Clean up uploaded file if database insert fails
        if (file_exists($profileImagePath)) {
            unlink($profileImagePath);
        }
        error_log("Database error: " . $stmt->error);
        echo json_encode(["success" => false, "message" => "Database error: " . $stmt->error]);
    }
    $stmt->close();
}

// Close connection
$conn->close();
?>