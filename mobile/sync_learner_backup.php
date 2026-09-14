<?php
include 'connection.php';

header('Content-Type: application/json');

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

        if (!$learner || !isset($learner['IDNumber']) || !isset($learner['classID'])) {
            $response['failed'][] = ['IDNumber' => $learner['IDNumber'] ?? 'unknown', 'error' => 'Missing required learner fields'];
            continue;
        }

        // Check if learner already exists (based on IDNumber)
        $stmt = $conn->prepare("SELECT LearnerID FROM learnerdetails WHERE IDNumber = ?");
        $stmt->bind_param("s", $learner['IDNumber']);
        $stmt->execute();
        $result = $stmt->get_result();
        $existingLearner = $result->num_rows > 0 ? $result->fetch_assoc() : null;
        $stmt->close();

        // Prepare learner fields
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
            'classID' => $learner['classID'],
            'profile_image' => $learner['profile_image'] ?? null,
            'signature' => $learner['signature'] ?? null,
            'synced' => 1, // Server marks as synced
            'fingerprint_template' => $learner['fingerprint_template'] ?? null,
            'imagePath' => $learner['imagePath'] ?? null,
            'isLeftHand' => $learner['isLeftHand'] ?? null,
            'AddressLine2' => $learner['AddressLine2'] ?? null,
            'AddressLine3' => $learner['AddressLine3'] ?? null,
            'PostalCode' => $learner['PostalCode'] ?? null,
            'activity_statu' => $learner['activity_statu'] ?? 'Inactive',
            'witness_initials' => $learner['witness_initials'] ?? null,
            'learner_initials' => $learner['learner_initials'] ?? null,
            'witness_signature' => $learner['witness_signature'] ?? null,
        ];

        $serverLearnerId = null;
        if ($existingLearner) {
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