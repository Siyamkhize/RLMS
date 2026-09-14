<?php

require_once __DIR__ . '/../security_functions.php';
header('Content-Type: application/json');
include 'connection.php';

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

    // Upload file helpers
    function saveFile($fileKey, $targetFolder = 'uploads') {
        if (!isset($_FILES[$fileKey]) || $_FILES[$fileKey]['error'] !== UPLOAD_ERR_OK) {
            return null;
        }
        $filename = basename($_FILES[$fileKey]['name']);
        $uniqueName = uniqid() . '_' . $filename;
        $targetPath = $targetFolder . '/' . $uniqueName;
        move_uploaded_file($_FILES[$fileKey]['tmp_name'], $targetPath);
        return $targetPath;
    }

    $data['profile_image'] = stripDevicePath(saveFile('profile_image') ?? getPost('profile_image'));
    $data['signature'] = stripDevicePath(saveFile('signature') ?? getPost('signature'));
    $data['witness_signature'] = stripDevicePath(saveFile('witness_signature') ?? getPost('witness_signature'));

    // Check if learner exists by IDNumber
    $check = $conn->prepare("SELECT LearnerID FROM learnerdetails WHERE IDNumber = ?");
    $check->bind_param("s", $IDNumber);
    $check->execute();
    $checkResult = $check->get_result();

    if ($checkResult->num_rows > 0) {
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
            'ssssssssssssssssssssssissssssssss',
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
