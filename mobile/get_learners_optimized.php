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
    $page = (int)($_GET['page'] ?? $_POST['page'] ?? 1);
    $limit = (int)($_GET['limit'] ?? $_POST['limit'] ?? 50); // Default 50 learners per page
    $includeFingerprints = ($_GET['includeFingerprints'] ?? $_POST['includeFingerprints'] ?? 'false') === 'true';
    $fieldsOnly = $_GET['fields'] ?? $_POST['fields'] ?? null; // Comma-separated list of fields

    if (!$classID) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'classID parameter is required']);
        exit;
    }

    // Calculate offset for pagination
    $offset = ($page - 1) * $limit;

    // Build dynamic field list
    $basicFields = [
        'l.LearnerID', 'l.Title', 'l.Name', 'l.Surname', 'l.IDNumber', 
        'l.DateOfBirth', 'l.PhoneNumber', 'l.Email', 'l.Age', 'l.Gender', 
        'l.classID', 'l.synced'
    ];

    $optionalFields = [
        'l.Race', 'l.Language', 'l.Disability', 'l.AddressLine1', 'l.AddressLine2', 
        'l.AddressLine3', 'l.PostalCode', 'l.KinName', 'l.KinRelation', 'l.KinContact',
        'l.SchoolName', 'l.SchoolCompletion', 'l.SchoolLocation', 'l.SchoolGrade',
        'l.profile_image', 'l.signature', 'l.imagePath', 'l.activity_statu',
        'l.witness_initials', 'l.learner_initials', 'l.witness_signature'
    ];

    $fingerprintFields = [
        'l.zkteco_left_template', 'l.zkteco_right_template', 
        'l.futronic_left_template', 'l.futronic_right_template'
    ];

    $bankFields = [
        'b.BankName', 'b.bankType', 'b.BankAccount', 'b.BankCode'
    ];

    // Start with basic fields
    $selectedFields = $basicFields;

    // Add optional fields if requested or if no specific fields requested
    if ($fieldsOnly) {
        $requestedFields = array_map('trim', explode(',', $fieldsOnly));
        foreach ($requestedFields as $field) {
            if (in_array("l.$field", $optionalFields)) {
                $selectedFields[] = "l.$field";
            } elseif (in_array("b.$field", $bankFields)) {
                $selectedFields[] = "b.$field";
            }
        }
    } else {
        // Include all optional fields by default
        $selectedFields = array_merge($selectedFields, $optionalFields, $bankFields);
    }

    // Add fingerprint fields only if requested
    if ($includeFingerprints) {
        $selectedFields = array_merge($selectedFields, $fingerprintFields);
    }

    $fieldList = implode(', ', $selectedFields);

    // Build optimized query with pagination
    $sql = "SELECT $fieldList
            FROM learnerdetails l
            LEFT JOIN bankdetails b ON l.LearnerID = b.LearnerID
            WHERE l.classID = ?
            ORDER BY l.LearnerID
            LIMIT ? OFFSET ?";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sii", $classID, $limit, $offset);
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
            
            // Create new learner object - only include non-null values to reduce payload
            $currentLearner = [];
            foreach ($row as $key => $value) {
                // Only include non-null, non-empty values to minimize JSON size
                if ($value !== null && $value !== '') {
                    $currentLearner[$key] = $value;
                } elseif (in_array($key, ['LearnerID', 'Name', 'Surname', 'IDNumber', 'classID'])) {
                    // Always include essential fields even if empty
                    $currentLearner[$key] = $value ?? '';
                }
            }
            
            $currentLearnerID = $learnerID;
        }
    }
    
    // Add the last learner
    if ($currentLearner !== null) {
        $learners[] = $currentLearner;
    }

    // Get total count for pagination info
    $countStmt = $conn->prepare("SELECT COUNT(DISTINCT l.LearnerID) as total FROM learnerdetails l WHERE l.classID = ?");
    $countStmt->bind_param("s", $classID);
    $countStmt->execute();
    $countResult = $countStmt->get_result();
    $totalLearners = $countResult->fetch_assoc()['total'];
    $totalPages = ceil($totalLearners / $limit);

    // Return optimized response
    $response = [
        'status' => 'success',
        'data' => $learners,
        'pagination' => [
            'page' => $page,
            'limit' => $limit,
            'total' => (int)$totalLearners,
            'totalPages' => $totalPages,
            'hasNext' => $page < $totalPages
        ],
        'meta' => [
            'includedFingerprints' => $includeFingerprints,
            'fieldsCount' => count($selectedFields),
            'responseSize' => strlen(json_encode($learners))
        ]
    ];

    echo json_encode($response);
    $stmt->close();
    $countStmt->close();

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