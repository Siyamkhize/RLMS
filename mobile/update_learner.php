<?php
include 'connection.php';

// Track which script is making database changes
if ($conn ?? false) {
    $conn->query("SET @script_name = 'mobile/update_learner.php'");
}

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
    // CRITICAL: Signatures and initials should ONLY be uploaded via dedicated endpoints
    $protectedFields = [
        'LearnerID',
        'classID',
        'synced',
        'signature',                    // FILE - only via save_signature.php
        'witness_signature',            // FILE - only via save_signature.php
        'learner_initials',             // TEXT - only via save_initials.php
        'witness_initials',             // TEXT - only via save_initials.php
        'profile_image',                // FILE - only via save_image.php
        'activity_statu',               // Only admins can set to Inactive
        'zkteco_right_template',        // Fingerprint data
        'zkteco_left_template',         // Fingerprint data
        'sourceafis_template',          // Fingerprint data
        'futronic_left_template',       // Fingerprint data
        'futronic_right_template',      // Fingerprint data
        'fingerprint_template',         // Fingerprint data
        'imagePath',                    // Legacy field
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
        // CRITICAL FAILSAFE: Get existing learner data from server FIRST
        // Never overwrite signature/initials if server has data
        $existingStmt = $conn->prepare("
            SELECT signature, witness_signature, learner_initials, witness_initials 
            FROM learnerdetails 
            WHERE LearnerID = ?
        ");
        $existingStmt->bind_param("s", $learnerID);
        $existingStmt->execute();
        $existingResult = $existingStmt->get_result();
        $existingData = $existingResult->fetch_assoc();
        $existingStmt->close();
        
        // PRESERVE EXISTING SIGNATURE DATA - Never allow NULL/empty to overwrite existing values
        if ($existingData) {
            $criticalFields = ['signature', 'witness_signature', 'learner_initials', 'witness_initials'];
            foreach ($criticalFields as $field) {
                // If server has data for this field, NEVER let update set it to null/empty
                if (!empty($existingData[$field])) {
                    if (isset($learnerUpdateData[$field]) && empty($learnerUpdateData[$field])) {
                        // Trying to set to empty/null - BLOCK IT and keep server value
                        unset($learnerUpdateData[$field]);
                        error_log("PROTECTION: Blocked attempt to clear $field for learner $learnerID via update_learner.php");
                    }
                }
            }
        }
        
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
