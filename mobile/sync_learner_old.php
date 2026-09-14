<?php
include 'connection.php';

header('Content-Type: application/json');

/**
 * Strip device-specific path prefixes from image paths.
 * Converts: /data/user/0/com.example.rlmss/app_flutter/learnerImages_22433.png
 * To: learnerImages_22433.png
 * @param string|null $path The path that may contain device-specific prefixes
 * @return string|null Clean filename without device paths
 */
function stripDevicePath($path) {
    if ($path === null || $path === '') {
        return $path;
    }
    // Remove any device-specific path prefix and keep only the filename
    return basename($path);
}

/**
 * Save base64-encoded image to server storage.
 * @param string $base64Data Base64-encoded image data
 * @param string $subdir Subdirectory (e.g. 'learnerImages' or 'signatures')
 * @param string $prefix Filename prefix (e.g. 'learner_123')
 * @return string|null Relative path for DB (e.g. 'learnerImages/learner_123_1234567890.png') or null on failure
 */
function saveBase64Image($base64Data, $subdir, $prefix) {
    $decoded = base64_decode($base64Data, true);
    if ($decoded === false) {
        error_log("sync_learner: Failed to decode base64 image for $prefix");
        return null;
    }
    $dir = __DIR__ . '/' . $subdir;
    if (!is_dir($dir)) {
        if (!mkdir($dir, 0755, true)) {
            error_log("sync_learner: Failed to create directory $dir");
            return null;
        }
    }
    $ext = 'png';
    $filename = $prefix . '_' . time() . '.' . $ext;
    $filepath = $dir . '/' . $filename;
    if (file_put_contents($filepath, $decoded) === false) {
        error_log("sync_learner: Failed to save image to $filepath");
        return null;
    }
    return $subdir . '/' . $filename;
}

// Read JSON input
$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !is_array($input)) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid JSON input or not an array']);
    http_response_code(400);
    exit;
}

// Prepare response
$response = ['status' => 'success', 'message' => 'Data synchronized successfully', 'learners' => [], 'failed' => []];

try {
    // Begin transaction
    $conn->begin_transaction();

    foreach ($input as $item) {
        $learner = $item['learner'] ?? null;
        $bank = $item['bank'] ?? null;

        $isPartialUpdate = false;
        if ($learner && isset($learner['partial_update'])) {
            $partialRaw = strtolower(trim((string)$learner['partial_update']));
            $isPartialUpdate = in_array($partialRaw, ['1', 'true', 'yes'], true);
        }

        if (
            !$learner ||
            !isset($learner['IDNumber']) ||
            (!$isPartialUpdate && !isset($learner['classID']))
        ) {
            $response['failed'][] = ['IDNumber' => $learner['IDNumber'] ?? 'unknown', 'error' => 'Missing required learner fields'];
            continue;
        }

        // Check if learner already exists (based on IDNumber AND project to prevent duplicates within same project)
        // Join with classes and sites to get project context for proper duplicate checking
        $hasClassId = isset($learner['classID']) && $learner['classID'] !== null && $learner['classID'] !== '';
        if (!$hasClassId) {
            // No class context provided: resolve by ID only (safe only when unique).
            $stmt = $conn->prepare("
                SELECT LearnerID
                FROM learnerdetails
                WHERE IDNumber = ?
            ");
            $stmt->bind_param("s", $learner['IDNumber']);
        } else {
            $stmt = $conn->prepare("
                SELECT ld.LearnerID 
                FROM learnerdetails ld 
                JOIN classes c ON ld.classID = c.ClassID 
                JOIN sites s ON c.SiteID = s.SiteID 
                JOIN classes new_c ON new_c.ClassID = ?
                JOIN sites new_s ON new_c.SiteID = new_s.SiteID
                WHERE ld.IDNumber = ? 
                AND s.project_id = new_s.project_id 
                AND s.sdp_id = new_s.sdp_id
            ");
            $stmt->bind_param("is", $learner['classID'], $learner['IDNumber']);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        if (!$hasClassId && $result->num_rows > 1) {
            $response['failed'][] = [
                'IDNumber' => $learner['IDNumber'],
                'error' => 'Ambiguous IDNumber across multiple classes/projects. Provide classID.'
            ];
            $stmt->close();
            continue;
        }
        $existingLearner = $result->num_rows > 0 ? $result->fetch_assoc() : null;
        $stmt->close();

        // Process base64-encoded images from offline sync (save to server storage)
        $profileImagePath = null;
        $signaturePath = null;
        $witnessSignaturePath = null;

        $safeId = preg_replace('/[^a-zA-Z0-9]/', '_', $learner['IDNumber'] ?? 'unknown');
        if (!empty($learner['profile_image_base64'])) {
            $profileImagePath = saveBase64Image($learner['profile_image_base64'], 'learnerImages', 'learner_' . $safeId);
        }
        if (!empty($learner['signature_base64'])) {
            $signaturePath = saveBase64Image($learner['signature_base64'], 'signatures', 'learner_signature_' . $safeId);
        }
        if (!empty($learner['witness_signature_base64'])) {
            $witnessSignaturePath = saveBase64Image($learner['witness_signature_base64'], 'signatures', 'witness_signature_' . $safeId);
        }

        // For partial updates, never allow class reassignment via sync payload.
        // Class changes must go through assign_learner_to_class.php.

        // Prepare learner fields (use saved paths from base64, or existing URLs/paths)
        // Strip device-specific paths from profile_image, signature, and witness_signature
        $fields = [
            'Title' => $learner['Title'] ?? null,
            'Name' => $learner['Name'] ?? null,
            'Surname' => $learner['Surname'] ?? null,
            'IDNumber' => $learner['IDNumber'],
            'DateOfBirth' => $learner['DateOfBirth'] ?? null,
            'PhoneNumber' => $learner['PhoneNumber'] ?? null,
            'Email' => $learner['Email'] ?? null,
            'Age' => $learner['Age'] ?? null,
            'Gender' => $learner['Gender'] ?? null,
            'Race' => $learner['Race'] ?? null,
            'Language' => $learner['Language'] ?? null,
            'Disability' => $learner['Disability'] ?? null,
            'AddressLine1' => $learner['AddressLine1'] ?? null,
            'KinName' => $learner['KinName'] ?? null,
            'KinRelation' => $learner['KinRelation'] ?? null,
            'KinContact' => $learner['KinContact'] ?? null,
            'SchoolName' => $learner['SchoolName'] ?? null,
            'SchoolCompletion' => $learner['SchoolCompletion'] ?? null,
            'SchoolLocation' => $learner['SchoolLocation'] ?? null,
            'SchoolGrade' => $learner['SchoolGrade'] ?? null,
            // Keep classID only for non-partial sync payloads.
            'classID' => $isPartialUpdate ? null : ($learner['classID'] ?? null),
            'profile_image' => $profileImagePath ?? stripDevicePath($learner['profile_image']) ?? null,
            'signature' => $signaturePath ?? stripDevicePath($learner['signature']) ?? null,
            'synced' => 1, // Server marks as synced
            'zkteco_left_template' => $learner['zkteco_left_template'] ?? null,
            'zkteco_right_template' => $learner['zkteco_right_template'] ?? null,
            'futronic_left_template' => $learner['futronic_left_template'] ?? null,
            'futronic_right_template' => $learner['futronic_right_template'] ?? null,
            'imagePath' => $learner['imagePath'] ?? null,
            'isLeftHand' => $learner['isLeftHand'] ?? null,
            'AddressLine2' => $learner['AddressLine2'] ?? null,
            'AddressLine3' => $learner['AddressLine3'] ?? null,
            'PostalCode' => $learner['PostalCode'] ?? null,
            'activity_statu' => $learner['activity_statu'] ?? 'Inactive',
            'witness_initials' => $learner['witness_initials'] ?? null,
            'learner_initials' => $learner['learner_initials'] ?? null,
            'witness_signature' => $witnessSignaturePath ?? stripDevicePath($learner['witness_signature']) ?? null,
        ];

        $serverLearnerId = null;
        if ($existingLearner) {
            // Existing learners must keep their assigned class.
            unset($fields['classID']);
            // Update existing record
            $serverLearnerId = $existingLearner['LearnerID'];
            $updateFields = [];
            $params = [];
            $types = '';
            foreach ($fields as $key => $value) {
                if ($value !== null) {
                    $updateFields[] = "$key = ?";
                    $params[] = $value;
                    $types .= ($key === 'classID' || $key === 'Age' || $key === 'synced') ? 'i' : 's';
                }
            }
            $query = "UPDATE learnerdetails SET " . implode(', ', $updateFields) . " WHERE LearnerID = ?";
            $params[] = $serverLearnerId;
            $types .= 'i';

            $stmt = $conn->prepare($query);
            $stmt->bind_param($types, ...$params);
            if (!$stmt->execute()) {
                $response['failed'][] = ['IDNumber' => $learner['IDNumber'], 'error' => $conn->error];
                $stmt->close();
                continue;
            }
            $stmt->close();
        } else {
            // Partial payloads must never create new learners because class ownership is mandatory.
            if ($isPartialUpdate) {
                $response['failed'][] = [
                    'IDNumber' => $learner['IDNumber'],
                    'error' => 'Partial update cannot insert new learner without explicit class assignment'
                ];
                continue;
            }

            if (!isset($learner['classID']) || $learner['classID'] === null || $learner['classID'] === '') {
                $response['failed'][] = [
                    'IDNumber' => $learner['IDNumber'],
                    'error' => 'classID is required to insert new learner'
                ];
                continue;
            }

            // Insert new record - this will generate auto-incremented LearnerID
            $columns = array_keys($fields);
            $placeholders = array_fill(0, count($fields), '?');
            $query = "INSERT INTO learnerdetails (" . implode(', ', $columns) . ") VALUES (" . implode(', ', $placeholders) . ")";
            $stmt = $conn->prepare($query);
            $params = array_values($fields);
            
            // Build type string dynamically
            $types = '';
            foreach ($fields as $key => $value) {
                $types .= ($key === 'classID' || $key === 'Age' || $key === 'synced') ? 'i' : 's';
            }
            
            $stmt->bind_param($types, ...$params);
            if (!$stmt->execute()) {
                $response['failed'][] = ['IDNumber' => $learner['IDNumber'], 'error' => $conn->error];
                $stmt->close();
                continue;
            }
            $serverLearnerId = $conn->insert_id; // Get the auto-generated ID
            $stmt->close();
        }

        // Process bank details if provided
        $bankId = null;
        if ($bank && isset($bank['BankName']) && isset($bank['BankAccount'])) {
            // Check if bank record exists for this learner
            $stmt = $conn->prepare("SELECT BankID FROM bankdetails WHERE LearnerID = ?");
            $stmt->bind_param("i", $serverLearnerId);
            $stmt->execute();
            $result = $stmt->get_result();
            $existingBank = $result->num_rows > 0 ? $result->fetch_assoc() : null;
            $stmt->close();

            $bankFields = [
                'LearnerID' => $serverLearnerId,
                'BankName' => $bank['BankName'],
                'bankType' => $bank['bankType'] ?? null,
                'BankAccount' => $bank['BankAccount'],
                'BankCode' => $bank['BankCode'] ?? null,
                'synced' => 1,
            ];

            if ($existingBank) {
                // Update bank record
                $bankId = $existingBank['BankID'];
                $updateFields = [];
                $params = [];
                $types = '';
                foreach ($bankFields as $key => $value) {
                    if ($value !== null) {
                        $updateFields[] = "$key = ?";
                        $params[] = $value;
                        $types .= ($key === 'LearnerID' || $key === 'synced') ? 'i' : 's';
                    }
                }
                $query = "UPDATE bankdetails SET " . implode(', ', $updateFields) . " WHERE BankID = ?";
                $params[] = $bankId;
                $types .= 'i';

                $stmt = $conn->prepare($query);
                $stmt->bind_param($types, ...$params);
                if (!$stmt->execute()) {
                    $response['failed'][] = ['IDNumber' => $learner['IDNumber'], 'error' => 'Bank update error: ' . $conn->error];
                    $stmt->close();
                    continue;
                }
                $stmt->close();
            } else {
                // Insert new bank record
                $columns = array_keys($bankFields);
                $placeholders = array_fill(0, count($bankFields), '?');
                $query = "INSERT INTO bankdetails (" . implode(', ', $columns) . ") VALUES (" . implode(', ', $placeholders) . ")";
                $stmt = $conn->prepare($query);
                $params = array_values($bankFields);
                $types = 'issssi'; // LearnerID (i), BankName (s), bankType (s), BankAccount (s), BankCode (s), synced (i)
                $stmt->bind_param($types, ...$params);
                if (!$stmt->execute()) {
                    $response['failed'][] = ['IDNumber' => $learner['IDNumber'], 'error' => 'Bank insert error: ' . $conn->error];
                    $stmt->close();
                    continue;
                }
                $bankId = $conn->insert_id;
                $stmt->close();
            }
        }

        // Add to successful learners with the server-generated IDs
        $response['learners'][] = [
            'LearnerID' => $serverLearnerId, // Fixed typo from $serverLearnernd
            'IDNumber' => $learner['IDNumber'],
            'BankID' => $bankId
        ];
    }

    // Commit transaction
    $conn->commit();
    
    // Log successful sync
    error_log("Sync completed successfully. Processed " . count($response['learners']) . " learners.");
    
} catch (Exception $e) {
    $conn->rollback();
    error_log("Sync failed: " . $e->getMessage());
    $response = ['status' => 'error', 'message' => 'Server error: ' . $e->getMessage(), 'learners' => [], 'failed' => []];
    http_response_code(500);
}

echo json_encode($response);
$conn->close();
?>