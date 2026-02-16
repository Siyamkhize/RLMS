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

    // Check if this is a bulk upload or individual upload
    $isBulkUpload = isset($_POST['exercises']) && !empty($_POST['exercises']);

    // Check if this is a unit standard bulk upload (single document for all exercises)
    $isUnitStandardUpload = isset($_POST['unit_standard_upload']) && $_POST['unit_standard_upload'] === 'true';
    
    // Get unit standard name if provided
    $unitStandardName = $_POST['unit_standard_name'] ?? '';

    if ($isBulkUpload) {
        // BULK UPLOAD MODE - Multiple files
        $exercisesJson = $_POST['exercises'] ?? '';

        if (empty($learnerID) || empty($type) || empty($exercisesJson)) {
            error_log('Missing required fields for bulk upload: ' . print_r($_POST, true));
            ob_end_clean();
            echo json_encode(['status' => 'error', 'message' => 'Missing required fields for bulk upload']);
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

        error_log("Bulk upload request: learnerID=$learnerID, type=$type, exercises=" . implode(',', $exercises) . ", unitStandard=$unitStandardName");
    } else {
        // INDIVIDUAL UPLOAD MODE (backward compatibility)
        $exercise = $_POST['exercise'] ?? '';
        $logbookText = $_POST['logbook_text'] ?? '';

        if (empty($learnerID) || empty($exercise) || empty($type)) {
            error_log('Missing required fields for individual upload: ' . print_r($_POST, true));
            ob_end_clean();
            echo json_encode(['status' => 'error', 'message' => 'Missing required fields for individual upload']);
            exit;
        }

        // Check if this is a "Scan All" operation (bulk upload with single document)
        $isScanAllOperation = strpos($exercise, 'All Questions') !== false || 
                             strpos($exercise, 'All Entries') !== false ||
                             strpos($exercise, 'All ') === 0;

        // Convert individual upload to bulk format for processing
        $exercises = [$exercise];
        $logbookTexts = [$logbookText];

        error_log("Individual upload request: learnerID=$learnerID, type=$type, exercise=$exercise, isScanAll=$isScanAllOperation");
    }

    // Validate type - UPDATED TO INCLUDE REMEDIAL TYPES
    $validTypes = ['Formative', 'Summative', 'LogBook', 'FormativeRemedial', 'SummativeRemedial'];
    if (!in_array($type, $validTypes)) {
        error_log('Invalid type: ' . $type);
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'Invalid assessment type']);
        exit;
    }

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

    // IMPROVED MULTIPLE FILE HANDLING
    $filePaths = [];
    $uploadedFiles = [];
    $errors = [];

    if (isset($_FILES['files']) && is_array($_FILES['files']['name'])) {
        $allowedExtensions = ['pdf'];
        $maxFileSize = 2 * 1024 * 1024; // 2MB
        $totalFiles = count($_FILES['files']['name']);

        error_log("Processing $totalFiles files for " . count($exercises) . " exercises");

        // For Scan All operations, we expect only 1 file but multiple exercises
        $isScanAllMode = !$isBulkUpload && isset($isScanAllOperation) && $isScanAllOperation && count($exercises) > 1;
        
        if ($isScanAllMode) {
            // Scan All mode: 1 file for multiple exercises
            if ($totalFiles !== 1) {
                error_log("Scan All file count mismatch: Expected 1 file for " . count($exercises) . " exercises, received $totalFiles");
                ob_end_clean();
                echo json_encode([
                    'status' => 'error',
                    'message' => "Scan All expects 1 file for " . count($exercises) . " exercises, received $totalFiles"
                ]);
                $conn->close();
                exit;
            }
        } else {
            // Regular mode: file count should match exercise count
            if ($totalFiles !== count($exercises)) {
                error_log("File count mismatch: Expected " . count($exercises) . " files, received $totalFiles");
                ob_end_clean();
                echo json_encode([
                    'status' => 'error',
                    'message' => "File count mismatch. Expected " . count($exercises) . " files, received $totalFiles"
                ]);
                $conn->close();
                exit;
            }
        }

        foreach ($_FILES['files']['name'] as $key => $name) {
            $errorCode = $_FILES['files']['error'][$key];
            $fileTmpPath = $_FILES['files']['tmp_name'][$key];
            $fileSize = $_FILES['files']['size'][$key];

            error_log("Processing file $key: $name, Size: $fileSize bytes, Error: $errorCode");

            // Check for upload errors
            if ($errorCode !== UPLOAD_ERR_OK) {
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
                $errors[] = $errorMessage;
                error_log('Upload error: ' . $errorMessage);
                continue;
            }

            // Validate file size
            if ($fileSize > $maxFileSize) {
                $errors[] = "File $name exceeds 2MB limit ($fileSize bytes)";
                error_log("File $name exceeds 2MB limit: $fileSize bytes");
                continue;
            }

            // Validate file type
            $extension = strtolower(pathinfo($name, PATHINFO_EXTENSION));
            if (!in_array($extension, $allowedExtensions)) {
                $errors[] = "Invalid file type: $name. Allowed: " . implode(', ', $allowedExtensions);
                error_log('Invalid file type: ' . $name . ' for type ' . $type);
                continue;
            }

            // Validate file exists and is readable
            if (!file_exists($fileTmpPath)) {
                $errors[] = "Temporary file does not exist: $name";
                error_log('Temporary file does not exist: ' . $fileTmpPath);
                continue;
            }

            if (!is_readable($fileTmpPath)) {
                $errors[] = "Temporary file is not readable: $name";
                error_log('Temporary file is not readable: ' . $fileTmpPath);
                continue;
            }

            // Validate file integrity
            if (filesize($fileTmpPath) === 0) {
                $errors[] = "Empty file uploaded: $name";
                error_log('Empty file uploaded: ' . $name);
                continue;
            }

            // Generate unique filename
            $fileName = uniqid() . '_' . basename($name);
            $destinationPath = $uploadDir . $fileName;

            // Move file
            error_log('Attempting to move file from ' . $fileTmpPath . ' to ' . $destinationPath);
            if (move_uploaded_file($fileTmpPath, $destinationPath)) {
                $filePaths[] = 'POE/' . $fileName;
                $uploadedFiles[] = [
                    'original_name' => $name,
                    'saved_name' => $fileName,
                    'path' => 'POE/' . $fileName,
                    'size' => $fileSize,
                    'exercise_index' => $key
                ];
                error_log("File moved successfully: $name to $destinationPath");
            } else {
                $error = error_get_last();
                $errorMsg = 'Failed to move uploaded file: ' . $name . ' (Error: ' . ($error['message'] ?? 'Unknown') . ')';
                $errors[] = $errorMsg;
                error_log($errorMsg);
            }
        }
    } else {
        error_log('No files uploaded or invalid file data');
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'No files uploaded or invalid file data']);
        $conn->close();
        exit;
    }

    // Check for processing errors
    if (!empty($errors)) {
        error_log('File processing errors: ' . implode(', ', $errors));
        ob_end_clean();
        echo json_encode([
            'status' => 'error',
            'message' => 'File processing errors: ' . implode(', ', $errors)
        ]);

        // Clean up any uploaded files
        foreach ($uploadedFiles as $file) {
            if (file_exists($file['path'])) {
                unlink($file['path']);
                error_log("Cleaned up file due to processing errors: " . $file['path']);
            }
        }
        $conn->close();
        exit;
    }

    // Verify we have enough files
    $expectedFileCount = $isScanAllMode ? 1 : count($exercises);
    if (count($filePaths) < $expectedFileCount) {
        error_log('Not enough files uploaded. Expected: ' . $expectedFileCount . ', Received: ' . count($filePaths));
        ob_end_clean();
        echo json_encode([
            'status' => 'error',
            'message' => 'Not enough files uploaded. Expected: ' . $expectedFileCount . ', Received: ' . count($filePaths)
        ]);

        // Clean up uploaded files
        foreach ($uploadedFiles as $file) {
            if (file_exists($file['path'])) {
                unlink($file['path']);
                error_log("Cleaned up file due to insufficient files: " . $file['path']);
            }
        }
        $conn->close();
        exit;
    }

    // For Scan All mode, replicate the single file path for all exercises
    if ($isScanAllMode && count($filePaths) === 1) {
        $singleFilePath = $filePaths[0];
        $filePaths = array_fill(0, count($exercises), $singleFilePath);
        error_log("Replicated single file path for " . count($exercises) . " exercises: $singleFilePath");
    }

    // Handle "Scan All" operations - get all related exercises from the database
    if (!$isBulkUpload && isset($isScanAllOperation) && $isScanAllOperation) {
        error_log("Processing Scan All operation for learnerID=$learnerID, type=$type");
        
        // Query to get all exercises for this learner and type from the learner data
        // We need to get this from the main learner database, not the POE table
        $getAllExercisesQuery = "
            SELECT DISTINCT a.exercise 
            FROM assessments a 
            JOIN learners l ON a.learner_id = l.learner_id 
            WHERE l.learner_id = ? AND a.assessment_type = ?
        ";
        
        $getAllStmt = $conn->prepare($getAllExercisesQuery);
        if ($getAllStmt) {
            $getAllStmt->bind_param("is", $learnerID, $type);
            $getAllStmt->execute();
            $getAllResult = $getAllStmt->get_result();
            
            $allExercises = [];
            while ($row = $getAllResult->fetch_assoc()) {
                $allExercises[] = $row['exercise'];
            }
            $getAllStmt->close();
            
            if (!empty($allExercises)) {
                error_log("Found " . count($allExercises) . " exercises for Scan All: " . implode(', ', $allExercises));
                // Replace the single exercise with all exercises for this type
                $exercises = $allExercises;
                // Create logbook texts array for all exercises
                $logbookTexts = array_fill(0, count($allExercises), $logbookText);
                error_log("Converted to bulk upload with " . count($exercises) . " exercises");
            } else {
                error_log("No exercises found for Scan All operation, proceeding with single exercise");
            }
        } else {
            error_log("Failed to prepare getAllExercises query: " . $conn->error);
        }
    }

    // Begin transaction
    $conn->begin_transaction();

    try {
        if ($isUnitStandardUpload) {
            // For unit standard uploads, save only one document entry with a special exercise name
            $unitStandardExercise = 'All ' . $type . ' Questions';
            $filePath = $filePaths[0]; // Use the first file since they're all the same

            $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, filePath, logbook_text) VALUES (?, ?, ?, ?, ?)');
            if (!$stmt) {
                throw new Exception('Database prepare error: ' . $conn->error);
            }

            $logbookText = '';
            $stmt->bind_param('sssss', $learnerID, $unitStandardExercise, $type, $filePath, $logbookText);

            if ($stmt->execute()) {
                $successCount = 1;
                $insertedExercises = [$unitStandardExercise];
                $insertedFiles = [$filePath];
                error_log("Successfully inserted unit standard upload: learnerID=$learnerID, exercise=$unitStandardExercise, type=$type, filePath=$filePath");
            } else {
                throw new Exception('Failed to insert unit standard upload: ' . $stmt->error);
            }

            $stmt->close();
        } else {
            // Regular bulk upload - insert each exercise with its corresponding file
            $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, filePath, logbook_text) VALUES (?, ?, ?, ?, ?)');
            if (!$stmt) {
                throw new Exception('Database prepare error: ' . $conn->error);
            }

            $successCount = 0;
            $insertedExercises = [];
            $insertedFiles = [];

            // Insert each exercise with its corresponding file
            for ($i = 0; $i < count($exercises); $i++) {
                $exercise = $exercises[$i];
                $filePath = $filePaths[$i];
                $logbookText = $isBulkUpload ? '' : ($logbookTexts[$i] ?? '');

                $stmt->bind_param('sssss', $learnerID, $exercise, $type, $filePath, $logbookText);

                if ($stmt->execute()) { 
                    $successCount++;
                    $insertedExercises[] = $exercise;
                    $insertedFiles[] = $filePath;
                    error_log("Successfully inserted: learnerID=$learnerID, exercise=$exercise, type=$type, filePath=$filePath");
                } else {
                    throw new Exception('Failed to insert exercise: ' . $exercise . ' - ' . $stmt->error);
                }
            }

            $stmt->close();
        }

        // Commit transaction
        $conn->commit();
        ob_end_clean();

        if ($isBulkUpload) {
            echo json_encode([
                'status' => 'success',
                'message' => "Bulk upload successful. $successCount exercises uploaded.",
                'exercises' => $insertedExercises,
                'files' => $insertedFiles,
                'upload_details' => [
                    'total_files' => count($uploadedFiles),
                    'total_exercises' => count($exercises),
                    'successful_uploads' => $successCount
                ]
            ]);
            error_log("Bulk upload completed successfully: $successCount exercises for learnerID=$learnerID, type=$type");
        } else {
            echo json_encode([
                'status' => 'success',
                'message' => 'Metadata and files saved successfully',
                'files' => $filePaths,
                'logbook_text' => $logbookTexts[0] ?? ''
            ]);
            error_log("Individual upload completed successfully: learnerID=$learnerID, exercise={$exercises[0]}, type=$type");
        }
    } catch (Exception $e) {
        // Rollback transaction
        $conn->rollback();
        error_log('Upload failed: ' . $e->getMessage());
        ob_end_clean();
        echo json_encode([
            'status' => 'error',
            'message' => 'Upload failed: ' . $e->getMessage()
        ]);

        // Clean up uploaded files
        foreach ($uploadedFiles as $file) {
            if (file_exists($file['path'])) {
                unlink($file['path']);
                error_log("Cleaned up file due to database failure: " . $file['path']);
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
