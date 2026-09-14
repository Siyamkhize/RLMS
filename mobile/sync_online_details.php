<?php

// Track which script is making database changes
if ($conn ?? false) {
    $conn->query("SET @script_name = 'sync_online_details.php'");
}

require_once __DIR__ . '/../security_functions.php';
header('Content-Type: application/json');
include 'connection.php';

/**
 * Save base64-encoded image to server storage.
 * @param string $base64Data Base64-encoded image data
 * @param string $subdir Subdirectory (e.g. 'learnerImages' or 'signatures')
 * @param string $prefix Filename prefix (e.g. 'learner_123')
 * @return string|null Filename (not path) for DB or null on failure
 */
function saveBase64Image($base64Data, $subdir, $prefix) {
    $decoded = base64_decode($base64Data, true);
    if ($decoded === false) {
        error_log("sync_online_details: Failed to decode base64 image for $prefix");
        return null;
    }
    $dir = __DIR__ . '/' . $subdir;
    if (!is_dir($dir)) {
        if (!mkdir($dir, 0755, true)) {
            error_log("sync_online_details: Failed to create directory $dir");
            return null;
        }
    }
    $ext = 'png';
    $filename = $prefix . '_' . time() . '.' . $ext;
    $filepath = $dir . '/' . $filename;
    if (file_put_contents($filepath, $decoded) === false) {
        error_log("sync_online_details: Failed to save image to $filepath");
        return null;
    }
    return $filename; // Return only filename, not full path
}

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

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception("Invalid request method.");
    }

    // Helper function to safely get POST values
    function getPost($key) {
        return isset($_POST[$key]) ? trim($_POST[$key]) : null;
    }

    $IDNumber = getPost('IDNumber');
    $classID = getPost('classID');
    $partialRaw = strtolower((string)(getPost('partial_update') ?? 'false'));
    $isPartialUpdate = in_array($partialRaw, ['1', 'true', 'yes'], true);

    if (!$IDNumber) {
        throw new Exception("Missing required field: IDNumber.");
    }

    // Extract all values
    $data = [
        'Title' => getPost('Title'),
        'Name' => getPost('Name'),
        'Surname' => getPost('Surname'),
        'IDNumber' => $IDNumber,
        'DateOfBirth' => getPost('DateOfBirth'),
        'PhoneNumber' => getPost('PhoneNumber'),
        'Email' => getPost('Email'),
        'Age' => getPost('Age'),
        'Gender' => getPost('Gender'),
        'Race' => getPost('Race'),
        'Language' => getPost('Language'),
        'Disability' => getPost('Disability'),
        'AddressLine1' => getPost('AddressLine1'),
        'AddressLine2' => getPost('AddressLine2'),
        'AddressLine3' => getPost('AddressLine3'),
        'PostalCode' => getPost('PostalCode'),
        'KinName' => getPost('KinName'),
        'KinRelation' => getPost('KinRelation'),
        'KinContact' => getPost('KinContact'),
        'SchoolName' => getPost('SchoolName'),
        'SchoolCompletion' => getPost('SchoolCompletion'),
        'SchoolLocation' => getPost('SchoolLocation'),
        'SchoolGrade' => getPost('SchoolGrade'),
        // classID is handled separately - never update via sync (partial or full)
        'synced' => 1,
        'activity_statu' => getPost('activity_statu'),
        'witness_initials' => getPost('witness_initials'),
        'learner_initials' => getPost('learner_initials'),
        'fingerprint_template' => getPost('fingerprint_template'),
        'imagePath' => getPost('imagePath'),
        'isLeftHand' => getPost('isLeftHand')
    ];

    // Upload file helpers - ONLY CORRECT FOLDERS (NO uploads/ FOLDER!)
    function saveUploadedFile($fileKey, $learnerID, $fieldType) {
        if (!isset($_FILES[$fileKey]) || $_FILES[$fileKey]['error'] !== UPLOAD_ERR_OK) {
            return null;
        }
        
        // Determine correct folder based on field type - NO FALLBACK TO uploads/
        if ($fieldType === 'profile_image') {
            $targetFolder = 'learnerImages';
        } elseif ($fieldType === 'signature' || $fieldType === 'witness_signature') {
            $targetFolder = 'signatures';
        } else {
            // Unknown field type - reject it
            error_log("UPLOAD_ERROR: Unknown field type '$fieldType' for learner $learnerID");
            return null;
        }
        
        // Create folder if it doesn't exist
        if (!is_dir($targetFolder)) {
            mkdir($targetFolder, 0755, true);
        }
        
        // Generate simple filename - ONLY filename.extension (no paths, no timestamps)
        // Format: fieldtype_learnerID.ext (e.g., profile_image_11453.jpg, signature_11453.png)
        $ext = pathinfo($_FILES[$fileKey]['name'], PATHINFO_EXTENSION);
        $filename = $fieldType . '_' . $learnerID . '.' . $ext;
        $targetPath = $targetFolder . '/' . $filename;
        
        if (move_uploaded_file($_FILES[$fileKey]['tmp_name'], $targetPath)) {
            return $filename; // Return ONLY filename, NOT full path
        }
        
        return null;
    }

    $IDNumberForFiles = $IDNumber ?? 'unknown';
    
    // Handle file uploads - strip device paths and keep ONLY filename
    $uploadedProfileImage = saveUploadedFile('profile_image', $IDNumberForFiles, 'profile_image');
    $uploadedSignature = saveUploadedFile('signature', $IDNumberForFiles, 'signature');
    $uploadedWitnessSignature = saveUploadedFile('witness_signature', $IDNumberForFiles, 'witness_signature');
    
    // Clean incoming POST data - remove device paths like /data/user/0/...
    $data['profile_image'] = $uploadedProfileImage ?? stripDevicePath(getPost('profile_image'));
    $data['signature'] = $uploadedSignature ?? stripDevicePath(getPost('signature'));
    $data['witness_signature'] = $uploadedWitnessSignature ?? stripDevicePath(getPost('witness_signature'));

    // Check if learner exists by IDNumber
    $check = $conn->prepare("SELECT * FROM learnerdetails WHERE IDNumber = ?");
    $check->bind_param("s", $IDNumber);
    $check->execute();
    $checkResult = $check->get_result();

    if ($checkResult->num_rows > 0) {
        // CRITICAL FIX: Preserve ALL existing data if not provided in update
        $existing = $checkResult->fetch_assoc();
        $learnerId = $existing['LearnerID'];
        
        // PROCESS BASE64 SIGNATURES FROM OFFLINE SYNC
        // If app sends signature_base64/witness_signature_base64, save them to signatures/ folder
        $signaturePath = null;
        $witnessSignaturePath = null;
        
        if (!empty($data['signature_base64'])) {
            $signaturePath = saveBase64Image($data['signature_base64'], 'signatures', 'learner_signature_' . $IDNumber);
            if ($signaturePath) {
                $data['signature'] = basename($signaturePath); // Store only filename in DB
                error_log("OFFLINE_SIGNATURE: Saved learner signature to $signaturePath");
            }
        }
        
        if (!empty($data['witness_signature_base64'])) {
            $witnessSignaturePath = saveBase64Image($data['witness_signature_base64'], 'signatures', 'witness_signature_' . $IDNumber);
            if ($witnessSignaturePath) {
                $data['witness_signature'] = basename($witnessSignaturePath); // Store only filename in DB
                error_log("OFFLINE_SIGNATURE: Saved witness signature to $witnessSignaturePath");
            }
        }
        
        // CRITICAL PROTECTION: NEVER UPDATE signature/initials fields if app sends null/empty
        // These should ONLY be updated via dedicated endpoints (save_signature.php, save_initials.php) or base64 upload
        $protectedFields = ['signature', 'witness_signature', 'learner_initials', 'witness_initials', 'profile_image'];
        foreach ($protectedFields as $field) {
            if (empty($data[$field]) || $data[$field] === '' || $data[$field] === null) {
                // App sent empty/null - Keep existing server value (don't update this field)
                $data[$field] = $existing[$field];
                error_log("PROTECTION: Preserved $field for learner $IDNumber (server has: " . ($existing[$field] ?: 'NULL') . ")");
            }
        }
        
        // Preserve ALL other fields if incoming data is empty/null
        foreach ($data as $key => $value) {
            if (empty($value) && isset($existing[$key]) && !empty($existing[$key])) {
                $data[$key] = $existing[$key];
            }
        }
        
        // Update - classID is NEVER updated via sync (partial or full)
        // classID should only be set during initial learner creation via add_learner.php
        $update = $conn->prepare("
            UPDATE learnerdetails SET
                Title=?, Name=?, Surname=?, DateOfBirth=?, PhoneNumber=?, Email=?, Age=?, Gender=?, Race=?,
                Language=?, Disability=?, AddressLine1=?, AddressLine2=?, AddressLine3=?, PostalCode=?,
                KinName=?, KinRelation=?, KinContact=?, SchoolName=?, SchoolCompletion=?, SchoolLocation=?, SchoolGrade=?,
                profile_image=?, signature=?, synced=?, fingerprint_template=?, imagePath=?, isLeftHand=?,
                activity_statu=?, witness_initials=?, learner_initials=?, witness_signature=?
            WHERE IDNumber = ?
        ");

        $update->bind_param(
            'ssssssississssssssssssssisssissss',
            $data['Title'], $data['Name'], $data['Surname'], $data['DateOfBirth'], $data['PhoneNumber'],
            $data['Email'], $data['Age'], $data['Gender'], $data['Race'], $data['Language'], $data['Disability'],
            $data['AddressLine1'], $data['AddressLine2'], $data['AddressLine3'], $data['PostalCode'],
            $data['KinName'], $data['KinRelation'], $data['KinContact'],
            $data['SchoolName'], $data['SchoolCompletion'], $data['SchoolLocation'], $data['SchoolGrade'],
            $data['profile_image'], $data['signature'], $data['synced'],
            $data['fingerprint_template'], $data['imagePath'], $data['isLeftHand'],
            $data['activity_statu'], $data['witness_initials'], $data['learner_initials'], $data['witness_signature'],
            $IDNumber
        );

        if (!$update->execute()) {
            throw new Exception("Update failed: " . $update->error);
        }

        echo json_encode(["success" => true, "message" => "Learner updated successfully."]);
    } else {
        // Insert - classID is REQUIRED for new learners
        if (!$classID) {
            throw new Exception("Missing required field: classID for insert.");
        }
        
        $insert = $conn->prepare("
            INSERT INTO learnerdetails (
                Title, Name, Surname, IDNumber, DateOfBirth, PhoneNumber, Email, Age, Gender,
                Race, Language, Disability, AddressLine1, AddressLine2, AddressLine3, PostalCode,
                KinName, KinRelation, KinContact, SchoolName, SchoolCompletion, SchoolLocation, SchoolGrade,
                classID, profile_image, signature, synced, fingerprint_template, imagePath, isLeftHand,
                activity_statu, witness_initials, learner_initials, witness_signature
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");

        $insert->bind_param(
            'sssssssissssssssssssssisssssssssss',
            $data['Title'], $data['Name'], $data['Surname'], $data['IDNumber'], $data['DateOfBirth'],
            $data['PhoneNumber'], $data['Email'], $data['Age'], $data['Gender'], $data['Race'],
            $data['Language'], $data['Disability'], $data['AddressLine1'], $data['AddressLine2'], $data['AddressLine3'],
            $data['PostalCode'], $data['KinName'], $data['KinRelation'], $data['KinContact'],
            $data['SchoolName'], $data['SchoolCompletion'], $data['SchoolLocation'], $data['SchoolGrade'],
            $classID, $data['profile_image'], $data['signature'], $data['synced'],
            $data['fingerprint_template'], $data['imagePath'], $data['isLeftHand'],
            $data['activity_statu'], $data['witness_initials'], $data['learner_initials'], $data['witness_signature']
        );

        if (!$insert->execute()) {
            throw new Exception("Insert failed: " . $insert->error);
        }

        echo json_encode(["success" => true, "message" => "Learner inserted successfully."]);
    }

    $check->close();
    $conn->close();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "error" => $e->getMessage()]);
}
?>
