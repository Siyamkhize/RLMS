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
    $requiredFields = ['Name', 'Surname', 'IDNumber', 'classID'];
    foreach ($requiredFields as $field) {
        if (!isset($input[$field]) || empty($input[$field])) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => "Missing required field: $field"]);
            exit;
        }
    }

    // Get project_id from classID (via class -> sites join)
    $projectStmt = $conn->prepare("
        SELECT s.project_id 
        FROM class c 
        JOIN sites s ON c.siteID = s.siteID 
        WHERE c.classID = ?
    ");
    $projectStmt->bind_param("s", $input['classID']);
    $projectStmt->execute();
    $projectResult = $projectStmt->get_result();
    
    $projectId = null;
    if ($projectResult->num_rows > 0) {
        $projectRow = $projectResult->fetch_assoc();
        $projectId = $projectRow['project_id'];
    }

    // Check if learner already exists by IDNumber AND project_id
    if ($projectId !== null) {
        // Check for duplicate in same project
        $stmt = $conn->prepare("
            SELECT ld.LearnerID 
            FROM learnerdetails ld
            JOIN class c ON ld.classID = c.classID
            JOIN sites s ON c.siteID = s.siteID
            WHERE ld.IDNumber = ? AND s.project_id = ?
        ");
        $stmt->bind_param("ss", $input['IDNumber'], $projectId);
    } else {
        // Fallback to old behavior if project_id not found
        $stmt = $conn->prepare("SELECT LearnerID FROM learnerdetails WHERE IDNumber = ?");
        $stmt->bind_param("s", $input['IDNumber']);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $existingLearner = $result->fetch_assoc();
        $learnerID = $existingLearner['LearnerID'];
        
        // Update existing learner (learnerdetails table only)
        $updateFields = [
            'Title' => $input['Title'] ?? 'N/A',
            'Name' => $input['Name'],
            'Surname' => $input['Surname'],
            'DateOfBirth' => $input['DateOfBirth'] ?? 'N/A',
            'PhoneNumber' => $input['PhoneNumber'] ?? 'N/A',
            'Email' => $input['Email'] ?? 'N/A',
            'Age' => $input['Age'] ?? 0,
            'Gender' => $input['Gender'] ?? 'Unknown',
            'Race' => $input['Race'] ?? '',
            'Language' => $input['Language'] ?? '',
            'Disability' => $input['Disability'] ?? '',
            'AddressLine1' => $input['AddressLine1'] ?? '',
            'AddressLine2' => $input['AddressLine2'] ?? '',
            'AddressLine3' => $input['AddressLine3'] ?? '',
            'PostalCode' => $input['PostalCode'] ?? '',
            'KinName' => $input['KinName'] ?? '',
            'KinRelation' => $input['KinRelation'] ?? '',
            'KinContact' => $input['KinContact'] ?? '',
            'SchoolName' => $input['SchoolName'] ?? '',
            'SchoolCompletion' => $input['SchoolCompletion'] ?? '',
            'SchoolLocation' => $input['SchoolLocation'] ?? '',
            'SchoolGrade' => $input['SchoolGrade'] ?? '',
            'profile_image' => $input['profile_image'] ?? '',
            'signature' => $input['signature'] ?? '',
            'synced' => 1,
            'zkteco_left_template' => $input['zkteco_left_template'] ?? '',
            'zkteco_right_template' => $input['zkteco_right_template'] ?? '',
            'futronic_left_template' => $input['futronic_left_template'] ?? '',
            'futronic_right_template' => $input['futronic_right_template'] ?? '',
            'imagePath' => $input['imagePath'] ?? '',
            'activity_statu' => $input['activity_statu'] ?? '',
            'witness_initials' => $input['witness_initials'] ?? '',
            'learner_initials' => $input['learner_initials'] ?? '',
            'witness_signature' => $input['witness_signature'] ?? '',
        ];

        $updateQuery = "UPDATE learnerdetails SET ";
        $updateParams = [];
        $updateTypes = "";
        
        foreach ($updateFields as $field => $value) {
            $updateQuery .= "$field = ?, ";
            $updateParams[] = $value;
            $updateTypes .= "s";
        }
        
        $updateQuery = rtrim($updateQuery, ", ");
        $updateQuery .= " WHERE LearnerID = ?";
        $updateParams[] = $learnerID;
        $updateTypes .= "i";

        $stmt = $conn->prepare($updateQuery);
        $stmt->bind_param($updateTypes, ...$updateParams);
        $stmt->execute();

        // Handle bank details separately
        if (isset($input['BankName']) && !empty($input['BankName'])) {
            $bankFields = [
                'LearnerID' => $learnerID,
                'BankName' => $input['BankName'],
                'bankType' => $input['bankType'] ?? '',
                'BankAccount' => $input['BankAccount'] ?? '',
                'BankCode' => $input['BankCode'] ?? '',
                'synced' => 1,
            ];

            // Check if bank details already exist
            $bankStmt = $conn->prepare("SELECT BankID FROM bankdetails WHERE LearnerID = ?");
            $bankStmt->bind_param("i", $learnerID);
            $bankStmt->execute();
            $bankResult = $bankStmt->get_result();

            if ($bankResult->num_rows > 0) {
                // Update existing bank details
                $bankUpdateQuery = "UPDATE bankdetails SET BankName = ?, bankType = ?, BankAccount = ?, BankCode = ?, synced = ? WHERE LearnerID = ?";
                $bankUpdateStmt = $conn->prepare($bankUpdateQuery);
                $bankUpdateStmt->bind_param("sssssi", $bankFields['BankName'], $bankFields['bankType'], $bankFields['BankAccount'], $bankFields['BankCode'], $bankFields['synced'], $learnerID);
                $bankUpdateStmt->execute();
            } else {
                // Insert new bank details
                $bankInsertQuery = "INSERT INTO bankdetails (LearnerID, BankName, bankType, BankAccount, BankCode, synced) VALUES (?, ?, ?, ?, ?, ?)";
                $bankInsertStmt = $conn->prepare($bankInsertQuery);
                $bankInsertStmt->bind_param("issssi", $learnerID, $bankFields['BankName'], $bankFields['bankType'], $bankFields['BankAccount'], $bankFields['BankCode'], $bankFields['synced']);
                $bankInsertStmt->execute();
            }
        }

        echo json_encode([
            'success' => true,
            'message' => 'Learner updated successfully',
            'LearnerID' => $learnerID
        ]);
    } else {
        // Insert new learner (learnerdetails table only)
        $insertFields = [
            'classID' => $input['classID'],
            'Title' => $input['Title'] ?? 'N/A',
            'Name' => $input['Name'],
            'Surname' => $input['Surname'],
            'IDNumber' => $input['IDNumber'],
            'DateOfBirth' => $input['DateOfBirth'] ?? 'N/A',
            'PhoneNumber' => $input['PhoneNumber'] ?? 'N/A',
            'Email' => $input['Email'] ?? 'N/A',
            'Age' => $input['Age'] ?? 0,
            'Gender' => $input['Gender'] ?? 'Unknown',
            'Race' => $input['Race'] ?? '',
            'Language' => $input['Language'] ?? '',
            'Disability' => $input['Disability'] ?? '',
            'AddressLine1' => $input['AddressLine1'] ?? '',
            'AddressLine2' => $input['AddressLine2'] ?? '',
            'AddressLine3' => $input['AddressLine3'] ?? '',
            'PostalCode' => $input['PostalCode'] ?? '',
            'KinName' => $input['KinName'] ?? '',
            'KinRelation' => $input['KinRelation'] ?? '',
            'KinContact' => $input['KinContact'] ?? '',
            'SchoolName' => $input['SchoolName'] ?? '',
            'SchoolCompletion' => $input['SchoolCompletion'] ?? '',
            'SchoolLocation' => $input['SchoolLocation'] ?? '',
            'SchoolGrade' => $input['SchoolGrade'] ?? '',
            'profile_image' => $input['profile_image'] ?? '',
            'signature' => $input['signature'] ?? '',
            'synced' => 1,
            'zkteco_left_template' => $input['zkteco_left_template'] ?? '',
            'zkteco_right_template' => $input['zkteco_right_template'] ?? '',
            'futronic_left_template' => $input['futronic_left_template'] ?? '',
            'futronic_right_template' => $input['futronic_right_template'] ?? '',
            'imagePath' => $input['imagePath'] ?? '',
            'activity_statu' => $input['activity_statu'] ?? '',
            'witness_initials' => $input['witness_initials'] ?? '',
            'learner_initials' => $input['learner_initials'] ?? '',
            'witness_signature' => $input['witness_signature'] ?? '',
        ];

        $insertQuery = "INSERT INTO learnerdetails (" . implode(', ', array_keys($insertFields)) . ") VALUES (" . str_repeat('?,', count($insertFields) - 1) . "?)";
        
        $stmt = $conn->prepare($insertQuery);
        $stmt->bind_param(str_repeat('s', count($insertFields)), ...array_values($insertFields));
        $stmt->execute();
        
        $learnerID = $conn->insert_id;

        // Handle bank details separately
        if (isset($input['BankName']) && !empty($input['BankName'])) {
            $bankFields = [
                'LearnerID' => $learnerID,
                'BankName' => $input['BankName'],
                'bankType' => $input['bankType'] ?? '',
                'BankAccount' => $input['BankAccount'] ?? '',
                'BankCode' => $input['BankCode'] ?? '',
                'synced' => 1,
            ];

            $bankInsertQuery = "INSERT INTO bankdetails (LearnerID, BankName, bankType, BankAccount, BankCode, synced) VALUES (?, ?, ?, ?, ?, ?)";
            $bankInsertStmt = $conn->prepare($bankInsertQuery);
            $bankInsertStmt->bind_param("issssi", $learnerID, $bankFields['BankName'], $bankFields['bankType'], $bankFields['BankAccount'], $bankFields['BankCode'], $bankFields['synced']);
            $bankInsertStmt->execute();
        }

        echo json_encode([
            'success' => true,
            'message' => 'Learner added successfully',
            'LearnerID' => $learnerID
        ]);
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server error: ' . $e->getMessage()
    ]);
}

$conn->close();
?> 