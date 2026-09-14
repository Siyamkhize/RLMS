<?php
include('connection.php');
$signatureDir = 'reports/signature/';
if (!is_dir($signatureDir)) {
    mkdir($signatureDir, 0777, true);
    file_put_contents('debug.log', "Created directory $signatureDir\n", FILE_APPEND);
}

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Database connection failed: " . $conn->connect_error]));
}

function saveSignatureFile($file, $signatureDir, $student_id_number, $description) {
    if (isset($file) && is_array($file) && $file['error'] == UPLOAD_ERR_OK) {
        $fileExtension = pathinfo($file['name'], PATHINFO_EXTENSION);
        $allowedExtensions = ['png', 'jpeg', 'jpg'];
        if (!in_array(strtolower($fileExtension), $allowedExtensions)) {
            file_put_contents('debug.log', "Invalid file format for $student_id_number: $fileExtension\n", FILE_APPEND);
            return null;
        }

        $sanitizedDescription = preg_replace('/[^a-zA-Z0-9]/', '_', $description);
        $fileName = "learner_signature_{$student_id_number}_{$sanitizedDescription}.png";
        $filePath = $signatureDir . $fileName;

        if (move_uploaded_file($file['tmp_name'], $filePath)) {
            file_put_contents('debug.log', "Successfully moved file to $filePath\n", FILE_APPEND);
            return $filePath;
        } else {
            file_put_contents('debug.log', "Failed to move file to $filePath\n", FILE_APPEND);
            return null;
        }
    }
    file_put_contents('debug.log', "File upload error or missing for $student_id_number: " . ($file['error'] ?? 'No file') . "\n", FILE_APPEND);
    return null;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    file_put_contents('debug.log', "Received POST request. FILES: " . print_r($_FILES, true) . "\n", FILE_APPEND);
    if (!isset($_POST['data'])) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'No data received']);
        exit;
    }

    $inputData = json_decode($_POST['data'], true);
    if (!is_array($inputData)) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid JSON format']);
        exit;
    }

    $conn->begin_transaction();
    try {
        foreach ($inputData as $index => $record) {
            if (!is_array($record)) {
                file_put_contents('debug.log', "Skipping non-array record at index $index\n", FILE_APPEND);
                continue;
            }

            $requiredFields = ['student_id_number', 'student_full_name', 'class_name', 'received', 'quantity', 'description', 'date_received'];
            foreach ($requiredFields as $field) {
                if (!isset($record[$field]) || empty($record[$field])) {
                    file_put_contents('debug.log', "Missing required field '$field' at index $index\n", FILE_APPEND);
                    continue 2;
                }
            }

            $student_id_number = trim($record['student_id_number']);
            $student_full_name = trim($record['student_full_name']);
            $class_name = trim($record['class_name']);
            $received = trim($record['received']);
            $quantity = (int)($record['quantity'] ?? 1);
            $description = trim($record['description']);
            $date_received = trim($record['date_received']);
            $practitioner_full_name = trim($record['practitioner_full_name'] ?? '');
            $created_at = trim($record['created_at'] ?? '');
            $synced = 1;

            $stmtCheck = $conn->prepare("SELECT id FROM material_receipt_form WHERE student_id_number = ? AND description = ?");
            $stmtCheck->bind_param("ss", $student_id_number, $description);
            $stmtCheck->execute();
            $resultCheck = $stmtCheck->get_result();
            if ($resultCheck->num_rows > 0) {
                $stmtCheck->close();
                file_put_contents('debug.log', "Duplicate record skipped for $student_id_number, $description\n", FILE_APPEND);
                continue;
            }
            $stmtCheck->close();

            $learnerSignaturePath = null;
            if (isset($_FILES['signature']['name'][$index])) {
                $signatureFile = [
                    'name' => $_FILES['signature']['name'][$index],
                    'type' => $_FILES['signature']['type'][$index],
                    'tmp_name' => $_FILES['signature']['tmp_name'][$index],
                    'error' => $_FILES['signature']['error'][$index],
                    'size' => $_FILES['signature']['size'][$index],
                ];
                $learnerSignaturePath = saveSignatureFile($signatureFile, $signatureDir, $student_id_number, $description);
            }

            $stmt = $conn->prepare("INSERT INTO material_receipt_form (
                    student_id_number, student_full_name, class_name, received, quantity,
                    description, date_received, practitioner_full_name, learner_signature,
                    created_at, synced
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->bind_param(
                'ssssisssssi',
                $student_id_number,
                $student_full_name,
                $class_name,
                $received,
                $quantity,
                $description,
                $date_received,
                $practitioner_full_name,
                $learnerSignaturePath,
                $created_at,
                $synced
            );

            if (!$stmt->execute()) {
                throw new Exception("Failed to insert record for $student_id_number: " . $stmt->error);
            }
            $stmt->close();
        }

        $conn->commit();
        echo json_encode(['status' => 'success', 'message' => 'Data synced successfully']);
    } catch (Exception $e) {
        $conn->rollback();
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
} else {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method']);
}

$conn->close();
?>