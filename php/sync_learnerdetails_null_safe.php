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
    // Query all learner details with bank details joined
    // Using LEFT JOIN to include learners even if they don't have bank details
    $stmt = $conn->prepare("SELECT 
        l.LearnerID,
        l.Title,
        l.Name,
        l.Surname,
        l.IDNumber,
        l.DateOfBirth,
        l.PhoneNumber,
        l.Email,
        l.Age,
        l.Gender,
        l.Race,
        l.Language,
        l.Disability,
        l.AddressLine1,
        l.AddressLine2,
        l.AddressLine3,
        l.PostalCode,
        l.KinName,
        l.KinRelation,
        l.KinContact,
        l.SchoolName,
        l.SchoolCompletion,
        l.SchoolLocation,
        l.SchoolGrade,
        l.classID,
        l.profile_image,
        l.signature,
        l.synced,
        l.zkteco_left_template,
        l.zkteco_right_template,
        l.futronic_left_template,
        l.futronic_right_template,
        l.imagePath,
        l.activity_statu,
        l.witness_initials,
        l.learner_initials,
        l.witness_signature,
        b.BankName,
        b.bankType,
        b.BankAccount,
        b.BankCode
        FROM learnerdetails l
        LEFT JOIN bankdetails b ON l.LearnerID = b.LearnerID
        ORDER BY l.LearnerID");
    
    $stmt->execute();
    $result = $stmt->get_result();

    $learners = [];
    $currentLearnerID = null;
    $currentLearner = null;

    while ($row = $result->fetch_assoc()) {
        $learnerID = $row['LearnerID'];
        
        // If this is a new learner, create a new learner entry
        if ($currentLearnerID !== $learnerID) {
            // Save the previous learner if exists
            if ($currentLearner !== null) {
                $learners[] = $currentLearner;
            }
            
            // Create new learner entry with null-safe handling
            $currentLearner = [
                'LearnerID' => $row['LearnerID'],
                'Title' => $row['Title'] ?? '',
                'Name' => $row['Name'] ?? '',
                'Surname' => $row['Surname'] ?? '',
                'IDNumber' => $row['IDNumber'] ?? '',
                'DateOfBirth' => $row['DateOfBirth'] ?? null,
                'PhoneNumber' => $row['PhoneNumber'] ?? '',
                'Email' => $row['Email'] ?? '',
                'Age' => $row['Age'] ?? null,
                'Gender' => $row['Gender'] ?? '',
                'Race' => $row['Race'] ?? '',
                'Language' => $row['Language'] ?? '',
                'Disability' => $row['Disability'] ?? '',
                'AddressLine1' => $row['AddressLine1'] ?? '',
                'AddressLine2' => $row['AddressLine2'] ?? '',
                'AddressLine3' => $row['AddressLine3'] ?? '',
                'PostalCode' => $row['PostalCode'] ?? '',
                'KinName' => $row['KinName'] ?? '',
                'KinRelation' => $row['KinRelation'] ?? '',
                'KinContact' => $row['KinContact'] ?? '',
                'SchoolName' => $row['SchoolName'] ?? '',
                'SchoolCompletion' => $row['SchoolCompletion'] ?? null,
                'SchoolLocation' => $row['SchoolLocation'] ?? '',
                'SchoolGrade' => $row['SchoolGrade'] ?? '',
                'classID' => $row['classID'],
                'profile_image' => $row['profile_image'] ?? '',
                'signature' => $row['signature'] ?? '',
                'synced' => $row['synced'] ?? 0,
                'zkteco_left_template' => $row['zkteco_left_template'] ?? '',
                'zkteco_right_template' => $row['zkteco_right_template'] ?? '',
                'futronic_left_template' => $row['futronic_left_template'] ?? '',
                'futronic_right_template' => $row['futronic_right_template'] ?? '',
                'imagePath' => $row['imagePath'] ?? '',
                'activity_statu' => $row['activity_statu'] ?? '',
                'witness_initials' => $row['witness_initials'] ?? '',
                'learner_initials' => $row['learner_initials'] ?? '',
                'witness_signature' => $row['witness_signature'] ?? '',
                'BankName' => $row['BankName'] ?? '',
                'bankType' => $row['bankType'] ?? '',
                'BankAccount' => $row['BankAccount'] ?? '',
                'BankCode' => $row['BankCode'] ?? '',
            ];
            
            $currentLearnerID = $learnerID;
        }
        // If this is the same learner but with different bank details (shouldn't happen with current schema, but just in case)
        else if ($row['BankName'] !== null && $row['BankName'] !== '') {
            // Update bank details if they exist
            $currentLearner['BankName'] = $row['BankName'];
            $currentLearner['bankType'] = $row['bankType'] ?? '';
            $currentLearner['BankAccount'] = $row['BankAccount'] ?? '';
            $currentLearner['BankCode'] = $row['BankCode'] ?? '';
        }
    }
    
    // Don't forget to add the last learner
    if ($currentLearner !== null) {
        $learners[] = $currentLearner;
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