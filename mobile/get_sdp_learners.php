<?php
/**
 * Fetch all learners that belong to a specific SDP.
 * Accepts either `sdp_id` (int) or `sdp_name` (string) as query parameters.
 * Example: get_sdp_learners.php?sdp_id=12
 */

// Enable error reporting during development (disable in production)
error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    include_once __DIR__ . '/connection.php';
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Unable to load connection.php',
        'details' => $e->getMessage(),
    ]);
    exit();
}

/**
 * Resolve a MySQLi connection regardless of the variable name used in connection.php.
 *
 * @return mysqli
 * @throws Exception
 */
function resolveDatabaseConnection(): mysqli
{
    $candidates = ['connection', 'conn', 'db', 'mysqli'];

    foreach ($candidates as $name) {
        if (isset($GLOBALS[$name]) && $GLOBALS[$name] instanceof mysqli) {
            return $GLOBALS[$name];
        }
    }

    throw new Exception('No MySQLi connection instance found. Expected $connection, $conn, $db, or $mysqli.');
}

/**
 * Bind parameters to a prepared statement with dynamic arguments.
 *
 * @param mysqli_stmt $statement
 * @param string      $types
 * @param array       $params
 */
function bindStatementParams(mysqli_stmt $statement, string $types, array $params): void
{
    $bindParams = [];
    $bindParams[] = $types;

    foreach ($params as $key => $value) {
        $bindParams[] = &$params[$key];
    }

    call_user_func_array([$statement, 'bind_param'], $bindParams);
}

/**
 * Retrieve learners for a given SDP identifier.
 *
 * @param mysqli      $mysqli
 * @param int|null    $sdpId
 * @param string|null $sdpName
 * @param int         $page
 * @param int         $pageSize
 *
 * @return array
 * @throws Exception
 */
function fetchLearnersBySdp(mysqli $mysqli, ?int $sdpId, ?string $sdpName, int $page = 1, int $pageSize = 30): array
{
    $conditions = [];
    $params = [];
    $types = '';

    if ($sdpId !== null) {
        $conditions[] = 'site.sdp_id = ?';
        $params[] = $sdpId;
        $types .= 'i';
    }

    if ($sdpName !== null && $sdpName !== '') {
        $conditions[] = 'LOWER(s.sdp_name) = ?';
        $params[] = mb_strtolower($sdpName, 'UTF-8');
        $types .= 's';
    }

    if (empty($conditions)) {
        throw new InvalidArgumentException('Provide at least one of sdp_id or sdp_name.');
    }

    $wrappedConditions = array_map(function ($clause) {
        return '(' . $clause . ')';
    }, $conditions);

    $whereClause = implode(' OR ', $wrappedConditions);

    // Get total count for pagination
    $countSql = "
        SELECT COUNT(*) as total
        FROM learnerdetails l
        LEFT JOIN class c ON l.classID = c.classID
        LEFT JOIN sites site ON c.siteID = site.siteID
        LEFT JOIN sdp s ON site.sdp_id = s.sdp_id
        WHERE $whereClause
    ";

    $countStmt = $mysqli->prepare($countSql);
    if (!$countStmt) {
        throw new Exception('Failed to prepare count statement: ' . $mysqli->error);
    }

    bindStatementParams($countStmt, $types, $params);
    
    if (!$countStmt->execute()) {
        $error = $countStmt->error;
        $countStmt->close();
        throw new Exception('Failed to execute count query: ' . $error);
    }

    $countResult = $countStmt->get_result();
    $totalCount = $countResult->fetch_assoc()['total'];
    $countStmt->close();

    // Calculate pagination
    $offset = ($page - 1) * $pageSize;
    $totalPages = ceil($totalCount / $pageSize);
    $hasMore = ($offset + $pageSize) < $totalCount;

    $sql = "
        SELECT 
            l.LearnerID,
            l.Name,
            l.Surname,
            l.IDNumber,
            l.classID,
            COALESCE(c.className, 'Unknown Class') AS className,
            site.siteID,
            site.siteName,
            s.sdp_id,
            s.sdp_name
        FROM learnerdetails l
        LEFT JOIN class c ON l.classID = c.classID
        LEFT JOIN sites site ON c.siteID = site.siteID
        LEFT JOIN sdp s ON site.sdp_id = s.sdp_id
        WHERE $whereClause
        ORDER BY 
            c.className ASC,
            l.Surname ASC,
            l.Name ASC
        LIMIT ? OFFSET ?
    ";

    $statement = $mysqli->prepare($sql);
    if (!$statement) {
        throw new Exception('Failed to prepare statement: ' . $mysqli->error);
    }

    // Add pagination parameters
    $params[] = $pageSize;
    $params[] = $offset;
    $types .= 'ii';

    bindStatementParams($statement, $types, $params);

    if (!$statement->execute()) {
        $error = $statement->error;
        $statement->close();
        throw new Exception('Failed to execute query: ' . $error);
    }

    $result = $statement->get_result();
    $learners = [];

    while ($row = $result->fetch_assoc()) {
        $learners[] = $row;
    }

    $statement->close();

    return [
        'data' => $learners,
        'pagination' => [
            'page' => $page,
            'pageSize' => $pageSize,
            'total' => $totalCount,
            'totalPages' => $totalPages,
            'hasMore' => $hasMore
        ]
    ];
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        http_response_code(405);
        echo json_encode([
            'status' => 'error',
            'message' => 'Method not allowed. Use GET to retrieve learners.',
        ]);
        exit();
    }

    $sdpId = isset($_GET['sdp_id']) ? (int) $_GET['sdp_id'] : null;
    $sdpName = isset($_GET['sdp_name']) ? trim($_GET['sdp_name']) : null;
    $page = isset($_GET['page']) ? max(1, (int) $_GET['page']) : 1;
    $pageSize = isset($_GET['pageSize']) ? min(100, max(1, (int) $_GET['pageSize'])) : 30;

    $mysqli = resolveDatabaseConnection();
    $result = fetchLearnersBySdp($mysqli, $sdpId, $sdpName, $page, $pageSize);
    $learners = $result['data'];
    $pagination = $result['pagination'];

    $sdpMeta = null;
    if (!empty($learners)) {
        $first = $learners[0];
        $sdpMeta = [
            'sdp_id' => $first['sdp_id'] ?? $sdpId,
            'sdp_name' => $first['sdp_name'] ?? $sdpName,
        ];
    } else {
        $sdpMeta = [
            'sdp_id' => $sdpId,
            'sdp_name' => $sdpName,
        ];
    }

    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'message' => 'Learners retrieved successfully',
        'filters' => [
            'sdp_id' => $sdpId,
            'sdp_name' => $sdpName,
        ],
        'sdp' => $sdpMeta,
        'total' => $pagination['total'],
        'pagination' => $pagination,
        'data' => $learners,
    ]);
} catch (InvalidArgumentException $invalidArgumentException) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $invalidArgumentException->getMessage(),
    ]);
} catch (Throwable $throwable) {
    error_log('get_sdp_learners.php error: ' . $throwable->getMessage());
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Unable to retrieve learners.',
        'details' => $throwable->getMessage(),
    ]);
}
?>

