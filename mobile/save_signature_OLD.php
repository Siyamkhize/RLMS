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
    error_log("Connection failed: " . $conn->connect_error);
    echo json_encode(["success" => false, "message" => "Connection failed: " . $conn->connect_error]);
    exit();
}

// Determine which signature field is present
$field_name = '';
$signature = null;
if (isset($_FILES['signature'])) {
    $field_name = 'signature';
    $signature = $_FILES['signature'];
} elseif (isset($_FILES['witness_signature'])) {
    $field_name = 'witness_signature';
    $signature = $_FILES['witness_signature'];
}

if ($signature && isset($_POST['learner_id'])) {
    $learner_id = trim($_POST['learner_id']); // Trim to avoid whitespace issues
    error_log("Received learner_id: $learner_id, field_name: $field_name");

    // Validate learner_id exists
    $check_query = "SELECT LearnerID FROM learnerdetails WHERE LearnerID = ?";
    $check_stmt = $conn->prepare($check_query);
    $check_stmt->bind_param("i", $learner_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    if ($check_result->num_rows === 0) {
        error_log("No learner found with LearnerID: $learner_id");
        echo json_encode(['success' => false, 'message' => 'No learner found with LearnerID: ' . $learner_id]);
        $check_stmt->close();
        $conn->close();
        exit();
    }
    $check_stmt->close();

    // Ensure upload directory exists
    $upload_dir = 'signatures/';
    if (!is_dir($upload_dir)) {
        mkdir($upload_dir, 0775, true);
    }

    // Generate file name (avoid overwriting by including timestamp)
    $file_name = $learner_id . '_' . $field_name . '_' . time() . '.png';
    $file_path = $upload_dir . $file_name;

    if ($signature['error'] !== UPLOAD_ERR_OK) {
        error_log("File upload error for $field_name: " . $signature['error']);
        echo json_encode(['success' => false, 'message' => 'File upload error: ' . $signature['error']]);
        $conn->close();
        exit();
    }

    if (move_uploaded_file($signature['tmp_name'], $file_path)) {
        // Update database
        $column = $field_name === 'signature' ? 'signature' : 'witness_signature';
        $sql = "UPDATE learnerdetails SET $column = ? WHERE LearnerID = ?";
        $stmt = $conn->prepare($sql);

        if ($stmt === false) {
            error_log("Failed to prepare statement: " . $conn->error);
            echo json_encode(['success' => false, 'message' => 'Failed to prepare statement: ' . $conn->error]);
            $conn->close();
            exit();
        }

        $stmt->bind_param("si", $file_name, $learner_id);

        if ($stmt->execute()) {
            if ($stmt->affected_rows > 0) {
                error_log("Signature updated for learner_id: $learner_id, column: $column");
                echo json_encode(['success' => true, 'message' => "$field_name saved and database updated successfully"]);
            } else {
                error_log("No rows affected for learner_id: $learner_id, column: $column, file_name: $file_name");
                echo json_encode(['success' => false, 'message' => 'No changes made for LearnerID: ' . $learner_id . '. Signature may already be set.']);
            }
        } else {
            error_log("Failed to execute statement: " . $stmt->error);
            echo json_encode(['success' => false, 'message' => 'Failed to execute statement: ' . $stmt->error]);
        }

        $stmt->close();
    } else {
        error_log("Failed to move uploaded file to $file_path");
        echo json_encode(['success' => false, 'message' => 'Failed to save signature. Error code: ' . $signature['error']]);
    }
} else {
    error_log("Invalid request: signature or learner_id missing");
    echo json_encode(['success' => false, 'message' => 'Invalid request: signature or learner_id missing']);
}

$conn->close();
?>