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
 *
 * @return array
 * @throws Exception
 */
function fetchLearnersBySdp(mysqli $mysqli, ?int $sdpId, ?string $sdpName): array
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
    ";

    $statement = $mysqli->prepare($sql);
    if (!$statement) {
        throw new Exception('Failed to prepare statement: ' . $mysqli->error);
    }

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

    return $learners;
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

    $mysqli = resolveDatabaseConnection();
    $learners = fetchLearnersBySdp($mysqli, $sdpId, $sdpName);

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
        'total' => count($learners),
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

