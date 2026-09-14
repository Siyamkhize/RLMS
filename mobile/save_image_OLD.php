<?php
// save_image.php
include 'connection.php'; // Include your database connection

error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    echo json_encode(["success" => false, "message" => "Connection failed: " . $conn->connect_error]);
    exit();
}

$targetDir = "learnerImages/";

if (!is_dir($targetDir)) {
    mkdir($targetDir, 0777, true); // Create directory if it doesn't exist
}

// Check if file and learner ID are provided
if (isset($_FILES['image']) && isset($_POST['learner_id'])) {
    $learner_id = $_POST['learner_id'];
    $imageFile = $_FILES['image'];
    $image_name = basename($imageFile['name']);
    $targetFilePath = $targetDir . $image_name;

    // Validate learner ID
    if (empty($learner_id)) {
        echo json_encode(["success" => false, "message" => "Learner ID is missing."]);
        exit();
    }

    // Check file type (e.g., allow only images)
    $fileType = pathinfo($targetFilePath, PATHINFO_EXTENSION);
    $allowedTypes = ['jpg', 'jpeg', 'png', 'gif'];
    if (!in_array(strtolower($fileType), $allowedTypes)) {
        echo json_encode(["success" => false, "message" => "Invalid file type. Only JPG, JPEG, PNG, and GIF are allowed."]);
        exit();
    }

    // Move the uploaded file to the target directory
    if (move_uploaded_file($imageFile['tmp_name'], $targetFilePath)) {
        // Update the existing learner record with the image filename
        $stmt = $conn->prepare("UPDATE learnerdetails SET profile_image = ?, synced = 1 WHERE LearnerID = ?");
        $stmt->bind_param("ss", $image_name, $learner_id);

        // Execute the statement and handle success or failure
        if ($stmt->execute()) {
            if ($stmt->affected_rows > 0) {
                echo json_encode([
                    "success" => true, 
                    "message" => "Image uploaded and database updated successfully.",
                    "image_name" => $image_name,
                    "learner_id" => $learner_id
                ]);
            } else {
                // No rows affected - learner might not exist
                echo json_encode([
                    "success" => false, 
                    "message" => "Learner ID $learner_id not found in database. Image uploaded but database not updated.",
                    "image_name" => $image_name
                ]);
            }
        } else {
            echo json_encode(["success" => false, "message" => "Database error: " . $stmt->error]);
        }
        $stmt->close();
    } else {
        echo json_encode(["success" => false, "message" => "Failed to move the uploaded file."]);
    }
} else {
    echo json_encode(["success" => false, "message" => "No image file or learner ID provided."]);
}

$conn->close();
?>
