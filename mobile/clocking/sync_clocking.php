<?php

require_once __DIR__ . '/../../security_functions.php';
include '../connection.php'; 
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
$clock_out_time = !empty($data['clock_out_time']) ? $data['clock_out_time'] : null;
$contact_time = !empty($data['contact_time']) ? $data['contact_time'] : null;
$clocking_id = $data['clocking_id'] ?? null;
$user_latitude = !empty($data['user_latitude']) ? $data['user_latitude'] : null;
$user_longitude = !empty($data['user_longitude']) ? $data['user_longitude'] : null;
$user_accuracy = !empty($data['user_accuracy']) ? $data['user_accuracy'] : null;

// Match existing record by LearnerID + clock_date + clock_in_time (unique key)
$checkQuery = "SELECT clocking_id FROM learner_clocking WHERE LearnerID = ? AND clock_date = ? AND clock_in_time = ?";
$checkStmt = $conn->prepare($checkQuery);
$checkStmt->bind_param('sss', $LearnerID, $clock_date, $clock_in_time);
$checkStmt->execute();
$checkResult = $checkStmt->get_result();
$existingRow = $checkResult->fetch_assoc();
$checkStmt->close();

if ($existingRow) {
    // UPDATE existing record - merge incoming data, avoid duplicates
    // We no longer store signature for clocking; keep existing DB value as-is.
    logMessage("Updating existing record for LearnerID: $LearnerID, clock_date: $clock_date, clock_in_time: $clock_in_time");
    $existingId = (int)$existingRow['clocking_id'];

    // Handle optional signature upload for update
    $target_file = null;
    if (isset($_FILES['signature']) && $_FILES['signature']['error'] === UPLOAD_ERR_OK) {
        $signature = $_FILES['signature'];
        $target_dir = "signatures/";
        if (!is_dir($target_dir)) {
            mkdir($target_dir, 0755, true);
        }
        $uniqueFileName = uniqid('signature_', true) . '.' . pathinfo($signature["name"], PATHINFO_EXTENSION);
        $target_file = $target_dir . $uniqueFileName;
        if (!move_uploaded_file($signature["tmp_name"], $target_file)) {
            $target_file = null; // fallback to NULL if upload fails
        }
    }

    // Build UPDATE: merge incoming data; if signature sent, store it, otherwise set NULL
    $updates = [];
    $types = '';
    $params = [];

    if ($target_file !== null) {
        $updates[] = "signature = ?";
        $types .= 's';
        $params[] = $target_file;
    } else {
        $updates[] = "signature = NULL";
    }

    if ($clock_out_time !== null) {
        $updates[] = "clock_out_time = ?";
        $types .= 's';
        $params[] = $clock_out_time;
    }
    if ($contact_time !== null) {
        $updates[] = "contact_time = ?";
        $types .= 's';
        $params[] = $contact_time;
    }
    if ($user_latitude !== null) {
        $updates[] = "user_latitude = ?";
        $types .= 's';
        $params[] = $user_latitude;
    }
    if ($user_longitude !== null) {
        $updates[] = "user_longitude = ?";
        $types .= 's';
        $params[] = $user_longitude;
    }
    if ($user_accuracy !== null) {
        $updates[] = "user_accuracy = ?";
        $types .= 's';
        $params[] = $user_accuracy;
    }

    if (!empty($updates)) {
        $params[] = $existingId;
        $types .= 'i';
        $updateSql = "UPDATE learner_clocking SET " . implode(', ', $updates) . " WHERE clocking_id = ?";
        $updateStmt = $conn->prepare($updateSql);
        if ($updateStmt) {
            $updateStmt->bind_param($types, ...$params);
            if ($updateStmt->execute()) {
                $response = ['status' => 'success', 'message' => 'Record updated successfully.'];
                logMessage("Record updated for LearnerID: $LearnerID, clocking_id: $existingId");
            } else {
                $errorMessage = "Update error: " . $updateStmt->error;
                $response = ['status' => 'error', 'message' => $errorMessage];
                logMessage($errorMessage);
            }
            $updateStmt->close();
        } else {
            $response = ['status' => 'success', 'message' => 'Record already synced.'];
        }
    } else {
        $response = ['status' => 'success', 'message' => 'Record already synced.'];
    }
} else {
    // INSERT new record (no existing match)
    // If signature file is provided, store it; otherwise insert NULL for signature.
    $target_file = null;
    if (isset($_FILES['signature']) && $_FILES['signature']['error'] === UPLOAD_ERR_OK) {
        $signature = $_FILES['signature'];
        $target_dir = "signatures/";
        if (!is_dir($target_dir)) {
            mkdir($target_dir, 0755, true);
        }
        $uniqueFileName = uniqid('signature_', true) . '.' . pathinfo($signature["name"], PATHINFO_EXTENSION);
        $target_file = $target_dir . $uniqueFileName;
        if (!move_uploaded_file($signature["tmp_name"], $target_file)) {
            $target_file = null;
        }
    }

    $isSynced = 1;
    $query = "INSERT INTO learner_clocking (LearnerID, clock_date, clock_in_time, clock_out_time, contact_time, signature, synced, user_latitude, user_longitude, user_accuracy) 
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($query);
    if ($stmt) {
        $stmt->bind_param('ssssssisss', $LearnerID, $clock_date, $clock_in_time, $clock_out_time, $contact_time, $target_file, $isSynced, $user_latitude, $user_longitude, $user_accuracy);
        if ($stmt->execute()) {
            $response = ['status' => 'success', 'message' => 'Data synced successfully.'];
            logMessage("Inserted new record for LearnerID: $LearnerID");
        } else {
            $response = ['status' => 'error', 'message' => 'Database error: ' . $stmt->error];
        }
        $stmt->close();
    } else {
        $response = ['status' => 'error', 'message' => 'Failed to prepare statement: ' . $conn->error];
    }
}

echo json_encode($response ?? ['status' => 'error', 'message' => 'Unknown error']);
$conn->close();
logMessage("Request processing completed.");
?>