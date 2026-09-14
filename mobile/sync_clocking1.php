<?php
include 'connection.php'; 
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

function logMessage($message) {
    $logFile = 'sync_log.txt';
    $currentDate = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[$currentDate] $message\n", FILE_APPEND);
}

logMessage("Request received.");
logMessage("Request method: " . $_SERVER['REQUEST_METHOD']);

// Handle CORS pre-flight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    logMessage("OPTIONS request handled.");
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    $errorMessage = "Invalid request method: " . $_SERVER['REQUEST_METHOD'];
    logMessage($errorMessage);
    echo json_encode(["status" => "error", "message" => $errorMessage]);
    exit;
}

$data = $_POST;
logMessage("Received POST data: " . print_r($data, true));
logMessage("Received FILES data: " . print_r($_FILES, true));

// Default to current date if clock_date is not provided
$clock_date = $data['clock_date'] ?? date('Y-m-d');

// Required fields (made clock_out_time and contact_time optional)
$requiredFields = ['LearnerID', 'clock_in_time'];
foreach ($requiredFields as $field) {
    if (empty($data[$field]) && $data[$field] !== "0") {
        $errorMessage = "Missing required field: $field";
        logMessage($errorMessage);
        echo json_encode(["status" => "error", "message" => $errorMessage]);
        exit;
    }
}

$LearnerID = $data['LearnerID'];
$clock_in_time = $data['clock_in_time'];
$clock_out_time = $data['clock_out_time'] ?? null;
$contact_time = $data['contact_time'] ?? null;
$clocking_id = $data['clocking_id'] ?? null;


// Check for duplicates
$checkQuery = "SELECT clocking_id FROM learner_clocking WHERE LearnerID = ? AND clock_in_time = ? AND (clock_out_time = ? OR clock_out_time IS NULL)";
$checkStmt = $conn->prepare($checkQuery);
$checkStmt->bind_param('sss', $LearnerID, $clock_in_time, $clock_out_time);
$checkStmt->execute();
$checkStmt->store_result();

if ($checkStmt->num_rows > 0) {
    $response = ['status' => 'success', 'message' => 'Record already synced.'];
    logMessage("Duplicate record detected for LearnerID: $LearnerID");
} else {
    // Handle signature upload
    $target_file = null;
    if (isset($_FILES['signature']) && $_FILES['signature']['error'] === UPLOAD_ERR_OK) {
        $signature = $_FILES['signature'];
        $target_dir = "signatures/";

        if (!is_dir($target_dir)) {
            mkdir($target_dir, 0755, true);
            logMessage("Signature directory created.");
        }

        $maxFileSize = 2 * 1024 * 1024; // 2MB
        $allowedTypes = ['image/png', 'image/jpeg'];
        $fileType = mime_content_type($signature['tmp_name']);

        if (!in_array($fileType, $allowedTypes)) {
            $errorMessage = "Invalid file type: $fileType";
            logMessage($errorMessage);
            echo json_encode(["status" => "error", "message" => $errorMessage]);
            exit;
        }

        if ($signature["size"] > $maxFileSize) {
            $errorMessage = "File size exceeds limit: " . $signature["size"];
            logMessage($errorMessage);
            echo json_encode(["status" => "error", "message" => $errorMessage]);
            exit;
        }

        $uniqueFileName = uniqid('signature_', true) . '.' . pathinfo($signature["name"], PATHINFO_EXTENSION);
        $target_file = $target_dir . $uniqueFileName;

        if (!move_uploaded_file($signature["tmp_name"], $target_file)) {
            $errorMessage = "Failed to upload signature file.";
            logMessage($errorMessage);
            echo json_encode(["status" => "error", "message" => $errorMessage]);
            exit;
        }
        logMessage("Signature uploaded to: $target_file");
    }

    // Insert new record
    $isSynced = 1;
    $query = "INSERT INTO learner_clocking (LearnerID, clock_date, clock_in_time, clock_out_time, contact_time, signature, synced) 
              VALUES (?, ?, ?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($query);

    if ($stmt) {
        $stmt->bind_param('ssssssi', $LearnerID, $clock_date, $clock_in_time, $clock_out_time, $contact_time, $target_file, $isSynced);
        if ($stmt->execute()) {
            $response = ['status' => 'success', 'message' => 'Data synced successfully.'];
            logMessage("Data synced successfully for LearnerID: $LearnerID");
        } else {
            $errorMessage = "Database error: " . $stmt->error . " (Query: $query)";
            $response = ['status' => 'error', 'message' => $errorMessage];
            logMessage($errorMessage);
        }
        $stmt->close();
    } else {
        $errorMessage = "Failed to prepare SQL statement: " . $conn->error;
        $response = ['status' => 'error', 'message' => $errorMessage];
        logMessage($errorMessage);
    }
}
$checkStmt->close();

echo json_encode($response);
$conn->close();
logMessage("Request processing completed.");
?>