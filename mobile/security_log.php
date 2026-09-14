<?php
/**
 * Security event logging endpoint.
 * Receives security events (mock location, impossible movement, etc.)
 * and stores them for audit purposes.
 *
 * Create the table if it does not exist:
 * CREATE TABLE IF NOT EXISTS security_events (
 *   id INT AUTO_INCREMENT PRIMARY KEY,
 *   event_type VARCHAR(64) NOT NULL,
 *   learner_id VARCHAR(64) DEFAULT NULL,
 *   class_id VARCHAR(64) DEFAULT NULL,
 *   data JSON DEFAULT NULL,
 *   event_timestamp DATETIME NOT NULL,
 *   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 *   ip_address VARCHAR(45) DEFAULT NULL,
 *   user_agent TEXT DEFAULT NULL
 * ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 */

require_once __DIR__ . '/security_functions.php';
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'POST required']);
    exit;
}

$response = ['success' => false];

try {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        $response['error'] = 'Invalid JSON';
        echo json_encode($response);
        exit;
    }

    $eventType = $input['event_type'] ?? 'unknown';
    $learnerId = $input['learner_id'] ?? null;
    $classId = $input['class_id'] ?? null;
    $data = $input['data'] ?? [];
    $eventTimestamp = $input['timestamp'] ?? date('Y-m-d\TH:i:s.u\Z');

    if (empty($eventType)) {
        $response['error'] = 'Missing event_type';
        echo json_encode($response);
        exit;
    }

    include __DIR__ . '/connection.php';
    if (!isset($conn)) {
        $response['error'] = 'Database connection failed';
        echo json_encode($response);
        exit;
    }

    // Create table if not exists
    $conn->query(
        "CREATE TABLE IF NOT EXISTS security_events (
            id INT AUTO_INCREMENT PRIMARY KEY,
            event_type VARCHAR(64) NOT NULL,
            learner_id VARCHAR(64) DEFAULT NULL,
            class_id VARCHAR(64) DEFAULT NULL,
            data JSON DEFAULT NULL,
            event_timestamp DATETIME NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            ip_address VARCHAR(45) DEFAULT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    );

    // Parse ISO timestamp to MySQL datetime
    $parsed = DateTime::createFromFormat('Y-m-d\TH:i:s.u\Z', $eventTimestamp);
    if (!$parsed) {
        $parsed = DateTime::createFromFormat('Y-m-d\TH:i:s\Z', $eventTimestamp);
    }
    if (!$parsed) {
        $parsed = new DateTime($eventTimestamp);
    }
    $mysqlTimestamp = $parsed->format('Y-m-d H:i:s');

    $ipAddress = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? null;

    $stmt = $conn->prepare(
        "INSERT INTO security_events (event_type, learner_id, class_id, data, event_timestamp, ip_address)
         VALUES (?, ?, ?, ?, ?, ?)"
    );

    $dataJson = json_encode($data);
    $stmt->bind_param(
        "ssssss",
        $eventType,
        $learnerId,
        $classId,
        $dataJson,
        $mysqlTimestamp,
        $ipAddress
    );

    if ($stmt->execute()) {
        $response['success'] = true;
    } else {
        $response['error'] = 'Insert failed';
    }

    $stmt->close();
    echo json_encode($response);
} catch (Exception $e) {
    error_log('security_log.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server error',
    ]);
}
