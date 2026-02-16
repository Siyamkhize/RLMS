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
        $className = $learner['ClassName'] ?? '';
        $received = $learner['Received'] === 'Yes' ? 'Yes' : 'No';
        $quantity = intval($learner['Quantity'] ?? 0);
        $description = $learner['description'] ?? '';
        $dateReceived = $learner['Date'] ?? date('Y-m-d');
        $signatureBase64 = $learner['Signature'] ?? null;

        if (empty($name) || empty($idNumber)) {
            throw new Exception("Missing required fields for learner: $name");
        }

        if ($received !== 'Yes') {
            continue; // Skip if not marked as "Received"
        }

        // Check if the record already exists based on student_id_number and description
        $stmtCheck = $conn->prepare("
            SELECT description FROM material_receipt_form 
            WHERE student_id_number = ?
        ");
        $stmtCheck->bind_param("s", $idNumber);
        $stmtCheck->execute();
        $stmtCheck->store_result();
        $stmtCheck->bind_result($existingDescription);

        $descriptionExists = false;

        // Fetch existing descriptions
        while ($stmtCheck->fetch()) {
            if ($existingDescription === $description) {
                $descriptionExists = true; // The same description already exists
                break;
            }
        }

        $stmtCheck->close();

        // If the student already has the same description, do not insert a new record
        if ($descriptionExists) {
            $existingLearners[] = $name; // Add the name to the list of existing learners
            continue;
        }

        // Save learner's signature (if available)
        $learnerSignature = 'learner_' . $idNumber . '.png';
        $learnerSignatureFilePath = saveBase64Image($signatureBase64, $signatureDir . $learnerSignature);

        // Insert into material_receipt_form table
        $stmtMaterialReceipt = $conn->prepare("
            INSERT INTO material_receipt_form (
                student_id_number, student_full_name, class_name, received, quantity, description, 
                date_received, practitioner_full_name, learner_signature, synced
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");

        if ($stmtMaterialReceipt === false) {
            throw new Exception("SQL Error: " . $conn->error);
        }

        // Bind the parameters
        $synced = 1; // Set the synced field to 1 (or 0 if needed)
        $stmtMaterialReceipt->bind_param(
            "ssssissssi",
            $idNumber, $name, $className, $received, $quantity, $description, $dateReceived,
            $facilitatorName, $learnerSignature, $synced
        );

        if (!$stmtMaterialReceipt->execute()) {
            throw new Exception("Failed to insert data for learner: $name. Error: " . $stmtMaterialReceipt->error);
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
