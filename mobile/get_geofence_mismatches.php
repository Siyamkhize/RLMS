<?php

/**
 * Get recent geofence mismatch logs so you can manually
 * inspect and update site coordinates yourself.
 *
 * Example:
 *   https://your-server/mobile/get_geofence_mismatches.php?limit=50
 *
 * Depends on the `security_events` table used by security_log.php.
 */

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

require_once __DIR__ . '/connection.php';

if (!isset($conn)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Database connection failed']);
    exit;
}

// How many records to return (default 50, max 500)
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;
if ($limit <= 0) $limit = 50;
if ($limit > 500) $limit = 500;

try {
    // Only geofence mismatch events
    $stmt = $conn->prepare(
        "SELECT id, event_type, learner_id, class_id, data, event_timestamp, created_at
         FROM security_events
         WHERE event_type LIKE 'geofence_mismatch_%'
         ORDER BY id DESC
         LIMIT ?"
    );

    $stmt->bind_param('i', $limit);
    $stmt->execute();
    $result = $stmt->get_result();

    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $data = [];
        if (!empty($row['data'])) {
            $decoded = json_decode($row['data'], true);
            if (is_array($decoded)) {
                $data = $decoded;
            }
        }

        $rows[] = [
            'id' => (int)$row['id'],
            'event_type' => $row['event_type'],
            'learner_id' => $row['learner_id'],
            'class_id' => $row['class_id'],
            'event_timestamp' => $row['event_timestamp'],
            'created_at' => $row['created_at'],
            // Useful coordinates for manual correction:
            'site_latitude' => $data['site_latitude'] ?? null,
            'site_longitude' => $data['site_longitude'] ?? null,
            'site_name' => $data['site_name'] ?? null,
            'user_latitude' => $data['user_latitude'] ?? null,
            'user_longitude' => $data['user_longitude'] ?? null,
            'user_accuracy_m' => $data['user_accuracy_m'] ?? null,
            'distance_to_site_m' => $data['distance_to_site_m'] ?? null,
        ];
    }

    $stmt->close();

    echo json_encode([
        'success' => true,
        'count' => count($rows),
        'records' => $rows,
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server error: ' . $e->getMessage(),
    ]);
}

