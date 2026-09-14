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

if (!$conn) {
    ob_end_clean();
    echo json_encode(['status' => 'error', 'message' => 'Database connection failed']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $learnerID = $_POST['learnerID'] ?? '';
    $type = $_POST['type'] ?? '';
    $exercise = $_POST['exercise'] ?? '';
    $submitted_at = $_POST['submitted_at'] ?? '';
    $logbookText = $_POST['logbook_text'] ?? '';
    
    // DEBUG: Log all received data
    error_log("=== SYNC_POEONLINE DEBUG START ===");
    error_log("learnerID: " . $learnerID);
    error_log("type: " . $type);
    error_log("exercise: " . $exercise);
    error_log("submitted_at: " . $submitted_at);
    error_log("logbook_text: " . $logbookText);
    error_log("FILES: " . print_r($_FILES, true));
    error_log("POST: " . print_r($_POST, true));
    
    // Check if exercise contains unit standard marker
    $isUnitStandardMarker = preg_match('/^All\s+(Formative|Summative)\s+Questions\s+-\s+(\d+)\s+-/', $exercise, $matches);
    
    error_log("Regex match result: " . ($isUnitStandardMarker ? 'MATCH' : 'NO MATCH'));
    if ($isUnitStandardMarker) {
        error_log("Unit Standard ID: " . $matches[2]);
        error_log("Assessment Type: " . $matches[1]);
    }
    
    if (empty($learnerID) || empty($exercise) || empty($type)) {
        error_log('Missing required fields: learnerID=' . $learnerID . ', exercise=' . $exercise . ', type=' . $type);
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'Missing required fields']);
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

    // Process file upload first
    $filePath = null;
    $uploadedFiles = [];
    $errors = [];
    
    if (isset($_FILES['file']) && $_FILES['file']['error'] === UPLOAD_ERR_OK) {
        $allowedExtensions = ['pdf'];
        $maxFileSize = 2 * 1024 * 1024; // 2MB
        $fileTmpPath = $_FILES['file']['tmp_name'];
        $fileSize = $_FILES['file']['size'];
        $fileName = $_FILES['file']['name'];
        
        error_log("Processing file: $fileName, Size: $fileSize bytes");

        // Validate file size
        if ($fileSize > $maxFileSize) {
            $errors[] = "File $fileName exceeds 2MB limit ($fileSize bytes)";
            error_log("File $fileName exceeds 2MB limit: $fileSize bytes");
        }

        // Validate file type
        $extension = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
        if (!in_array($extension, $allowedExtensions)) {
            $errors[] = "Invalid file type: $fileName. Allowed: " . implode(', ', $allowedExtensions);
            error_log('Invalid file type: ' . $fileName);
        }

        // Validate file exists and is readable
        if (!file_exists($fileTmpPath)) {
            $errors[] = "Temporary file does not exist: $fileName";
            error_log('Temporary file does not exist: ' . $fileTmpPath);
        }

        if (!is_readable($fileTmpPath)) {
            $errors[] = "Temporary file is not readable: $fileName";
            error_log('Temporary file is not readable: ' . $fileTmpPath);
        }

        // Validate file integrity
        if (filesize($fileTmpPath) === 0) {
            $errors[] = "Empty file uploaded: $fileName";
            error_log('Empty file uploaded: ' . $fileName);
        }

        if (empty($errors)) {
            // Define upload directory
            $uploadDir = 'POE/';
            
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

            // Generate unique filename
            // CRITICAL FIX: Remove ALL whitespace characters including tabs, newlines, etc.
            // Windows/XAMPP cannot handle tab characters (\t) in file paths
            $sanitizedName = preg_replace('/\s+/', '_', basename($fileName)); // Replace all whitespace with underscore
            $sanitizedName = preg_replace('/[^a-zA-Z0-9._-]/', '', $sanitizedName); // Remove special chars
            $uniqueFileName = uniqid() . '_' . $sanitizedName;
            $destinationPath = $uploadDir . $uniqueFileName;

            // Move file
            error_log('Attempting to move file from ' . $fileTmpPath . ' to ' . $destinationPath);
            if (move_uploaded_file($fileTmpPath, $destinationPath)) {
                $filePath = 'POE/' . $uniqueFileName;
                $uploadedFiles[] = [
                    'original_name' => $fileName,
                    'saved_name' => $uniqueFileName,
                    'path' => $filePath,
                    'size' => $fileSize
                ];
                error_log("File moved successfully: $fileName to $destinationPath");
            } else {
                $error = error_get_last();
                $errorMsg = 'Failed to move uploaded file: ' . $fileName . ' (Error: ' . ($error['message'] ?? 'Unknown') . ')';
                $errors[] = $errorMsg;
                error_log($errorMsg);
            }
        }
    } else {
        error_log('No file uploaded or upload error: ' . ($_FILES['file']['error'] ?? 'No file'));
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'No file uploaded or upload error']);
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
        $conn->close();
        exit;
    }

    if ($isUnitStandardMarker) {
        // UNIT STANDARD BULK UPLOAD - Expand to individual exercises
        $unitStandardId = $matches[2];
        $assessmentType = $matches[1];
        
        error_log("Processing unit standard bulk upload: unitStandardId=$unitStandardId, assessmentType=$assessmentType");
        
        // Get all individual exercises for this unit standard and assessment type
        $stmt = $conn->prepare("
            SELECT DISTINCT exercise 
            FROM assessments 
            WHERE unit_standard_id = ? AND LOWER(assessment_type) = LOWER(?)
        ");
        
        if (!$stmt) {
            error_log('Prepare failed for assessments lookup: ' . $conn->error);
            ob_end_clean();
            echo json_encode(['status' => 'error', 'message' => 'Database prepare error']);
            exit;
        }
        
        $stmt->bind_param('is', $unitStandardId, $assessmentType);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $individualExercises = [];
        while ($row = $result->fetch_assoc()) {
            $individualExercises[] = $row['exercise'];
        }
        $stmt->close();
        
        error_log("Found " . count($individualExercises) . " individual exercises for unit standard $unitStandardId");
        
        if (empty($individualExercises)) {
            error_log("No individual exercises found for unit_standard_id=$unitStandardId, assessment_type=$assessmentType");
            ob_end_clean();
            echo json_encode(['status' => 'error', 'message' => 'No exercises found for this unit standard']);
            exit;
        }
        
        // Check for duplicates using the individual exercises
        $placeholders = str_repeat('?,', count($individualExercises) - 1) . '?';
        $checkStmt = $conn->prepare("SELECT exercise FROM poe WHERE learnerID = ? AND type = ? AND exercise IN ($placeholders)");
        if (!$checkStmt) {
            error_log('Prepare failed for duplicate check: ' . $conn->error);
            ob_end_clean();
            echo json_encode(['status' => 'error', 'message' => 'Database prepare error']);
            exit;
        }
        
        $params = array_merge([$learnerID, $type], $individualExercises);
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
        
        // Begin transaction
        $conn->begin_transaction();

        try {
            // Insert one POE record for each individual exercise, reusing the same file
            $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, filePath, logbook_text, submitted_at) VALUES (?, ?, ?, ?, ?, ?)');
            if (!$stmt) {
                throw new Exception('Database prepare error: ' . $conn->error);
            }

            $successCount = 0;
            $insertedExercises = [];

            // Insert each individual exercise with the same file
            foreach ($individualExercises as $individualExercise) {
                $stmt->bind_param('ssssss', $learnerID, $individualExercise, $type, $filePath, $logbookText, $submitted_at);
                
                if ($stmt->execute()) {
                    $successCount++;
                    $insertedExercises[] = $individualExercise;
                    error_log("Successfully inserted: learnerID=$learnerID, exercise=$individualExercise, type=$type, filePath=$filePath");
                } else {
                    throw new Exception('Failed to insert exercise: ' . $individualExercise . ' - ' . $stmt->error);
                }
            }

            $stmt->close();

            // Commit transaction
            $conn->commit();

            ob_end_clean();
            
            echo json_encode([
                'status' => 'success',
                'success' => true,
                'message' => "Unit standard upload successful. $successCount exercises uploaded.",
                'exercises' => $insertedExercises,
                'files' => [$filePath],
                'upload_details' => [
                    'total_files' => 1,
                    'total_exercises' => count($individualExercises),
                    'successful_uploads' => $successCount,
                    'unit_standard_id' => $unitStandardId,
                    'assessment_type' => $assessmentType
                ]
            ]);
            error_log("Unit standard upload completed successfully: $successCount exercises for learnerID=$learnerID, type=$type, unit_standard_id=$unitStandardId");

        } catch (Exception $e) {
            // Rollback transaction
            $conn->rollback();
            
            error_log('Unit standard upload failed: ' . $e->getMessage());
            ob_end_clean();
            echo json_encode(['status' => 'error', 'message' => 'Upload failed: ' . $e->getMessage()]);
            
            // Clean up uploaded file
            if (file_exists($filePath)) {
                unlink($filePath);
                error_log("Cleaned up file due to database failure: " . $filePath);
            }
        }

    } else {
        // REGULAR INDIVIDUAL UPLOAD
        error_log("Processing regular individual upload: exercise=$exercise");
        
        // Check for duplicates
        $checkStmt = $conn->prepare("SELECT exercise FROM poe WHERE learnerID = ? AND type = ? AND exercise = ?");
        if (!$checkStmt) {
            error_log('Prepare failed: ' . $conn->error);
            ob_end_clean();
            echo json_encode(['status' => 'error', 'message' => 'Database prepare error']);
            exit;
        }
        
        $checkStmt->bind_param('sss', $learnerID, $type, $exercise);
        $checkStmt->execute();
        $checkResult = $checkStmt->get_result();
        
        if ($checkResult->num_rows > 0) {
            error_log('Duplicate exercise found: ' . $exercise);
            ob_end_clean();
            echo json_encode([
                'status' => 'error', 
                'message' => 'Exercise has already been answered: ' . $exercise
            ]);
            $conn->close();
            exit;
        }
        $checkStmt->close();

        // Begin transaction
        $conn->begin_transaction();

        try {
            // Insert single POE record
            $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, filePath, logbook_text, submitted_at) VALUES (?, ?, ?, ?, ?, ?)');
            if (!$stmt) {
                throw new Exception('Database prepare error: ' . $conn->error);
            }
            
            $stmt->bind_param('ssssss', $learnerID, $exercise, $type, $filePath, $logbookText, $submitted_at);
            
            if ($stmt->execute()) {
                error_log("Successfully inserted individual upload: learnerID=$learnerID, exercise=$exercise, type=$type, filePath=$filePath");
            } else {
                throw new Exception('Failed to insert individual upload: ' . $stmt->error);
            }
            
            $stmt->close();

            // Commit transaction
            $conn->commit();

            ob_end_clean();
            
            echo json_encode([
                'status' => 'success',
                'success' => true,
                'message' => 'Metadata and files saved successfully',
                'exercises' => [$exercise],
                'files' => [$filePath],
                'logbook_text' => $logbookText
            ]);
            error_log("Individual upload completed successfully: learnerID=$learnerID, exercise=$exercise, type=$type");

        } catch (Exception $e) {
            // Rollback transaction
            $conn->rollback();
            
            error_log('Individual upload failed: ' . $e->getMessage());
            ob_end_clean();
            echo json_encode(['status' => 'error', 'message' => 'Upload failed: ' . $e->getMessage()]);
            
            // Clean up uploaded file
            if (file_exists($filePath)) {
                unlink($filePath);
                error_log("Cleaned up file due to database failure: " . $filePath);
            }
        }
    }

    error_log("=== SYNC_POEONLINE DEBUG END ===");
    $conn->close();
} else {
    ob_end_clean();
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method']);
}

ob_end_flush();
?>