<?php
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', '/home/username/public_html/logs/php_error_log');
error_reporting(E_ALL);
ob_start();

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

include('connection.php');

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    error_log('Connection failed: ' . $conn->connect_error);
    ob_end_clean();
    echo json_encode(['status' => 'error', 'message' => 'Connection failed']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $learnerID = $_POST['learnerID'] ?? '';
    $type = $_POST['type'] ?? '';
    $exercisesJson = $_POST['exercises'] ?? '';
    $unitStandardName = $_POST['unit_standard_name'] ?? '';

    if (empty($learnerID) || empty($type) || empty($exercisesJson)) {
        error_log('Missing required fields: ' . print_r($_POST, true));
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'Missing required fields']);
        exit;
    }

    // Decode exercises array
    $exercises = json_decode($exercisesJson, true);
    if (!is_array($exercises) || empty($exercises)) {
        error_log('Invalid exercises data: ' . $exercisesJson);
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'Invalid exercises data']);
        exit;
    }

    // Validate type
    $validTypes = ['Formative', 'Summative', 'LogBook'];
    if (!in_array($type, $validTypes)) {
        error_log('Invalid type: ' . $type);
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'Invalid assessment type']);
        exit;
    }

    error_log("Bulk upload request: learnerID=$learnerID, type=$type, exercises=" . implode(',', $exercises));

    // Check for duplicates
    $placeholders = str_repeat('?,', count($exercises) - 1) . '?';
    $checkStmt = $conn->prepare("SELECT exercise FROM poe WHERE learnerID = ? AND type = ? AND exercise IN ($placeholders)");
    if (!$checkStmt) {
        error_log('Prepare failed: ' . $conn->error);
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'Database prepare error']);
        exit;
    }
    
    $params = array_merge([$learnerID, $type], $exercises);
    $checkStmt->bind_param(str_repeat('s', count($params)), ...$params);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();
    
    $existingExercises = [];
    while ($row = $checkResult->fetch_assoc()) {
        $existingExercises[] = $row['exercise'];
    }
    $checkStmt->close();

    if (!empty($existingExercises)) {
        error_log('Duplicate exercises found: ' . implode(',', $existingExercises));
        ob_end_clean();
        echo json_encode([
            'status' => 'error', 
            'message' => 'Some exercises have already been answered: ' . implode(', ', $existingExercises)
        ]);
        $conn->close();
        exit;
    }

    // Log upload limits
    $uploadMaxFilesize = ini_get('upload_max_filesize');
    $postMaxSize = ini_get('post_max_size');
    error_log("Upload limits: upload_max_filesize=$uploadMaxFilesize, post_max_size=$postMaxSize");

    // Define upload directory
    $uploadDir = 'POE/';
    error_log('Upload directory: ' . $uploadDir . ' (Exists: ' . (is_dir($uploadDir) ? 'Yes' : 'No') . ', Writable: ' . (is_writable($uploadDir) ? 'Yes' : 'No') . ')');

    if (!is_dir($uploadDir)) {
        if (!mkdir($uploadDir, 0777, true)) {
            error_log('Failed to create directory: ' . $uploadDir);
            ob_end_clean();
            echo json_encode(['status' => 'error', 'message' => 'Failed to create upload directory']);
            $conn->close();
            exit;
        }
    }

    if (!is_writable($uploadDir)) {
        error_log('Upload directory is not writable: ' . $uploadDir);
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'Upload directory is not writable']);
        $conn->close();
        exit;
    }

    error_log('Received files: ' . print_r($_FILES, true));

    $filePaths = [];
    if (isset($_FILES['files']) && is_array($_FILES['files']['name'])) {
        $allowedExtensions = ['pdf'];
        $maxFileSize = 2 * 1024 * 1024; // 2MB

        foreach ($_FILES['files']['name'] as $key => $name) {
            $errorCode = $_FILES['files']['error'][$key];
            if ($errorCode === UPLOAD_ERR_OK) {
                $fileTmpPath = $_FILES['files']['tmp_name'][$key];
                $fileSize = $_FILES['files']['size'][$key];
                $fileName = uniqid() . '_' . basename($name);
                $destinationPath = $uploadDir . $fileName;

                error_log("Processing file: $name, Size: $fileSize bytes, Temp path: $fileTmpPath");

                // Validate file size
                if ($fileSize > $maxFileSize) {
                    error_log("File $name exceeds 2MB limit: $fileSize bytes");
                    ob_end_clean();
                    echo json_encode(['status' => 'error', 'message' => "File $name exceeds 2MB limit"]);
                    $conn->close();
                    exit;
                }

                $extension = strtolower(pathinfo($name, PATHINFO_EXTENSION));
                if (!in_array($extension, $allowedExtensions)) {
                    error_log('Invalid file type: ' . $name . ' for type ' . $type);
                    ob_end_clean();
                    echo json_encode(['status' => 'error', 'message' => 'Invalid file type: ' . $name . '. Allowed: ' . implode(', ', $allowedExtensions)]);
                    $conn->close();
                    exit;
                }

                if (!file_exists($fileTmpPath)) {
                    error_log('Temporary file does not exist: ' . $fileTmpPath);
                    ob_end_clean();
                    echo json_encode(['status' => 'error', 'message' => 'Temporary file does not exist: ' . $name]);
                    $conn->close();
                    exit;
                }

                if (!is_readable($fileTmpPath)) {
                    error_log('Temporary file is not readable: ' . $fileTmpPath);
                    ob_end_clean();
                    echo json_encode(['status' => 'error', 'message' => 'Temporary file is not readable: ' . $name]);
                    $conn->close();
                    exit;
                }

                // Validate file integrity
                if (filesize($fileTmpPath) === 0) {
                    error_log('Empty file uploaded: ' . $name);
                    ob_end_clean();
                    echo json_encode(['status' => 'error', 'message' => 'Empty file uploaded: ' . $name]);
                    $conn->close();
                    exit;
                }

                // Move file
                error_log('Attempting to move file from ' . $fileTmpPath . ' to ' . $destinationPath);
                if (move_uploaded_file($fileTmpPath, $destinationPath)) {
                    $filePaths[] = 'POE/' . $fileName;
                    error_log("File moved successfully: $name to $destinationPath");
                } else {
                    $error = error_get_last();
                    error_log('Failed to move file: ' . $name . ' from ' . $fileTmpPath . ' to ' . $destinationPath . ' (Error: ' . ($error['message'] ?? 'Unknown') . ')');
                    ob_end_clean();
                    echo json_encode(['status' => 'error', 'message' => 'Failed to move uploaded file: ' . $name]);
                    $conn->close();
                    exit;
                }
            } else {
                $errorMessage = match ($errorCode) {
                    UPLOAD_ERR_INI_SIZE => "File $name exceeds upload_max_filesize ($uploadMaxFilesize)",
                    UPLOAD_ERR_FORM_SIZE => "File $name exceeds form size limit",
                    UPLOAD_ERR_PARTIAL => "File $name was only partially uploaded",
                    UPLOAD_ERR_NO_FILE => "No file was uploaded for $name",
                    UPLOAD_ERR_NO_TMP_DIR => "Missing temporary folder for $name",
                    UPLOAD_ERR_CANT_WRITE => "Failed to write file $name to disk",
                    UPLOAD_ERR_EXTENSION => "File upload stopped by PHP extension for $name",
                    default => "Unknown upload error for $name (Error code: $errorCode)",
                };
                error_log('Upload error: ' . $errorMessage);
                ob_end_clean();
                echo json_encode(['status' => 'error', 'message' => $errorMessage]);
                $conn->close();
                exit;
            }
        }
    } else {
        error_log('No files uploaded or invalid file data');
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'No files uploaded or invalid file data']);
        $conn->close();
        exit;
    }

    // Check if we have enough files for all exercises
    if (count($filePaths) < count($exercises)) {
        error_log('Not enough files uploaded. Expected: ' . count($exercises) . ', Received: ' . count($filePaths));
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'Not enough files uploaded. Expected: ' . count($exercises) . ', Received: ' . count($filePaths)]);
        // Clean up uploaded files
        foreach ($filePaths as $path) {
            if (file_exists($path)) {
                unlink($path);
                error_log("Cleaned up file due to insufficient files: $path");
            }
        }
        $conn->close();
        exit;
    }

    // Begin transaction
    $conn->begin_transaction();

    try {
        // Prepare insert statement
        $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, filePath, unit_standard_name) VALUES (?, ?, ?, ?, ?)');
        if (!$stmt) {
            throw new Exception('Database prepare error: ' . $conn->error);
        }

        $successCount = 0;
        $insertedExercises = [];

        // Insert each exercise with its corresponding file
        for ($i = 0; $i < count($exercises); $i++) {
            $exercise = $exercises[$i];
            $filePath = $filePaths[$i];
            
            $stmt->bind_param('sssss', $learnerID, $exercise, $type, $filePath, $unitStandardName);
            
            if ($stmt->execute()) {
                $successCount++;
                $insertedExercises[] = $exercise;
                error_log("Successfully inserted: learnerID=$learnerID, exercise=$exercise, type=$type, filePath=$filePath");
            } else {
                throw new Exception('Failed to insert exercise: ' . $exercise . ' - ' . $stmt->error);
            }
        }

        $stmt->close();

        // Commit transaction
        $conn->commit();

        ob_end_clean();
        echo json_encode([
            'status' => 'success',
            'message' => "Bulk upload successful. $successCount exercises uploaded.",
            'exercises' => $insertedExercises,
            'files' => array_slice($filePaths, 0, count($exercises)),
            'unit_standard_name' => $unitStandardName
        ]);

        error_log("Bulk upload completed successfully: $successCount exercises for learnerID=$learnerID, type=$type");

    } catch (Exception $e) {
        // Rollback transaction
        $conn->rollback();
        
        error_log('Bulk upload failed: ' . $e->getMessage());
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'Bulk upload failed: ' . $e->getMessage()]);
        
        // Clean up uploaded files
        foreach ($filePaths as $path) {
            if (file_exists($path)) {
                unlink($path);
                error_log("Cleaned up file due to database failure: $path");
            }
        }
    }

    $conn->close();
} else {
    ob_end_clean();
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method']);
}

ob_end_flush();
?> 