<?php
include('connection.php');

// Set the response type to JSON
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Error reporting settings for debugging
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Initialize an array to hold any errors
$errors = [];

// Check if the learner agreement document is uploaded
if (isset($_FILES['learner_agreement']) && $_FILES['learner_agreement']['error'] === UPLOAD_ERR_OK) {
    // Get temporary file name and file name
    $agreementTmpName = $_FILES['learner_agreement']['tmp_name'];
    $agreementName = basename($_FILES['learner_agreement']['name']);
    
    // Define an absolute path to store the learner agreement
    $agreementPath = __DIR__ . '/agreement/' . $agreementName;

    // Ensure the directory exists
    $directoryPath = __DIR__ . '/agreement/';
    if (!is_dir($directoryPath)) {
        // Create the directory if it doesn't exist
        mkdir($directoryPath, 0777, true); // Permissions can be adjusted as needed
    }

    // Attempt to move the uploaded file to the destination
    if (move_uploaded_file($agreementTmpName, $agreementPath)) {
        // File successfully uploaded
    } else {
        $errors[] = 'Failed to upload learner agreement.';
    }
} else {
    $errors[] = 'No learner agreement uploaded or there was an upload error.';
}

// If no errors occurred during file upload, proceed to insert data
if (empty($errors)) {
    // Validate required data (e.g., learner_id)
    $learner_id = $_POST['learner_id'] ?? null; // Assuming learner_id is sent via POST
    $upload_date = date('Y-m-d H:i:s'); // Current timestamp

    if (empty($learner_id)) {
        $errors[] = 'Missing learner ID.';
    }

    if (empty($errors)) {
        // SQL query to insert the learner document
        $sql = "INSERT INTO learner_document (documentName, learner_document, status, learner_id, upload_date, synced)
                VALUES (?, ?, 'Approved', ?, ?, 1)";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param('ssss', $agreementName, $agreementPath, $learner_id, $upload_date);

        if ($stmt->execute()) {
            echo json_encode(['success' => true, 'message' => 'Learner document uploaded and synced successfully.']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to insert learner document into database.']);
        }

        $stmt->close();
    }
}

// Return errors if any
if (!empty($errors)) {
    echo json_encode(['success' => false, 'message' => implode(', ', $errors)]);
}

$conn->close();
?>
