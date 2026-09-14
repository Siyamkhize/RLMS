<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Include database connection file
include('connection.php');

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    error_log("Connection failed: " . $conn->connect_error);
    echo json_encode([
        'success' => false,
        'message' => 'Error: Failed to connect to the database - ' . $conn->connect_error,
        'synced_records' => 0,
        'errors' => ['Database connection failed: ' . $conn->connect_error]
    ]);
    exit;
}

// Directory to store uploaded files
$uploadDir = 'sicknotes/';
if (!file_exists($uploadDir)) {
    mkdir($uploadDir, 0777, true);
}

$response = ['success' => false, 'message' => '', 'synced_records' => 0, 'errors' => []];

try {
    // Handle OPTIONS request for CORS preflight
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit;
    }

    // Check if data field exists
    if (!isset($_POST['data'])) {
        throw new Exception('No data provided');
    }

    // Decode JSON data
    $records = json_decode($_POST['data'], true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Invalid JSON data');
    }

    if (empty($records)) {
        throw new Exception('No valid records to process');
    }

    $insertedRecords = 0;
    $errors = [];

    // Ensure files are sent as an array
    if (!isset($_FILES['document_file']) || !is_array($_FILES['document_file']['name'])) {
        throw new Exception('No document files uploaded or invalid file format');
    }

    foreach ($records as $index => $record) {
        // Validate required fields
        if (!isset($record['learner_id']) ||
            !isset($record['document_path']) ||
            !isset($record['practice_name']) ||
            !isset($record['medical_practitioner']) ||
            !isset($record['practitioner_name']) ||
            !isset($record['date_from']) ||
            !isset($record['date_to']) ||
            !isset($record['upload_date']) ||
            !isset($record['status'])) {
            $errors[] = "Record $index: Missing required fields";
            continue;
        }

        $learnerId = $record['learner_id'];
        $documentPath = $record['document_path']; // Filename only
        $practiceName = $record['practice_name'];
        $medicalPractitioner = $record['medical_practitioner'];
        $practitionerName = $record['practitioner_name'];
        $dateFrom = $record['date_from'];
        $dateTo = $record['date_to'];
        $uploadDate = $record['upload_date'];
        $status = $record['status'];
        $rejectionReason = null; // Explicitly set to NULL

        // Validate document file
        if (!isset($_FILES['document_file']['name'][$index]) || $_FILES['document_file']['error'][$index] !== UPLOAD_ERR_OK) {
            $errors[] = "Record $index: Missing or invalid document file";
            continue;
        }

        $fileTmpPath = $_FILES['document_file']['tmp_name'][$index];
        $fileName = basename($_FILES['document_file']['name'][$index]);
        $fileType = $_FILES['document_file']['type'][$index];

        // Validate file type (PDF only)
        if ($fileType !== 'application/pdf') {
            $errors[] = "Record $index: Invalid file type. Only PDFs are allowed.";
            continue;
        }

        // Validate that the uploaded filename matches the document_path
        if ($fileName !== $documentPath) {
            $errors[] = "Record $index: Uploaded filename ($fileName) does not match document_path ($documentPath)";
            continue;
        }

        // Generate unique filename to avoid conflicts
        $uniqueFileName = uniqid('sick_note_') . '_' . $fileName;
        $destPath = $uploadDir . $uniqueFileName;

        if (!move_uploaded_file($fileTmpPath, $destPath)) {
            $errors[] = "Record $index: Failed to upload file";
            continue;
        }

        // Insert record into database using MySQLi prepared statement
        $stmt = $conn->prepare("
            INSERT INTO sick_note (
                learner_id, document_path, practice_name, medical_practitioner, 
                practitioner_name, date_from, date_to, upload_date, status, rejection_reason
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        if (!$stmt) {
            $errors[] = "Record $index: Failed to prepare statement: " . $conn->error;
            continue;
        }

        $stmt->bind_param(
            "ssssssssss",
            $learnerId,
            $destPath,
            $practiceName,
            $medicalPractitioner,
            $practitionerName,
            $dateFrom,
            $dateTo,
            $uploadDate,
            $status,
            $rejectionReason
        );

        if (!$stmt->execute()) {
            $errors[] = "Record $index: Failed to insert record: " . $stmt->error;
            $stmt->close();
            continue;
        }

        $insertedRecords++;
        $stmt->close();
    }

    // Update response with sync status
    $response['synced_records'] = $insertedRecords;
    if ($insertedRecords > 0) {
        $response['success'] = true;
        $response['message'] = "Successfully synced $insertedRecords sick note record(s)";
        if (!empty($errors)) {
            $response['message'] .= '. Partial errors occurred: ' . implode(', ', $errors);
            $response['errors'] = $errors;
        }
    } else {
        $response['message'] = 'No records were synced';
        if (!empty($errors)) {
            $response['message'] .= '. Errors: ' . implode(', ', $errors);
            $response['errors'] = $errors;
        }
    }

} catch (Exception $e) {
    $response['message'] = 'Error: ' . $e->getMessage();
    $response['errors'] = [$e->getMessage()];
}

echo json_encode($response);
$conn->close();
exit;
?>