<?php
/**
 * Sync Learner Clocking Data - READ ONLY
 * Returns ALL columns for local sync including clock_out_time, contact_time,
 * user_latitude, user_longitude, user_accuracy, signature.
 *
 * If server table is missing columns, falls back to base columns only.
 * Run LEARNER_CLOCKING_MIGRATION.sql on server to add missing columns.
 *
 * URL: .../mobile/clocking/sync_learner_clocking.php?clock_date=YYYY-MM-DD&classID=123
 */

if (file_exists(__DIR__ . '/../../security_functions.php')) {
    require_once __DIR__ . '/../../security_functions.php';
}

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'GET required']);
    exit;
}

$clock_date = $_GET['clock_date'] ?? date('Y-m-d');
$classID = $_GET['classID'] ?? null;

// Resolve connection - mobile/connection.php or project root
$connectionPath = file_exists(__DIR__ . '/../connection.php')
    ? __DIR__ . '/../connection.php'
    : (file_exists(__DIR__ . '/../../connection.php') ? __DIR__ . '/../../connection.php' : null);

if (!$connectionPath) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Connection file not found']);
    exit;
}

require_once $connectionPath;

if (!isset($conn)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Database not connected']);
    exit;
}

try {
    $fullColumns = "lc.clocking_id, lc.LearnerID, lc.clock_date, lc.clock_in_time,
        lc.clock_out_time, lc.contact_time, lc.signature, lc.synced,
        lc.user_latitude, lc.user_longitude, lc.user_accuracy";
    $baseColumns = "lc.clocking_id, lc.LearnerID, lc.clock_date, lc.clock_in_time";

    $sqlBase = " FROM learner_clocking lc";
    if ($classID !== null && $classID !== '') {
        $sqlBase .= " INNER JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID";
    }

    $whereClauses = ["lc.clock_date = ?"];
    $params = [$clock_date];
    $types = "s";
    if ($classID !== null && $classID !== '') {
        $whereClauses[] = "ld.classID = ?";
        $params[] = $classID;
        $types .= "s";
    }
    $where = " WHERE " . implode(" AND ", $whereClauses);
    $order = " ORDER BY lc.clocking_id DESC";

    $clockingData = [];
    $queryOk = false;
    $stmt = null;

    try {
        $sql = "SELECT $fullColumns $sqlBase $where $order";
        $stmt = $conn->prepare($sql);
        if ($stmt && $stmt->bind_param($types, ...$params) && $stmt->execute()) {
            $queryOk = true;
            $result = $stmt->get_result();
            while ($row = $result->fetch_assoc()) {
                $clockingData[] = $row;
            }
        }
    } catch (Throwable $e) {
        $queryOk = false;
        error_log("[SYNC_CLOCKING] Full query failed: " . $e->getMessage());
    } finally {
        if ($stmt) {
            $stmt->close();
            $stmt = null;
        }
    }

    if (!$queryOk) {
        $stmt = $conn->prepare("SELECT $baseColumns $sqlBase $where $order");
        if (!$stmt) {
            throw new Exception($conn->error ?? 'Prepare failed');
        }
        if (!$stmt->bind_param($types, ...$params) || !$stmt->execute()) {
            $stmt->close();
            throw new Exception($conn->error ?? 'Query failed');
        }
        $clockingData = [];
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            $clockingData[] = array_merge($row, [
                'clock_out_time' => null,
                'contact_time' => null,
                'signature' => null,
                'synced' => 1,
                'user_latitude' => null,
                'user_longitude' => null,
                'user_accuracy' => null,
            ]);
        }
        $stmt->close();
    }

    echo json_encode($clockingData);
} catch (Exception $e) {
    error_log("[SYNC_CLOCKING] Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
