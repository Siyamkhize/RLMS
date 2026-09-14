<?php
include 'connection.php';

error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Define the server directory where the image will be saved
$uploadDir = 'mobile/learnerImages/';

// Check if the profile_image file has been uploaded
if (isset($_FILES['profile_image']) && isset($_POST['learnerID'])) {
    $fileError = $_FILES['profile_image']['error'];
    $learnerID = $_POST['learnerID']; // Ensure learnerID is passed in the POST request

    // Check for any upload errors
    if ($fileError === UPLOAD_ERR_OK) {
        $tmpName = $_FILES['profile_image']['tmp_name'];
        $fileName = basename($_FILES['profile_image']['name']);
        $filePath = $uploadDir . $fileName;

        // Move the uploaded file to the target directory
        if (move_uploaded_file($tmpName, $filePath)) {
            // Update the learnerdetails table with the image name
            $updateQuery = "UPDATE learnerdetails SET profile_image = ? WHERE learnerID = ?";
            $stmt = $conn->prepare($updateQuery);

            if ($stmt) {
                $stmt->bind_param('si', $fileName, $learnerID);
                if ($stmt->execute()) {
                    echo json_encode([
                        'success' => true,
                        'message' => 'Profile image uploaded and learnerdetails table updated successfully.',
                        'file_path' => $filePath
                    ]);
                } else {
                    echo json_encode(['success' => false, 'message' => 'Failed to update learnerdetails table.', 'error' => $stmt->error]);
                }
                $stmt->close();
            } else {
                echo json_encode(['success' => false, 'message' => 'Failed to prepare database query.', 'error' => $conn->error]);
            }
        } else {
            // If file move fails
            echo json_encode(['success' => false, 'message' => 'Failed to move the uploaded file.']);
        }
    } else {
        // If file upload error occurred
        echo json_encode(['success' => false, 'message' => 'File upload error: ' . $fileError]);
    }
} else {
    // If no file was uploaded or learnerID was not provided
    echo json_encode(['success' => false, 'message' => 'No file uploaded or learnerID is missing.']);
}

$conn->close();
?>
