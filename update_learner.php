<?php
include 'connection.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid JSON input']);
        exit;
    }

    // Validate required fields
    if (!isset($input['LearnerID']) || empty($input['LearnerID'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'LearnerID is required']);
        exit;
    }

    if (!isset($input['data']) || !is_array($input['data']) || empty($input['data'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'No data provided for update']);
        exit;
    }

    $learnerID = $input['LearnerID'];
    $updateData = $input['data'];

    // Fields that should NOT be updated (security and system-managed fields)
    $protectedFields = [
        'LearnerID',
        'classID',
        'synced',
        'signature',
        'zkteco_right_template',
        'imagePath',
        'zkteco_left_template',
        'activity_statu',
        'witness_initials',
        'learner_initials',
        'witness_signature',
        'sourceafis_template',
        'futronic_left_template',
        'futronic_right_template',
        'profile_image',
    ];
    
    // Fields that belong to bankdetails table
    $bankFields = ['BankName', 'bankType', 'BankAccount', 'BankCode'];
    
    // Separate learner data from bank data
    $learnerUpdateData = [];
    $bankUpdateData = [];
    
    foreach ($updateData as $key => $value) {
        // Skip protected fields
        if (in_array($key, $protectedFields)) {
            continue;
        }
        
        // Separate bank fields
        if (in_array($key, $bankFields)) {
            $bankUpdateData[$key] = $value;
        } else {
            $learnerUpdateData[$key] = $value;
        }
    }

    // Start transaction
    $conn->begin_transaction();

    try {
        // Update learnerdetails table if there's data
        if (!empty($learnerUpdateData)) {
            $updateFields = [];
            $updateValues = [];
            $updateTypes = '';

            foreach ($learnerUpdateData as $key => $value) {
                $updateFields[] = "`$key` = ?";
                $updateValues[] = $value;
                $updateTypes .= 's'; // Treat all as strings for simplicity
            }

            // Add LearnerID for WHERE clause
            $updateValues[] = $learnerID;
            $updateTypes .= 's';

            $sql = "UPDATE learnerdetails SET " . implode(', ', $updateFields) . " WHERE LearnerID = ?";
            $stmt = $conn->prepare($sql);
            
            if (!$stmt) {
                throw new Exception("Failed to prepare learner update statement: " . $conn->error);
            }

            $stmt->bind_param($updateTypes, ...$updateValues);
            
            if (!$stmt->execute()) {
                throw new Exception("Failed to update learner details: " . $stmt->error);
            }

            $stmt->close();
        }

        // Update bankdetails table if there's bank data
        if (!empty($bankUpdateData)) {
            // Check if bank record exists
            $checkStmt = $conn->prepare("SELECT LearnerID FROM bankdetails WHERE LearnerID = ?");
            $checkStmt->bind_param("s", $learnerID);
            $checkStmt->execute();
            $checkResult = $checkStmt->get_result();
            $bankExists = $checkResult->num_rows > 0;
            $checkStmt->close();

            if ($bankExists) {
                // Update existing bank record
                $updateFields = [];
                $updateValues = [];
                $updateTypes = '';

                foreach ($bankUpdateData as $key => $value) {
                    $updateFields[] = "`$key` = ?";
                    $updateValues[] = $value;
                    $updateTypes .= 's';
                }

                // Add LearnerID for WHERE clause
                $updateValues[] = $learnerID;
                $updateTypes .= 's';

                $sql = "UPDATE bankdetails SET " . implode(', ', $updateFields) . " WHERE LearnerID = ?";
                $stmt = $conn->prepare($sql);
                
                if (!$stmt) {
                    throw new Exception("Failed to prepare bank update statement: " . $conn->error);
                }

                $stmt->bind_param($updateTypes, ...$updateValues);
                
                if (!$stmt->execute()) {
                    throw new Exception("Failed to update bank details: " . $stmt->error);
                }

                $stmt->close();
            } else {
                // Insert new bank record
                $bankUpdateData['LearnerID'] = $learnerID;
                
                $insertFields = array_keys($bankUpdateData);
                $insertPlaceholders = array_fill(0, count($insertFields), '?');
                $insertValues = array_values($bankUpdateData);
                $insertTypes = str_repeat('s', count($insertValues));

                $sql = "INSERT INTO bankdetails (" . implode(', ', $insertFields) . ") VALUES (" . implode(', ', $insertPlaceholders) . ")";
                $stmt = $conn->prepare($sql);
                
                if (!$stmt) {
                    throw new Exception("Failed to prepare bank insert statement: " . $conn->error);
                }

                $stmt->bind_param($insertTypes, ...$insertValues);
                
                if (!$stmt->execute()) {
                    throw new Exception("Failed to insert bank details: " . $stmt->error);
                }

                $stmt->close();
            }
        }

        // Commit transaction
        $conn->commit();

        // Return success response
        echo json_encode([
            'success' => true,
            'message' => 'Learner information updated successfully',
            'updated_fields' => array_merge(array_keys($learnerUpdateData), array_keys($bankUpdateData))
        ]);

    } catch (Exception $e) {
        // Rollback transaction on error
        $conn->rollback();
        throw $e;
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error updating learner: ' . $e->getMessage()
    ]);
    error_log("Update learner error: " . $e->getMessage());
}

$conn->close();
?>
