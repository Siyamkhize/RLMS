<?php
// Database connection
include('connection.php');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

// Enable error reporting for debugging
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Check connection
if ($conn->connect_error) {
    echo json_encode(['success' => false, 'message' => 'Connection failed: ' . $conn->connect_error]);
    exit;
}

$conn->begin_transaction();

try {
    // Get JSON input
    $data = json_decode(file_get_contents('php://input'), true);
    if (!$data) {
        throw new Exception('Invalid JSON input');
    }

    // Extract class and learner data
    $classID = $data['classID'] ?? null;
    $learners = $data['learners'] ?? [];
    $facilitatorName = $data['facilitator_name'] ?? '';

    if (empty($classID)) {
        throw new Exception('Class ID is required');
    }

    if (empty($learners) || !is_array($learners)) {
        throw new Exception('Learners data is missing or invalid');
    }

    // Directory to store signatures (if any)
    $signatureDir = "reports/signature/";
    if (!file_exists($signatureDir)) {
        mkdir($signatureDir, 0777, true);
    }

    // Function to save base64-encoded images (for signatures)
    function saveBase64Image($base64, $filePath) {
        if (!empty($base64)) {
            file_put_contents($filePath, base64_decode($base64));
            return $filePath;
        }
        return '';
    }

    $existingLearners = [];

    // Process each learner
    foreach ($learners as $learner) {
        $name = $learner['Name'] ?? '';
        $idNumber = $learner['IDNumber'] ?? '';
        $learnerId = $learner['learnerID'] ?? '';
        $className = $learner['ClassName'] ?? '';
        $received = $learner['Received'] === 'Yes' ? 'Yes' : 'No';
        $quantity = intval($learner['Quantity'] ?? 0);
        $description = $learner['description'] ?? '';
        $subDescription = $learner['sub_description'] ?? ($learner['subDescription'] ?? '');
        $dateReceived = $learner['Date'] ?? $learner['date_received'] ?? date('Y-m-d');
        $dateAorCreated = $learner['date_aor_created'] ?? date('Y-m-d');
        $practitionerFullName = $learner['practitioner_full_name'] ?? $facilitatorName;
        $signatureBase64 = $learner['Signature'] ?? null;
        $facilitatorSignatureBase64 = $learner['facilitator_signature'] ?? null;

        if (empty($name) || empty($idNumber)) {
            throw new Exception("Missing required fields for learner: $name");
        }

        if ($received !== 'Yes') {
            continue; // Skip if not marked as "Received"
        }

        // Check if the record already exists based on student_id_number, class_name and description
        $stmtCheck = $conn->prepare("
            SELECT id FROM material_receipt_form 
            WHERE (student_id_number = ? OR learnerID = ?) AND class_name = ? AND description = ?
        ");
        $stmtCheck->bind_param("ssss", $idNumber, $learnerId, $className, $description);
        $stmtCheck->execute();
        $stmtCheck->store_result();
        
        $exists = $stmtCheck->num_rows > 0;
        $stmtCheck->close();

        // Save learner's signature (if available)
        $learnerSignature = '';
        if ($signatureBase64) {
            $learnerSignature = 'learner_' . $idNumber . '_' . time() . '.png';
            saveBase64Image($signatureBase64, $signatureDir . $learnerSignature);
        }
        
        // Save facilitator signature (if available)
        $facilitatorSignature = '';
        if ($facilitatorSignatureBase64) {
            $facilitatorSignature = 'facilitator_' . $idNumber . '_' . time() . '.png';
            saveBase64Image($facilitatorSignatureBase64, $signatureDir . $facilitatorSignature);
        }

        if ($exists) {
            // Update existing record
            $stmtUpdate = $conn->prepare("
                UPDATE material_receipt_form 
                SET student_full_name = ?, received = ?, quantity = ?, 
                    sub_description = ?, practitioner_full_name = ?, 
                    facilitator_signature = ?, date_aor_created = ?,
                    date_received = ?, learner_signature = ?, synced = ?
                WHERE (student_id_number = ? OR learnerID = ?) AND class_name = ? AND description = ?
            ");
            $stmtUpdate->bind_param(
                "ssisssssssss",
                $name, $received, $quantity, $subDescription, $practitionerFullName,
                $facilitatorSignature, $dateAorCreated, $dateReceived, $learnerSignature, 1,
                $idNumber, $learnerId, $className, $description
            );
            if (!$stmtUpdate->execute()) {
                throw new Exception("Failed to update data for learner: $name. Error: " . $stmtUpdate->error);
            }
            $stmtUpdate->close();
        } else {
            // Insert new record
            $stmtMaterialReceipt = $conn->prepare("
                INSERT INTO material_receipt_form (
                    student_id_number, student_full_name, learnerID, class_name, received, quantity, description, 
                    sub_description, date_received, date_aor_created, practitioner_full_name, 
                    learner_signature, facilitator_signature, synced
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");

            if ($stmtMaterialReceipt === false) {
                throw new Exception("SQL Error: " . $conn->error);
            }

            // Bind the parameters
            $synced = 1; // Set the synced field to 1
            $stmtMaterialReceipt->bind_param(
                "ssssissssssssi",
                $idNumber, $name, $learnerId, $className, $received, $quantity, $description,
                $subDescription, $dateReceived, $dateAorCreated, $practitionerFullName,
                $learnerSignature, $facilitatorSignature, $synced
            );

            if (!$stmtMaterialReceipt->execute()) {
                throw new Exception("Failed to insert data for learner: $name. Error: " . $stmtMaterialReceipt->error);
            }
            $stmtMaterialReceipt->close();
        }
    }

    // Commit transaction
    $conn->commit();

    // If there are any existing learners, return their names
    if (count($existingLearners) > 0) {
        echo json_encode([
            'success' => true, 
            'message' => 'Data submitted successfully, but the following learners already exist with the same description: ' . implode(', ', $existingLearners)
        ]);
    } else {
        echo json_encode(['success' => true, 'message' => 'Data submitted successfully']);
    }

} catch (Exception $e) {
    // Rollback transaction if an error occurs
    $conn->rollback();
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}

// Close the connection
$conn->close();
?>
