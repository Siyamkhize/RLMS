<?php
include 'connection.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Allow both GET and POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit;
}

try {
    // Query all learner details with the exact column names expected by Flutter
    $stmt = $conn->prepare("SELECT 
        LearnerID,
        Title,
        Name,
        Surname,
        IDNumber,
        DateOfBirth,
        PhoneNumber,
        Email,
        Age,
        Gender,
        Race,
        Language,
        Disability,
        AddressLine1,
        AddressLine2,
        AddressLine3,
        PostalCode,
        KinName,
        KinRelation,
        KinContact,
        SchoolName,
        SchoolCompletion,
        SchoolLocation,
        SchoolGrade,
        BankName,
        bankType,
        BankAccount,
        BankCode,
        classID,
        profile_image,
        signature,
        synced,
        zkteco_left_template,
        zkteco_right_template,
        futronic_left_template,
        futronic_right_template,
        imagePath,
        activity_statu,
        witness_initials,
        learner_initials,
        witness_signature
        FROM learnerdetails");
    $stmt->execute();
    $result = $stmt->get_result();

    $learners = [];
    while ($row = $result->fetch_assoc()) {
        $learners[] = [
            'LearnerID' => $row['LearnerID'],
            'Title' => $row['Title'],
            'Name' => $row['Name'],
            'Surname' => $row['Surname'],
            'IDNumber' => $row['IDNumber'],
            'DateOfBirth' => $row['DateOfBirth'],
            'PhoneNumber' => $row['PhoneNumber'],
            'Email' => $row['Email'],
            'Age' => $row['Age'],
            'Gender' => $row['Gender'],
            'Race' => $row['Race'],
            'Language' => $row['Language'],
            'Disability' => $row['Disability'],
            'AddressLine1' => $row['AddressLine1'],
            'AddressLine2' => $row['AddressLine2'],
            'AddressLine3' => $row['AddressLine3'],
            'PostalCode' => $row['PostalCode'],
            'KinName' => $row['KinName'],
            'KinRelation' => $row['KinRelation'],
            'KinContact' => $row['KinContact'],
            'SchoolName' => $row['SchoolName'],
            'SchoolCompletion' => $row['SchoolCompletion'],
            'SchoolLocation' => $row['SchoolLocation'],
            'SchoolGrade' => $row['SchoolGrade'],
            'BankName' => $row['BankName'],
            'bankType' => $row['bankType'],
            'BankAccount' => $row['BankAccount'],
            'BankCode' => $row['BankCode'],
            'classID' => $row['classID'],
            'profile_image' => $row['profile_image'],
            'signature' => $row['signature'],
            'synced' => $row['synced'],
            'zkteco_left_template' => $row['zkteco_left_template'],
            'zkteco_right_template' => $row['zkteco_right_template'],
            'futronic_left_template' => $row['futronic_left_template'],
            'futronic_right_template' => $row['futronic_right_template'],
            'imagePath' => $row['imagePath'],
            'activity_statu' => $row['activity_statu'],
            'witness_initials' => $row['witness_initials'],
            'learner_initials' => $row['learner_initials'],
            'witness_signature' => $row['witness_signature'],
        ];
    }

    // Return learners as JSON
    echo json_encode($learners);
    $stmt->close();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Server error: ' . $e->getMessage()]);
}

$conn->close();
?> 