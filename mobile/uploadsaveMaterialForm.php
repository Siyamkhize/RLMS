<?php
// uploadsaveMaterialForm.php

include('connection.php');
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

$response = array("success" => false, "message" => "Unknown error occurred");

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Check if the required form data is set
    if (isset($_FILES['facilitatorSignature'], $_FILES['representativeSignature'])) {
        // Extract form fields
        $classID = $_POST['classID'];
        $facilitatorFullName = $_POST['facilitatorFullName'];
        $representativeFullName = $_POST['representativeFullName'];
        $qualificationName = $_POST['qualificationName'];
        $description = $_POST['description'];
        $quantity = $_POST['quantity'];
        $createdAt = $_POST['createdAt'];
        $updatedAt = $_POST['updatedAt'];
        $is_synced = 1;  // Set synced to 0 by default
        
        // Define the upload directory for signatures
        $uploadDirectory = 'reports/';
        if (!is_dir($uploadDirectory)) {
            mkdir($uploadDirectory, 0777, true); // Create the directory if it doesn't exist
        }

        // Save facilitator signature
        $facilitatorSignature = $_FILES['facilitatorSignature'];
        $facilitatorSignatureName = $facilitatorFullName . '_signature.png';  // Construct unique name
        $facilitatorSignaturePath = $uploadDirectory . $facilitatorSignatureName;
        if (!move_uploaded_file($facilitatorSignature['tmp_name'], $facilitatorSignaturePath)) {
            $response['message'] = 'Failed to upload facilitator signature.';
            echo json_encode($response);
            exit();
        }

        // Save representative signature
        $representativeSignature = $_FILES['representativeSignature'];
        $representativeSignatureName = $representativeFullName . '_signature.png'; // Construct unique name
        $representativeSignaturePath = $uploadDirectory . $representativeSignatureName;
        if (!move_uploaded_file($representativeSignature['tmp_name'], $representativeSignaturePath)) {
            $response['message'] = 'Failed to upload representative signature.';
            echo json_encode($response);
            exit();
        }

        // Check if a record with the same classID, facilitatorFullName, and description already exists
        $stmt = $conn->prepare("SELECT id FROM material_forms WHERE classID = ? AND facilitator_full_name = ? AND description = ?");
        $stmt->bind_param("iss", $classID, $facilitatorFullName, $description);
        $stmt->execute();
        $stmt->store_result();

        if ($stmt->num_rows > 0) {
            // Record exists, return an error message
            $response['message'] = 'This entry already exists with the same Class ID, Facilitator Name, and Description.';
        } else {
            // Insert into the database if no record exists
            $stmt = $conn->prepare("INSERT INTO material_forms (classID, facilitator_full_name, representative_full_name, qualification_name, facilitator_signature, representative_signature, description, quantity, is_synced, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->bind_param("issssssisss", $classID, $facilitatorFullName, $representativeFullName, $qualificationName, $facilitatorSignatureName, $representativeSignatureName, $description, $quantity,$is_synced, $createdAt, $updatedAt);

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
?>
