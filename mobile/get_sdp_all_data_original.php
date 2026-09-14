<?php
error_reporting(E_ALL & ~E_WARNING & ~E_NOTICE);
ini_set('display_errors', 0);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST');
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

function _parse_pathway_json($jsonStr) {
    $pathways = [];
    $qualifications = [];
    
    if (empty($jsonStr)) {
        return ['pathways' => $pathways, 'qualifications' => $qualifications];
    }
    
    $decoded = json_decode($jsonStr, true);
    if (!is_array($decoded)) {
        return ['pathways' => $pathways, 'qualifications' => $qualifications];
    }
    
    foreach ($decoded as $pathway) {
        if (!is_array($pathway)) continue;
        
        if (isset($pathway['name'])) {
            $pathways[] = $pathway['name'];
        }
        
        if (isset($pathway['qual_types']) && is_array($pathway['qual_types'])) {
            foreach ($pathway['qual_types'] as $qt) {
                if (is_array($qt) && isset($qt['qualification']) && is_array($qt['qualification'])) {
                    if (isset($qt['qualification']['name'])) {
                        $qualifications[] = $qt['qualification']['name'];
                    }
                }
            }
        }
    }
    
    return [
        'pathways' => array_values(array_unique($pathways)),
        'qualifications' => array_values(array_unique($qualifications))
    ];
}

try {
    // Get SDP identifier - prefer unified "sdpId"
    $sdpIdentifier = _first_param(['sdpId', 'sdp_identifier', 'sdp_id']);
    
    if (empty($sdpIdentifier)) {
        _json_out(['success' => false, 'message' => 'SDP identifier is required'], 400);
    }

    // Resolve SDP identifier
    $sdpInfo = _resolve_sdp_identifier($conn, $sdpIdentifier);
    if (!$sdpInfo) {
        _json_out(['success' => false, 'message' => 'Invalid SDP identifier: ' . $sdpIdentifier], 400);
    }
    
    $sdpIdNumeric = $sdpInfo['sdp_id'];
    $sdpName = $sdpInfo['sdp_name'];

    // Optional filters
    $project_id = _first_param(['project_id']);
    $pathway_id = _first_param(['pathway_id', 'pathway']);
    $qualification_id = _first_param(['qualification_id']);

    // ============================================
    // SECTION 1: GET PROJECTS
    // ============================================
    $queryProjects = "
        SELECT 
            p.project_id,
            p.Project_name,
            p.Project_pathway,
            COUNT(DISTINCT s.siteID) AS active_sites,
            COUNT(DISTINCT l.LearnerID) AS total_learners
        FROM project p
        LEFT JOIN sites s ON s.project_id = p.project_id AND s.sdp_id = ?
        LEFT JOIN class c ON c.siteId = s.siteID
        LEFT JOIN learnerdetails l ON l.classID = c.classID
        WHERE p.sdp_name = ?
           OR p.project_id IN (SELECT DISTINCT s2.project_id FROM sites s2 WHERE s2.sdp_id = ?)
        GROUP BY p.project_id, p.Project_name, p.Project_pathway
        ORDER BY p.Project_name
    ";

    $stmtProjects = $conn->prepare($queryProjects);
    if (!$stmtProjects) {
        throw new Exception('Failed to prepare projects statement: ' . $conn->error);
    }
    
    $stmtProjects->bind_param('isi', $sdpIdNumeric, $sdpName, $sdpIdNumeric);
    
    if (!$stmtProjects->execute()) {
        throw new Exception('Failed to execute projects query: ' . $stmtProjects->error);
    }

    $resultProjects = $stmtProjects->get_result();
    $projects = [];
    $projectIds = [];

    while ($row = $resultProjects->fetch_assoc()) {
        $projectId = $row['project_id'] ?? null;
        $projectPathwayJson = $row['Project_pathway'] ?? '';
        $parsed = _parse_pathway_json($projectPathwayJson);
        
        $projectData = [
            'project_id' => $projectId,
            'project_name' => $row['Project_name'] ?? 'Unknown Project',
            'Project_name' => $row['Project_name'] ?? 'Unknown Project',
            'Project_pathway' => $projectPathwayJson,
            'Project_pathway_raw' => $projectPathwayJson,
            'active_sites' => isset($row['active_sites']) ? (int)$row['active_sites'] : 0,
            'total_learners' => isset($row['total_learners']) ? (int)$row['total_learners'] : 0,
            'pathways' => $parsed['pathways'],
            'pathway_count' => count($parsed['pathways']),
            'qualifications' => $parsed['qualifications'],
            'qualification_count' => count($parsed['qualifications']),
            'sites' => [] // Will be populated below
        ];
        
        $projects[] = $projectData;
        if ($projectId !== null) {
            $projectIds[] = $projectId;
        }
    }

    $stmtProjects->close();

    // ============================================
    // SECTION 2: GET SITES
    // ============================================
    $sqlSites = "SELECT 
                s.siteID,
                s.siteName,
                s.beneficiaries,
                COUNT(c.classId) AS classes,
                s.project_id,
                s.qualification_id,
                s.Project_pathway AS learningPathway,
                IF(s.latitude IS NOT NULL AND s.longitude IS NOT NULL,
                   CONCAT(FORMAT(s.latitude, 3), ',', FORMAT(s.longitude, 3)),
                   'No Coordinates Available') AS coordinates,
                s.Category AS category,
                s.province,
                p.Project_name AS project_name,
                sd.sdp_name,
                q.name AS qualification_name
            FROM sites s
            LEFT JOIN class c ON c.siteId = s.siteID
            LEFT JOIN project p ON p.project_id = s.project_id
            LEFT JOIN sdp sd ON sd.sdp_id = s.sdp_id
            LEFT JOIN qualification q ON CAST(q.qualification_id AS CHAR) = CAST(s.qualification_id AS CHAR)
            WHERE s.sdp_id = ?";
    $paramsSites = [$sdpIdNumeric];
    $typesSites = 'i';

    if (!empty($project_id)) {
        $project_id_int = is_numeric($project_id) ? intval($project_id) : 0;
        if ($project_id_int > 0) {
            $sqlSites .= " AND s.project_id = ?";
            $paramsSites[] = $project_id_int;
            $typesSites .= 'i';
        }
    }
    if (!empty($pathway_id)) {
        $sqlSites .= " AND TRIM(LOWER(s.Project_pathway)) = TRIM(LOWER(?))";
        $paramsSites[] = $pathway_id;
        $typesSites .= 's';
    }
    if (!empty($qualification_id)) {
        $sqlSites .= " AND TRIM(s.qualification_id) = TRIM(?)";
        $paramsSites[] = $qualification_id;
        $typesSites .= 's';
    }

    $sqlSites .= " GROUP BY 
                s.siteID, s.siteName, s.beneficiaries, s.Project_pathway,
                s.latitude, s.longitude, s.Category, s.province,
                s.project_id, s.sdp_id, s.qualification_id,
                p.Project_name, sd.sdp_name, q.name
            ORDER BY s.siteName";

    $stmtSites = $conn->prepare($sqlSites);
    if (!$stmtSites) {
        throw new Exception('Failed to prepare sites statement: ' . $conn->error);
    }

    $stmtSites->bind_param($typesSites, ...$paramsSites);
    $stmtSites->execute();
    $resultSites = $stmtSites->get_result();

    $allSites = [];
    $sitesByProject = [];

    while ($site_row = $resultSites->fetch_assoc()) {
        $row = array_map('strval', $site_row);

        // Compatibility keys expected by Flutter table
        if (isset($row['learningPathway'])) {
            $row['project_pathway'] = $row['learningPathway'];
            $row['pathways'] = [$row['learningPathway']];
            $row['pathway_count'] = 1;
        } else {
            $row['pathways'] = [];
            $row['pathway_count'] = 0;
        }

        $qualName = isset($row['qualification_name']) ? trim((string)$row['qualification_name']) : '';
        $qualId = isset($row['qualification_id']) ? trim((string)$row['qualification_id']) : '';
        if ($qualName !== '') {
            $row['qualifications'] = [$qualName];
        } elseif ($qualId !== '') {
            $row['qualifications'] = [$qualId];
        } else {
            $row['qualifications'] = [];
        }
        $row['qualification_count'] = count($row['qualifications']);

        $allSites[] = $row;

        // Group sites by project_id for hierarchical structure
        $siteProjectId = isset($row['project_id']) ? trim((string)$row['project_id']) : '';
        if ($siteProjectId !== '') {
            if (!isset($sitesByProject[$siteProjectId])) {
                $sitesByProject[$siteProjectId] = [];
            }
            $sitesByProject[$siteProjectId][] = $row;
        }
    }
    $stmtSites->close();

    // Attach sites to their projects
    foreach ($projects as &$project) {
        $pid = $project['project_id'] ?? null;
        if ($pid !== null && isset($sitesByProject[(string)$pid])) {
            $project['sites'] = $sitesByProject[(string)$pid];
        } else {
            $project['sites'] = [];
        }
    }
    unset($project);

    // ============================================
    // SECTION 3: BUILD RESPONSE
    // ============================================
    _json_out([
        'success' => true,
        'sdp_id' => $sdpIdNumeric,
        'sdp_name' => $sdpName,
        'projects' => $projects,
        'sites' => $allSites, // Flat list for backward compatibility
        'summary' => [
            'total_projects' => count($projects),
            'total_sites' => count($allSites),
            'total_pathways' => array_sum(array_column($projects, 'pathway_count')),
            'total_qualifications' => array_sum(array_column($projects, 'qualification_count')),
            'total_learners' => array_sum(array_column($projects, 'total_learners')),
        ],
        'filters_applied' => [
            'project_id' => $project_id ?: null,
            'pathway_id' => $pathway_id ?: null,
            'qualification_id' => $qualification_id ?: null,
        ],
    ]);

} catch (Exception $e) {
    _json_out(['success' => false, 'message' => 'Error: ' . $e->getMessage()], 500);
}

$conn->close();
