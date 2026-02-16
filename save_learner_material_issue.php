<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Include database connection
require_once 'connection.php';

try {
    // Get JSON input
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);

    if (!$data) {
        throw new Exception('Invalid JSON data received');
    }

    // Log received data for debugging
    error_log('Learner Material Issue - Received data: ' . print_r($data, true));

    // Validate required fields
    $requiredFields = ['classID', 'learnerID', 'learnerFullName', 'representativeFullName', 'description', 'quantity'];
    foreach ($requiredFields as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }

    // Extract data
    $classID = $data['classID'];
    $learnerID = $data['learnerID'];
    $learnerFullName = $data['learnerFullName'];
    $representativeFullName = $data['representativeFullName'];
    $description = $data['description'];
    $subDescription = isset($data['subDescription']) ? $data['subDescription'] : $description;
    $quantity = intval($data['quantity']);
    $qualificationName = isset($data['qualificationName']) ? $data['qualificationName'] : '';
    
    // Handle signatures
    $learnerSignature = isset($data['learnerSignature']) ? $data['learnerSignature'] : null;
    $representativeSignature = isset($data['representativeSignature']) ? $data['representativeSignature'] : null;

    // Validate quantity
    if ($quantity <= 0) {
        throw new Exception('Quantity must be greater than 0');
    }

    // Save signature files if provided
    $learnerSignaturePath = null;
    $representativeSignaturePath = null;

    if ($learnerSignature) {
        $learnerSignatureData = base64_decode($learnerSignature);
        $learnerSignaturePath = 'signatures/learner_' . $learnerID . '_' . time() . '.png';
        
        // Create signatures directory if it doesn't exist
        if (!file_exists('signatures')) {
            mkdir('signatures', 0777, true);
        }
        
        file_put_contents($learnerSignaturePath, $learnerSignatureData);
    }

    if ($representativeSignature) {
        $representativeSignatureData = base64_decode($representativeSignature);
        $representativeSignaturePath = 'signatures/rep_' . $learnerID . '_' . time() . '.png';
        
        // Create signatures directory if it doesn't exist
        if (!file_exists('signatures')) {
            mkdir('signatures', 0777, true);
        }
        
        file_put_contents($representativeSignaturePath, $representativeSignatureData);
    }

    // Prepare SQL statement for material_receipt_form table (changed table name only)
    $sql = "INSERT INTO material_receipt_form (
        classID, 
        learnerID, 
        learnerFullName, 
        representativeFullName, 
        description, 
        subDescription, 
        quantity, 
        qualificationName, 
        learnerSignature, 
        representativeSignature, 
        dateCreated
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Database prepare failed: ' . $conn->error);
    }

    $stmt->bind_param(
        'ssssssssss',
        $classID,
        $learnerID,
        $learnerFullName,
        $representativeFullName,
        $description,
        $subDescription,
        $quantity,
        $qualificationName,
        $learnerSignaturePath,
        $representativeSignaturePath
    );

    if (!$stmt->execute()) {
        throw new Exception('Database execution failed: ' . $stmt->error);
    }

    $insertId = $conn->insert_id;
    
    error_log("Learner Material Issue - Successfully saved with ID: $insertId");

    // Return success response
    echo json_encode([
        'success' => true,
        'message' => 'Material issued to learner successfully',
        'id' => $insertId,
        'data' => [
            'classID' => $classID,
            'learnerID' => $learnerID,
            'learnerFullName' => $learnerFullName,
            'description' => $description,
            'subDescription' => $subDescription,
            'quantity' => $quantity
        ]
    ]);

} catch (Exception $e) {
    error_log('Learner Material Issue Error: ' . $e->getMessage());
    
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'error_details' => [
            'file' => __FILE__,
            'line' => $e->getLine(),
            'trace' => $e->getTraceAsString()
        ]
    ]);
} finally {
    if (isset($stmt)) {
        $stmt->close();
    }
    if (isset($conn)) {
        $conn->close();
    }
}
?>