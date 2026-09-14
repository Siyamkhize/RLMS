<?php
// saveMaterialForm.php

include('connection.php');
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

$response = array("success" => false, "message" => "Unknown error occurred");

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (isset($data['classID'], $data['facilitatorFullName'], $data['representativeFullName'], $data['qualificationName'], $data['description'], $data['facilitatorSignature'], $data['representativeSignature'])) {
        $classID = $data['classID'];
        $facilitatorFullName = $data['facilitatorFullName'];
        $representativeFullName = $data['representativeFullName'];
        $qualificationName = $data['qualificationName'];
        $quantity = $data['quantity'];
        $description = $data['description'];
        $synced = 1;  // Set synced to 0 by default
        $facilitatorSignatureBase64 = $data['facilitatorSignature'];  // Base64 encoded signature
        $representativeSignatureBase64 = $data['representativeSignature']; // Base64 encoded signature

        // Directory where the signatures will be saved
        $reportsFolder = 'reports/';

        // Save the facilitator signature image
        $facilitatorSignature= $facilitatorFullName . '_signature';
        $facilitatorSignaturePath = saveSignatureImage($facilitatorSignatureBase64, $reportsFolder, $facilitatorSignature);
        if ($facilitatorSignaturePath === false) {
            $response['message'] = 'Failed to save facilitator signature.';
            echo json_encode($response);
            exit();
        }

        // Save the representative signature image
        $representativeSignature= $representativeFullName . '_signature';
        $representativeSignaturePath = saveSignatureImage($representativeSignatureBase64, $reportsFolder, $representativeSignature);
        if ($representativeSignaturePath === false) {
            $response['message'] = 'Failed to save representative signature.';
            echo json_encode($response);
            exit();
        }

        // Check if a record with the same classID, facilitatorFullName, and description already exists
        // Check if a record with the same classID, facilitatorFullName, and description already exists
$stmt = $conn->prepare("SELECT id FROM material_forms WHERE classID = ? AND facilitator_full_name = ? AND description = ?");
$stmt->bind_param("iss", $classID, $facilitatorFullName, $description);
$stmt->execute();
$stmt->store_result();

if ($stmt->num_rows > 0) {
    // Record exists, return an error message
    $response['message'] = 'This entry already exists with the same Class ID, Facilitator Name, and Description.';
} else {
    // Capture timestamps
    $createdAt = date('Y-m-d H:i:s'); // Set the current timestamp for new entries
    $updatedAt = $createdAt; // For new entries, created_at and updated_at are the same

    // Insert into the database if no record exists
    $stmt = $conn->prepare("INSERT INTO material_forms (classID, facilitator_full_name, representative_full_name, qualification_name, facilitator_signature, representative_signature, description, quantity, is_synced, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    
    $stmt->bind_param("issssssiiss", $classID, $facilitatorFullName, $representativeFullName, $qualificationName, $facilitatorSignature, $representativeSignature, $description, $quantity, $synced, $createdAt, $updatedAt);

    if ($stmt->execute()) {
        $response['success'] = true;
        $response['message'] = 'Form submitted successfully!';
    } else {
        $response['message'] = 'Failed to save form data.';
    }
}

    } else {
        $response['message'] = 'Missing required fields.';
    }
} else {
    $response['message'] = 'Invalid request method. Only POST method allowed';
}

$conn->close();
echo json_encode($response);

// Function to save the base64 signature to a file
function saveSignatureImage($base64Data, $directory, $prefix) {
    // Decode the Base64 string
    $data = base64_decode($base64Data);
    if ($data === false) {
        return false;
    }

    // Generate a unique file name for the image
    $fileName = $prefix .'.png';
    $filePath = $directory . $fileName;

    // Make sure the directory exists
    if (!is_dir($directory)) {
        mkdir($directory, 0777, true);  // Create the directory if it doesn't exist
    }

    // Save the image data to a file
    if (file_put_contents($filePath, $data)) {
        return $filePath;  // Return the file path to store in the database
    }

    return false;  // Return false if file saving failed
}
?>
