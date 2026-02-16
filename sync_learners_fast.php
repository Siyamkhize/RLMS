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

try {
    // Get parameters
    $classID = $_GET['classID'] ?? $_POST['classID'] ?? null;
    $onlyBasicFields = ($_GET['basicOnly'] ?? $_POST['basicOnly'] ?? 'true') === 'true';
    $lastSync = $_GET['lastSync'] ?? $_POST['lastSync'] ?? null; // For incremental sync

    if (!$classID) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'classID parameter is required']);
        exit;
    }

    // Build query based on requirements
    if ($onlyBasicFields) {
        // Fast sync - only essential fields for initial display
        $sql = "SELECT 
                    l.LearnerID,
                    l.Name,
                    l.Surname,
                    l.IDNumber,
                    l.PhoneNumber,
                    l.classID,
                    l.synced,
                    CASE 
                        WHEN l.Title IS NOT NULL AND l.Title != '' THEN l.Title
                        ELSE NULL 
                    END as Title,
                    CASE 
                        WHEN l.Gender IS NOT NULL AND l.Gender != '' THEN l.Gender
                        ELSE NULL 
                    END as Gender,
                    CASE 
                        WHEN l.profile_image IS NOT NULL AND l.profile_image != '' THEN l.profile_image
                        ELSE NULL 
                    END as profile_image
                FROM learnerdetails l
                WHERE l.classID = ?";
        
        if ($lastSync) {
            $sql .= " AND (l.updated_at > ? OR l.created_at > ?)";
        }
        
        $sql .= " ORDER BY l.LearnerID";
        
        $stmt = $conn->prepare($sql);
        if ($lastSync) {
            $stmt->bind_param("sss", $classID, $lastSync, $lastSync);
        } else {
            $stmt->bind_param("s", $classID);
        }
    } else {
        // Full sync - all fields but optimized for NULL handling
        $sql = "SELECT 
                    l.LearnerID,
                    l.Name,
                    l.Surname,
                    l.IDNumber,
                    l.PhoneNumber,
                    l.classID,
                    l.synced,
                    NULLIF(l.Title, '') as Title,
                    NULLIF(l.DateOfBirth, '') as DateOfBirth,
                    NULLIF(l.Email, '') as Email,
                    NULLIF(l.Age, '') as Age,
                    NULLIF(l.Gender, '') as Gender,
                    NULLIF(l.Race, '') as Race,
                    NULLIF(l.Language, '') as Language,
                    NULLIF(l.Disability, '') as Disability,
                    NULLIF(l.AddressLine1, '') as AddressLine1,
                    NULLIF(l.AddressLine2, '') as AddressLine2,
                    NULLIF(l.AddressLine3, '') as AddressLine3,
                    NULLIF(l.PostalCode, '') as PostalCode,
                    NULLIF(l.KinName, '') as KinName,
                    NULLIF(l.KinRelation, '') as KinRelation,
                    NULLIF(l.KinContact, '') as KinContact,
                    NULLIF(l.SchoolName, '') as SchoolName,
                    NULLIF(l.SchoolCompletion, '') as SchoolCompletion,
                    NULLIF(l.SchoolLocation, '') as SchoolLocation,
                    NULLIF(l.SchoolGrade, '') as SchoolGrade,
                    NULLIF(l.profile_image, '') as profile_image,
                    NULLIF(l.signature, '') as signature,
                    NULLIF(l.imagePath, '') as imagePath,
                    NULLIF(l.activity_statu, '') as activity_statu,
                    NULLIF(l.witness_initials, '') as witness_initials,
                    NULLIF(l.learner_initials, '') as learner_initials,
                    NULLIF(l.witness_signature, '') as witness_signature,
                    NULLIF(b.BankName, '') as BankName,
                    NULLIF(b.bankType, '') as bankType,
                    NULLIF(b.BankAccount, '') as BankAccount,
                    NULLIF(b.BankCode, '') as BankCode
                FROM learnerdetails l
                LEFT JOIN bankdetails b ON l.LearnerID = b.LearnerID
                WHERE l.classID = ?";
        
        if ($lastSync) {
            $sql .= " AND (l.updated_at > ? OR l.created_at > ?)";
        }
        
        $sql .= " ORDER BY l.LearnerID";
        
        $stmt = $conn->prepare($sql);
        if ($lastSync) {
            $stmt->bind_param("sss", $classID, $lastSync, $lastSync);
        } else {
            $stmt->bind_param("s", $classID);
        }
    }

    $stmt->execute();
    $result = $stmt->get_result();

    $learners = [];
    $processedLearners = [];

    while ($row = $result->fetch_assoc()) {
        $learnerID = $row['LearnerID'];
        
        // Handle duplicate learners from LEFT JOIN
        if (isset($processedLearners[$learnerID])) {
            continue;
        }
        
        // Create optimized learner object - exclude NULL values to reduce JSON size
        $learner = [];
        foreach ($row as $key => $value) {
            if ($value !== null) {
                $learner[$key] = $value;
            }
        }
        
        $learners[] = $learner;
        $processedLearners[$learnerID] = true;
    }

    // Calculate response statistics
    $originalSize = 0;
    $optimizedSize = strlen(json_encode($learners));
    
    // Estimate what the size would be with all NULL fields included
    foreach ($learners as $learner) {
        $originalSize += strlen(json_encode($learner)) + 500; // Estimate 500 bytes for NULL fields
    }

    $response = [
        'status' => 'success',
        'data' => $learners,
        'meta' => [
            'classID' => $classID,
            'count' => count($learners),
            'basicFieldsOnly' => $onlyBasicFields,
            'isIncremental' => $lastSync !== null,
            'optimizedSize' => $optimizedSize,
            'estimatedOriginalSize' => $originalSize,
            'sizeSavings' => $originalSize - $optimizedSize,
            'compressionRatio' => $originalSize > 0 ? round((1 - $optimizedSize / $originalSize) * 100, 2) : 0,
            'timestamp' => date('Y-m-d H:i:s')
        ]
    ];

    echo json_encode($response);
    $stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error', 
        'message' => 'Server error: ' . $e->getMessage(),
        'code' => $e->getCode()
    ]);
}

$conn->close();
?>