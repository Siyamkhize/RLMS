<?php
/**
 * Add Learner Endpoint - SECURED
 * 
 * Security Features:
 * - Bearer token authentication required
 * - Rate limiting: 30 requests per minute
 * - Input validation and sanitization
 * - SQL injection protection via prepared statements
 * - Duplicate detection by IDNumber + classID + project
 * 
 * @security CRITICAL - Authentication required
 */

require_once 'require_auth.php';
include 'connection.php';

header('Content-Type: application/json');

// Enhanced error logging
error_reporting(E_ALL);
ini_set('display_errors', 1);
$debug_log = [];

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

// SECURITY: Require authentication
$user = requireAuth($conn);
$debug_log[] = "Authenticated user: {$user['user_id']} ({$user['user_role']})";

// SECURITY: Apply rate limiting (30 requests per minute)
applyRateLimit($conn, 'add_learner');

/**
 * Strip device-specific path prefixes from image paths.
 * Converts: /data/user/0/com.example.rlmss/app_flutter/learnerImages_22433.png
 * To: learnerImages_22433.png
 * 
 * NOTE: For offline→online sync, signatures will be uploaded separately
 * via save_signature.php which will rename them with the server LearnerID
 * 
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
    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    
    $debug_log[] = "Received input: " . json_encode($input);
    
    if (!$input) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid JSON input']);
        exit;
    }

    // Detect if this is a sync operation (offline learner being synced)
    $isSyncOperation = isset($input['local_id']) && !empty($input['local_id']);
    $debug_log[] = "Is sync operation: " . ($isSyncOperation ? 'yes' : 'no');
    
    if ($isSyncOperation) {
        $debug_log[] = "Local ID: " . $input['local_id'];
    }

    // SECURITY: Validate required fields
    $requiredFields = ['Name', 'Surname', 'IDNumber', 'classID'];
    validateRequired($requiredFields, $input);
    
    // SECURITY: Sanitize and validate inputs
    $input['Name'] = sanitize_input($input['Name']);
    $input['Surname'] = sanitize_input($input['Surname']);
    $input['IDNumber'] = sanitize_input($input['IDNumber']);
    
    // Validate ID Number format
    if (!validate_sa_id($input['IDNumber'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Invalid South African ID number format',
            'debug' => $debug_log
        ]);
        exit;
    }
    
    // Validate classID is integer
    $classID_validated = validate_int($input['classID'], 1);
    if ($classID_validated === false) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Invalid classID format',
            'debug' => $debug_log
        ]);
        exit;
    }
    
    // Validate email if provided
    if (!empty($input['Email']) && !validate_email($input['Email'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Invalid email format',
            'debug' => $debug_log
        ]);
        exit;
    }
    
    $debug_log[] = "Input validation passed";

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
        $debug_log[] = "Project ID found: $projectId";
    } else {
        $debug_log[] = "No project ID found for classID: " . $input['classID'];
    }

    // For sync operations, check for duplicates by IDNumber + classID + project
    // This prevents multiple admins from creating duplicate learners when syncing offline data
    $learnerExists = false;
    $learnerID = null;
    
    if ($isSyncOperation) {
        $debug_log[] = "Sync operation - checking for duplicate by IDNumber + classID + project";
        
        if ($projectId !== null) {
            // Check for duplicate in same project by IDNumber + classID
            $stmt = $conn->prepare("
                SELECT ld.LearnerID 
                FROM learnerdetails ld
                JOIN class c ON ld.classID = c.classID
                JOIN sites s ON c.siteID = s.siteID
                WHERE ld.IDNumber = ? AND ld.classID = ? AND s.project_id = ?
            ");
            $stmt->bind_param("sss", $input['IDNumber'], $input['classID'], $projectId);
        } else {
            // Fallback: check by IDNumber + classID only
            $stmt = $conn->prepare("
                SELECT LearnerID FROM learnerdetails 
                WHERE IDNumber = ? AND classID = ?
            ");
            $stmt->bind_param("ss", $input['IDNumber'], $input['classID']);
        }
        
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            $existingLearner = $result->fetch_assoc();
            $learnerID = $existingLearner['LearnerID'];
            $learnerExists = true;
            $debug_log[] = "Duplicate found during sync - will UPDATE existing learner ID: $learnerID";
        } else {
            $debug_log[] = "No duplicate found - will INSERT new learner";
        }
    } else {
        // Direct online add - check for duplicates by IDNumber in same project
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
            $learnerExists = true;
            $debug_log[] = "Existing learner found with ID: $learnerID";
        }
    }
    
    if ($learnerExists) {
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
            'profile_image' => stripDevicePath($input['profile_image'] ?? ''),
            'signature' => stripDevicePath($input['signature'] ?? ''),
            'synced' => 1,
            'zkteco_left_template' => $input['zkteco_left_template'] ?? '',
            'zkteco_right_template' => $input['zkteco_right_template'] ?? '',
            'futronic_left_template' => $input['futronic_left_template'] ?? '',
            'futronic_right_template' => $input['futronic_right_template'] ?? '',
            'imagePath' => $input['imagePath'] ?? '',
            'activity_statu' => $input['activity_statu'] ?? '',
            'witness_initials' => $input['witness_initials'] ?? '',
            'learner_initials' => $input['learner_initials'] ?? '',
            'witness_signature' => stripDevicePath($input['witness_signature'] ?? ''),
        ];
        
        $debug_log[] = "Cleaned signature: " . ($updateFields['signature'] ?? 'none');
        $debug_log[] = "Cleaned witness_signature: " . ($updateFields['witness_signature'] ?? 'none');
        $debug_log[] = "Cleaned profile_image: " . ($updateFields['profile_image'] ?? 'none');

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
            'LearnerID' => $learnerID,
            'operation' => 'update',
            'debug' => $debug_log
        ]);
    } else {
        // Insert new learner (learnerdetails table only)
        $debug_log[] = "Inserting new learner...";
        
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
            'profile_image' => stripDevicePath($input['profile_image'] ?? ''),
            'signature' => stripDevicePath($input['signature'] ?? ''),
            'synced' => 1,
            'zkteco_left_template' => $input['zkteco_left_template'] ?? '',
            'zkteco_right_template' => $input['zkteco_right_template'] ?? '',
            'futronic_left_template' => $input['futronic_left_template'] ?? '',
            'futronic_right_template' => $input['futronic_right_template'] ?? '',
            'imagePath' => $input['imagePath'] ?? '',
            'activity_statu' => $input['activity_statu'] ?? '',
            'witness_initials' => $input['witness_initials'] ?? '',
            'learner_initials' => $input['learner_initials'] ?? '',
            'witness_signature' => stripDevicePath($input['witness_signature'] ?? ''),
        ];
        
        $debug_log[] = "Cleaned signature: " . ($insertFields['signature'] ?? 'none');
        $debug_log[] = "Cleaned witness_signature: " . ($insertFields['witness_signature'] ?? 'none');
        $debug_log[] = "Cleaned profile_image: " . ($insertFields['profile_image'] ?? 'none');

        $insertQuery = "INSERT INTO learnerdetails (" . implode(', ', array_keys($insertFields)) . ") VALUES (" . str_repeat('?,', count($insertFields) - 1) . "?)";
        
        $stmt = $conn->prepare($insertQuery);
        $stmt->bind_param(str_repeat('s', count($insertFields)), ...array_values($insertFields));
        $stmt->execute();
        
        $learnerID = $conn->insert_id;
        $debug_log[] = "New learner inserted with ID: $learnerID";

        // Handle bank details separately
        if (isset($input['BankName']) && !empty($input['BankName'])) {
            $debug_log[] = "Inserting bank details...";
            
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
            
            $debug_log[] = "Bank details inserted successfully";
        }

        echo json_encode([
            'success' => true,
            'message' => $isSyncOperation ? 'Learner synced successfully' : 'Learner added successfully',
            'LearnerID' => $learnerID,
            'server_id' => $learnerID, // For sync operations
            'local_id' => $isSyncOperation ? $input['local_id'] : null, // Return local_id for mapping
            'operation' => 'insert',
            'debug' => $debug_log
        ]);
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server error: ' . $e->getMessage(),
        'debug' => $debug_log
    ]);
}

$conn->close();
?> 