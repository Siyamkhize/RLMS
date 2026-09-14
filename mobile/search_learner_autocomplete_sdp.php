<?php
error_reporting(E_ALL & ~E_WARNING & ~E_NOTICE);
ini_set('display_errors', 0);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

try {
    if (file_exists(__DIR__ . '/../connection.php')) {
        require_once __DIR__ . '/../connection.php';
    } elseif (file_exists(__DIR__ . '/connection.php')) {
        require_once __DIR__ . '/connection.php';
    } else {
        throw new Exception('Database connection file not found');
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database connection failed']);
    exit;
}

function _first_param(array $keys, $default = '') {
    foreach ($keys as $k) {
        if (isset($_GET[$k])) {
            return trim($_GET[$k]);
        }
        if (isset($_POST[$k])) {
            return trim($_POST[$k]);
        }
    }
    return $default;
}

function _json_out(array $payload, int $statusCode = 200) {
    http_response_code($statusCode);
    $json = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if ($json === false) {
        $json = '{"success":false,"message":"Failed to encode JSON"}';
        http_response_code(500);
    }
    echo $json;
    exit;
}

function _resolve_sdp_identifier($conn, $sdpIdentifier) {
    if (empty($sdpIdentifier)) {
        return null;
    }
    
    $sdpIdNumeric = is_numeric($sdpIdentifier) ? intval($sdpIdentifier) : 0;
    $sdpName = '';
    
    if ($sdpIdNumeric > 0) {
        $stmt = $conn->prepare("SELECT sdp_id, sdp_name FROM sdp WHERE sdp_id = ? LIMIT 1");
        if ($stmt) {
            $stmt->bind_param('i', $sdpIdNumeric);
            $stmt->execute();
            $result = $stmt->get_result();
            if ($row = $result->fetch_assoc()) {
                $sdpIdNumeric = intval($row['sdp_id']);
                $sdpName = $row['sdp_name'];
            }
            $stmt->close();
        }
    } else {
        $stmt = $conn->prepare("SELECT sdp_id, sdp_name FROM sdp WHERE sdp_name = ? OR email = ? LIMIT 1");
        if ($stmt) {
            $stmt->bind_param('ss', $sdpIdentifier, $sdpIdentifier);
            $stmt->execute();
            $result = $stmt->get_result();
            if ($row = $result->fetch_assoc()) {
                $sdpIdNumeric = intval($row['sdp_id']);
                $sdpName = $row['sdp_name'];
            }
            $stmt->close();
        }
    }
    
    if ($sdpIdNumeric == 0 || empty($sdpName)) {
        return null;
    }
    
    return ['sdp_id' => $sdpIdNumeric, 'sdp_name' => $sdpName];
}

$query = _first_param(['q', 'query']);
$sdpId = _first_param(['sdpId', 'sdp_id', 'sdp_identifier']);
$projectId = _first_param(['project_id', 'projectId']);
$pathwayId = _first_param(['pathway_id', 'pathway']);
$qualificationId = _first_param(['qualification_id']);
$limit = intval(_first_param(['limit'], '8'));

if (empty($query) || strlen($query) < 2) {
    _json_out([
        'success' => false,
        'message' => 'Query must be at least 2 characters',
        'suggestions' => []
    ]);
}

if (empty($sdpId)) {
    _json_out([
        'success' => false,
        'message' => 'SDP ID is required',
        'suggestions' => []
    ]);
}

try {
    // Resolve SDP identifier
    $sdpInfo = _resolve_sdp_identifier($conn, $sdpId);
    if (!$sdpInfo) {
        _json_out([
            'success' => false,
            'message' => 'Invalid SDP identifier: ' . $sdpId,
            'suggestions' => []
        ]);
    }
    
    $sdpIdInt = $sdpInfo['sdp_id'];

    $projectFilterSql = '';
    $paramsProject = [];
    $optionalApplied = false;
    if (!empty($projectId)) {
        // Admin passes project_id to keep autocomplete within project scope
        $projectFilterSql = ' AND s.project_id = ?';
        $paramsProject[] = $projectId;
    }

    $pathwayFilterSql = '';
    $paramsPathway = [];
    if (!empty($pathwayId)) {
        $optionalApplied = true;
        $pathwayFilterSql =
            ' AND TRIM(LOWER(s.Project_pathway)) = TRIM(LOWER(?))';
        $paramsPathway[] = $pathwayId;
    }

    $qualificationFilterSql = '';
    $paramsQualification = [];
    if (!empty($qualificationId)) {
        $optionalApplied = true;
        // Match offline behavior: allow null/empty qualification_id sites
        $qualificationFilterSql =
            " AND (TRIM(s.qualification_id) = TRIM(?) OR s.qualification_id IS NULL OR s.qualification_id = '')";
        $paramsQualification[] = $qualificationId;
    }

    // Search within this SDP (and optionally within a specific project)
    $sqlBase = "
        SELECT 
            l.LearnerID,
            l.IDNumber,
            l.Name,
            l.Surname,
            l.classID,
            c.ClassName as class_name,
            s.siteName as site_name,
            s.siteID,
            s.project_id,
            p.Project_name as project_name
        FROM learnerdetails l
        INNER JOIN class c ON l.classID = c.classID
        INNER JOIN sites s ON c.siteID = s.siteID
        INNER JOIN project p ON s.project_id = p.project_id
        WHERE s.sdp_id = ? {$projectFilterSql}
        AND (
            l.IDNumber LIKE ? 
            OR l.Name LIKE ? 
            OR l.Surname LIKE ?
            OR CONCAT(l.Name, ' ', l.Surname) LIKE ?
            OR CONCAT(l.Surname, ' ', l.Name) LIKE ?
        )
        ORDER BY 
            CASE 
                WHEN l.IDNumber LIKE ? THEN 1
                WHEN l.Surname LIKE ? THEN 2
                ELSE 3
            END,
            l.Surname, l.Name
        LIMIT ?
    ";

    // Build strict query explicitly to ensure placeholders match bind_param order.
    $sqlStrict = "
        SELECT 
            l.LearnerID,
            l.IDNumber,
            l.Name,
            l.Surname,
            l.classID,
            c.ClassName as class_name,
            s.siteName as site_name,
            s.siteID,
            s.project_id,
            p.Project_name as project_name
        FROM learnerdetails l
        INNER JOIN class c ON l.classID = c.classID
        INNER JOIN sites s ON c.siteID = s.siteID
        INNER JOIN project p ON s.project_id = p.project_id
        WHERE s.sdp_id = ? {$projectFilterSql} {$pathwayFilterSql} {$qualificationFilterSql}
        AND (
            l.IDNumber LIKE ? 
            OR l.Name LIKE ? 
            OR l.Surname LIKE ?
            OR CONCAT(l.Name, ' ', l.Surname) LIKE ?
            OR CONCAT(l.Surname, ' ', l.Name) LIKE ?
        )
        ORDER BY 
            CASE 
                WHEN l.IDNumber LIKE ? THEN 1
                WHEN l.Surname LIKE ? THEN 2
                ELSE 3
            END,
            l.Surname, l.Name
        LIMIT ?
    ";
    
    $searchTerm = $query . '%';

    // Placeholder order:
    // 1) s.sdp_id
    // 2) (optional) s.project_id
    // 3) (optional) pathway_id / qualification_id
    // then 7 LIKE placeholders + LIMIT
    $paramsBase = array_merge(
        [$sdpIdInt],
        $paramsProject,
        [
            $searchTerm,
            $searchTerm,
            $searchTerm,
            $searchTerm,
            $searchTerm,
            $searchTerm,
            $searchTerm,
            $limit
        ]
    );

    $paramsStrict = array_merge(
        [$sdpIdInt],
        $paramsProject,
        $paramsPathway,
        $paramsQualification,
        [
            $searchTerm,
            $searchTerm,
            $searchTerm,
            $searchTerm,
            $searchTerm,
            $searchTerm,
            $searchTerm,
            $limit
        ]
    );

    // types: sdp_id is int ('i'), project/pathway/qualification are strings/ints, LIKE terms are strings, limit is int
    $typePartsStrict = ['i'];
    if (!empty($projectId)) $typePartsStrict[] = 'i';
    if (!empty($pathwayId)) $typePartsStrict[] = 's';
    if (!empty($qualificationId)) $typePartsStrict[] = 's';
    for ($i = 0; $i < 7; $i++) {
        $typePartsStrict[] = 's';
    }
    $typePartsStrict[] = 'i';
    $typesStrict = implode('', $typePartsStrict);

    $typesBase = empty($projectId) ? 'isssssssi' : 'issssssssi';

    // Run strict query first
    $stmt = $conn->prepare($sqlStrict);
    if (!$stmt) {
        throw new Exception('Query preparation failed: ' . $conn->error);
    }
    $stmt->bind_param($typesStrict, ...$paramsStrict);
    $stmt->execute();
    $result = $stmt->get_result();

    $suggestions = [];
    while ($row = $result->fetch_assoc()) {
        $suggestions[] = [
            'learner_id' => $row['LearnerID'],
            'id_number' => $row['IDNumber'],
            'name' => $row['Name'],
            'surname' => $row['Surname'],
            'class_id' => $row['classID'],
            'class_name' => $row['class_name'] ?? 'N/A',
            'site_name' => $row['site_name'] ?? 'N/A',
            'site_id' => $row['siteID'],
            'project_id' => $row['project_id'],
            'project_name' => $row['project_name'] ?? 'N/A',
            'display_text' => $row['Surname'] . ' ' . $row['Name'] . ' (' . $row['IDNumber'] . ')',
            'search_value' => $row['IDNumber']
        ];
    }

    // If strict context returned nothing, retry without pathway/qualification
    if ($optionalApplied && empty($suggestions)) {
        $stmt2 = $conn->prepare($sqlBase);
        if (!$stmt2) {
            throw new Exception('Base query preparation failed: ' . $conn->error);
        }
        $stmt2->bind_param($typesBase, ...$paramsBase);
        $stmt2->execute();
        $result2 = $stmt2->get_result();

        while ($row = $result2->fetch_assoc()) {
            $suggestions[] = [
                'learner_id' => $row['LearnerID'],
                'id_number' => $row['IDNumber'],
                'name' => $row['Name'],
                'surname' => $row['Surname'],
                'class_id' => $row['classID'],
                'class_name' => $row['class_name'] ?? 'N/A',
                'site_name' => $row['site_name'] ?? 'N/A',
                'site_id' => $row['siteID'],
                'project_id' => $row['project_id'],
                'project_name' => $row['project_name'] ?? 'N/A',
                'display_text' => $row['Surname'] . ' ' . $row['Name'] . ' (' . $row['IDNumber'] . ')',
                'search_value' => $row['IDNumber']
            ];
        }
        $stmt2->close();
    }

    $stmt->close();
    
    _json_out([
        'success' => true,
        'suggestions' => $suggestions,
        'count' => count($suggestions),
        'sdp_info' => $sdpInfo
    ]);
    
    $stmt->close();
    
} catch (Exception $e) {
    _json_out([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage(),
        'suggestions' => []
    ]);
}

$conn->close();
?>