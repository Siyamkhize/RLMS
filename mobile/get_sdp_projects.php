<?php

require_once __DIR__ . '/../security_functions.php';
// Suppress warnings/notices for clean JSON output
error_reporting(E_ALL & ~E_WARNING & ~E_NOTICE);
ini_set('display_errors', 0);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST');
header('Access-Control-Allow-Headers: Content-Type');

// Load database connection (parent folder: assessorReport2/connection.php)
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

    // Resolve SDP identifier to sdp_id and sdp_name
    $sdpInfo = _resolve_sdp_identifier($conn, $sdpIdentifier);
    if (!$sdpInfo) {
        _json_out(['success' => false, 'message' => 'Invalid SDP identifier: ' . $sdpIdentifier], 400);
    }
    
    $sdpIdNumeric = $sdpInfo['sdp_id'];
    $sdpName = $sdpInfo['sdp_name'];

    // Optimized query: compute active_sites + total_learners with joins (no per-project subqueries)
    $query = "
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

    $stmt = $conn->prepare($query);
    if (!$stmt) {
        throw new Exception('Failed to prepare statement: ' . $conn->error);
    }
    
    // 3 placeholders: (int sdp_id), (string sdp_name), (int sdp_id)
    $stmt->bind_param('isi', $sdpIdNumeric, $sdpName, $sdpIdNumeric);
    
    if (!$stmt->execute()) {
        throw new Exception('Failed to execute query: ' . $stmt->error);
    }

    $result = $stmt->get_result();
    $projects = [];

    while ($row = $result->fetch_assoc()) {
        $projectPathwayJson = $row['Project_pathway'] ?? '';
        $parsed = _parse_pathway_json($projectPathwayJson);
        
        $projects[] = [
            'project_id' => $row['project_id'] ?? null,
            'project_name' => $row['Project_name'] ?? 'Unknown Project',
            'Project_name' => $row['Project_name'] ?? 'Unknown Project',
            'Project_pathway' => $projectPathwayJson,
            'Project_pathway_raw' => $projectPathwayJson,
            'active_sites' => isset($row['active_sites']) ? (int)$row['active_sites'] : 0,
            'total_learners' => isset($row['total_learners']) ? (int)$row['total_learners'] : 0,
            'pathways' => $parsed['pathways'],
            'pathway_count' => count($parsed['pathways']),
            'qualifications' => $parsed['qualifications'],
            'qualification_count' => count($parsed['qualifications'])
        ];
    }

    $stmt->close();

    _json_out([
        'success' => true,
        'projects' => $projects,
        'count' => count($projects),
        'sdp_id' => $sdpIdNumeric,
        'sdp_name' => $sdpName,
    ]);

} catch (Exception $e) {
    _json_out(['success' => false, 'message' => 'Error: ' . $e->getMessage()], 500);
}

$conn->close();
