<?php

require_once __DIR__ . '/../security_functions.php';
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

// DEBUG: Log all incoming parameters
error_log('[SEARCH_GLOBAL] GET params: ' . json_encode($_GET));
error_log('[SEARCH_GLOBAL] POST params: ' . json_encode($_POST));

// Get parameters - support multiple parameter names for compatibility
$idNumber = '';

// Try different parameter names that might be used
$paramNames = ['id_number', 'search', 'idNumber', 'ID_number', 'learner_id'];
foreach ($paramNames as $param) {
    if (isset($_GET[$param]) && !empty(trim($_GET[$param]))) {
        $idNumber = trim($_GET[$param]);
        error_log("[SEARCH_GLOBAL] Found ID via GET[$param]: $idNumber");
        break;
    }
}

// Also check POST parameters as fallback
if (empty($idNumber)) {
    foreach ($paramNames as $param) {
        if (isset($_POST[$param]) && !empty(trim($_POST[$param]))) {
            $idNumber = trim($_POST[$param]);
            error_log("[SEARCH_GLOBAL] Found ID via POST[$param]: $idNumber");
            break;
        }
    }
}

$sdpId = isset($_GET['sdp_id']) ? trim($_GET['sdp_id']) : '';
$projectId = isset($_GET['project_id']) ? trim($_GET['project_id']) : '';
$pathwayId = isset($_GET['pathway_id']) ? trim($_GET['pathway_id']) : '';
$qualificationId = isset($_GET['qualification_id']) ? trim($_GET['qualification_id']) : '';

error_log("[SEARCH_GLOBAL] Extracted - ID: '$idNumber', SDP: '$sdpId', Project: '$projectId'");

// Validate input - provide more specific error message
if (empty($idNumber)) {
    $errorResponse = [
        'success' => false,
        'message' => 'Search parameter is required',
        'debug' => [
            'received_get' => $_GET,
            'received_post' => $_POST,
            'expected_params' => ['id_number', 'search', 'idNumber', 'ID_number', 'learner_id'],
            'extracted_id' => $idNumber,
            'query_string' => $_SERVER['QUERY_STRING'] ?? ''
        ]
    ];
    error_log('[SEARCH_GLOBAL] ERROR: No ID parameter found. Response: ' . json_encode($errorResponse));
    echo json_encode($errorResponse);
    exit;
}

// Require both sdpId and projectId for strict filtering
if (empty($sdpId) || empty($projectId)) {
    echo json_encode([
        'success' => false,
        'message' => 'Both SDP ID and Project ID are required for search',
        'debug' => [
            'sdp_id' => $sdpId,
            'project_id' => $projectId
        ]
    ]);
    exit;
}

try {
    $optionalApplied = false;
    $wherePathway = '';
    $whereQualification = '';

    // Base required params
    $paramsBase = [$idNumber, $projectId, $sdpId];
    $typesBase = 'sss';

    $paramsStrict = $paramsBase;
    $typesStrict = $typesBase;

    if (!empty($pathwayId)) {
        $optionalApplied = true;
        $wherePathway =
            " AND TRIM(LOWER(s.Project_pathway)) = TRIM(LOWER(?))";
        $paramsStrict[] = $pathwayId;
        $typesStrict .= 's';
    }

    if (!empty($qualificationId)) {
        $optionalApplied = true;
        // Match admin offline behavior: include null/empty qualification sites
        $whereQualification =
            " AND (TRIM(s.qualification_id) = TRIM(?) OR s.qualification_id IS NULL OR s.qualification_id = '')";
        $paramsStrict[] = $qualificationId;
        $typesStrict .= 's';
    }

    $baseQuery = "
        SELECT 
            l.LearnerID as learner_id,
            l.Name as name,
            l.Surname as surname,
            l.IDNumber as id_number,
            l.classID as class_id,
            c.className as class_name,
            s.siteName as site_name,
            s.siteID as site_id,
            s.project_id,
            s.sdp_id
        FROM learnerdetails l
        INNER JOIN class c ON l.classID = c.classID
        INNER JOIN sites s ON c.siteID = s.siteID
        INNER JOIN project p ON s.project_id = p.project_id
        INNER JOIN sdp sd ON sd.sdp_id = s.sdp_id
        WHERE l.IDNumber = ?
        AND p.project_id = ?
        AND sd.sdp_id = ?
    ";

    $strictQuery = $baseQuery . $wherePathway . $whereQualification . "
        GROUP BY l.IDNumber
        LIMIT 1
    ";

    $stmt = $conn->prepare($strictQuery);
    if (!$stmt) {
        throw new Exception('Query preparation failed: ' . $conn->error);
    }
    $stmt->bind_param($typesStrict, ...$paramsStrict);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $learner = $result->fetch_assoc();
        echo json_encode([
            'success' => true,
            'learners' => [$learner],
            'learner' => $learner,
            'message' => 'Learner found'
        ]);
        $stmt->close();
        $conn->close();
        exit;
    }

    // If strict context filters returned nothing, retry without them
    if ($optionalApplied) {
        $fallbackQuery = $baseQuery . "
            GROUP BY l.IDNumber
            LIMIT 1
        ";

        $stmt2 = $conn->prepare($fallbackQuery);
        if (!$stmt2) {
            throw new Exception('Fallback query preparation failed: ' . $conn->error);
        }
        $stmt2->bind_param($typesBase, ...$paramsBase);
        $stmt2->execute();
        $result2 = $stmt2->get_result();

        if ($result2->num_rows > 0) {
            $learner = $result2->fetch_assoc();
            echo json_encode([
                'success' => true,
                'learners' => [$learner],
                'learner' => $learner,
                'message' => 'Learner found (fallback)'
            ]);
            $stmt2->close();
            $conn->close();
            exit;
        }
        $stmt2->close();
    }

    echo json_encode([
        'success' => false,
        'message' => 'No learner found with this ID number in this project',
        'searched_id' => $idNumber,
        'learners' => []
    ]);

    $stmt->close();

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
