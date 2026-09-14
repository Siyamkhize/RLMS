<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Database connection
require_once 'connection.php';

// Get JSON input
$json = file_get_contents('php://input');
$data = json_decode($json, true);

// Validate required fields
$required_fields = ['learner_id', 'full_name', 'id_number', 'home_address', 'telephone'];
foreach ($required_fields as $field) {
    if (empty($data[$field])) {
        echo json_encode([
            'success' => false,
            'message' => "Missing required field: $field"
        ]);
        exit;
    }
}

// Function to save signature image
function saveSignatureImage($base64Data, $learnerID, $type) {
    if (empty($base64Data)) {
        return null;
    }
    
    // Create signatures directory if it doesn't exist
    $signaturesDir = __DIR__ . '/signatures';
    if (!file_exists($signaturesDir)) {
        mkdir($signaturesDir, 0755, true);
    }
    
    // Generate filename: guardian_signature_LEARNERID.png or guardian_witness_LEARNERID.png
    $filename = "guardian_{$type}_{$learnerID}.png";
    $filepath = $signaturesDir . '/' . $filename;
    
    // Decode base64 and save
    $imageData = base64_decode($base64Data);
    if ($imageData === false) {
        return null;
    }
    
    if (file_put_contents($filepath, $imageData)) {
        return $filename; // Return just the filename to store in database
    }
    
    return null;
}

try {
    $learnerID = $data['learner_id'];
    
    // Save signature images and get filenames
    $guardianSignatureFile = saveSignatureImage($data['signature'] ?? '', $learnerID, 'signature');
    $witnessSignatureFile = saveSignatureImage($data['witness_signature'] ?? '', $learnerID, 'witness');
    
    // Check if guardian record exists
    $check_sql = "SELECT guardian_id FROM guardian_details WHERE learner_id = ?";
    $check_stmt = $conn->prepare($check_sql);
    $check_stmt->bind_param("i", $learnerID);
    $check_stmt->execute();
    $result = $check_stmt->get_result();
    
    if ($result->num_rows > 0) {
        // Update existing record
        $sql = "UPDATE guardian_details SET 
                full_name = ?,
                id_number = ?,
                home_address = ?,
                postal_address = ?,
                telephone = ?,
                email = ?,
                signature = ?,
                witness_signature = ?,
                updated_at = NOW(),
                synced = 1
                WHERE learner_id = ?";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param(
            "ssssssssi",
            $data['full_name'],
            $data['id_number'],
            $data['home_address'],
            $data['postal_address'],
            $data['telephone'],
            $data['email'],
            $guardianSignatureFile,
            $witnessSignatureFile,
            $learnerID
        );
        
        if ($stmt->execute()) {
            echo json_encode([
                'success' => true,
                'message' => 'Guardian details updated successfully',
                'signature_file' => $guardianSignatureFile,
                'witness_signature_file' => $witnessSignatureFile
            ]);
        } else {
            throw new Exception('Failed to update guardian details');
        }
    } else {
        // Insert new record
        $sql = "INSERT INTO guardian_details (
                    learner_id, full_name, id_number, home_address, 
                    postal_address, telephone, email, signature, 
                    witness_signature, created_at, updated_at, synced
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW(), 1)";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param(
            "issssssss",
            $learnerID,
            $data['full_name'],
            $data['id_number'],
            $data['home_address'],
            $data['postal_address'],
            $data['telephone'],
            $data['email'],
            $guardianSignatureFile,
            $witnessSignatureFile
        );
        
        if ($stmt->execute()) {
            echo json_encode([
                'success' => true,
                'message' => 'Guardian details saved successfully',
                'guardian_id' => $conn->insert_id,
                'signature_file' => $guardianSignatureFile,
                'witness_signature_file' => $witnessSignatureFile
            ]);
        } else {
            throw new Exception('Failed to insert guardian details');
        }
    }
    
    $stmt->close();
    $check_stmt->close();
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
