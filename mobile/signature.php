<?php
include 'connection.php';

error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    echo json_encode(["success" => false, "message" => "Connection failed: " . $conn->connect_error]);
    exit();
}

if (isset($_GET['learner_id'])) {
    $learner_id = intval($_GET['learner_id']);

    $sql = "SELECT profile_image FROM learnerdetails WHERE LearnerID = ?";
    $stmt = $conn->prepare($sql);

    if ($stmt === false) {
        echo json_encode(["success" => false, "message" => "Failed to prepare statement: " . $conn->error]);
        exit();
    }

    $stmt->bind_param("i", $learner_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $learnerData = $result->fetch_assoc();

        if (!empty($learnerData['profile_image'])) {
            $filePath = 'learnerImages/' . $learnerData['profile_image']; // Update the folder path if necessary
            if (file_exists($filePath)) {
                // Convert the image to base64
                $imageData = base64_encode(file_get_contents($filePath));
                $learnerData['profile_image'] = $imageData; // Replace file name with base64 string
            } else {
                $learnerData['profile_image'] = null; // File not found
            }
        } else {
            $learnerData['profile_image'] = null; // No profile image available
        }

        echo json_encode(["success" => true, "data" => $learnerData]);
    } else {
        echo json_encode(["success" => false, "message" => "No learner found with the provided ID"]);
    }

    $stmt->close();
} else {
    echo json_encode(["success" => false, "message" => "Invalid request: learner_id is required"]);
}

$conn->close();
?>
