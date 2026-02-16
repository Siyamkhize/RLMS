<?php
header('Content-Type: application/json');
include 'connection.php';

$response = array("success" => false, "message" => "Unknown error occurred");

// Auto-create device_logs table if it doesn't exist
function createDeviceLogsTable($conn) {
    $createTableSQL = "
        CREATE TABLE IF NOT EXISTS device_logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            device_id VARCHAR(255) NOT NULL,
            device_model VARCHAR(255),
            app_version VARCHAR(50),
            timestamp DATETIME,
            logs LONGTEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_device_timestamp (device_id, timestamp),
            INDEX idx_timestamp (timestamp)
        )
    ";
    
    if ($conn->query($createTableSQL) === TRUE) {
        error_log("device_logs table created or already exists");
        return true;
    } else {
        error_log("Error creating device_logs table: " . $conn->error);
        return false;
    }
}

// Ensure table exists
createDeviceLogsTable($conn);

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Collect logs from devices
    $input = json_decode(file_get_contents('php://input'), true);
    
    if ($input) {
        $deviceId = $input['device_id'] ?? '';
        $deviceModel = $input['device_model'] ?? '';
        $appVersion = $input['app_version'] ?? '';
        $timestamp = $input['timestamp'] ?? date('Y-m-d H:i:s');
        $logs = $input['logs'] ?? '';
        
        $stmt = $conn->prepare("INSERT INTO device_logs (device_id, device_model, app_version, timestamp, logs) VALUES (?, ?, ?, ?, ?)");
        $stmt->bind_param("sssss", $deviceId, $deviceModel, $appVersion, $timestamp, $logs);
        
        if ($stmt->execute()) {
            $response['success'] = true;
            $response['message'] = 'Logs collected successfully';
        } else {
            $response['message'] = 'Failed to store logs: ' . $stmt->error;
        }
        $stmt->close();
    } else {
        $response['message'] = 'Invalid JSON data';
    }
    
} else if ($_SERVER["REQUEST_METHOD"] == "GET" && isset($_GET['action']) && $_GET['action'] == 'get_logs') {
    // Retrieve logs from all devices
    $fromTime = $_GET['from'] ?? date('Y-m-d 00:00:00');
    $toTime = $_GET['to'] ?? date('Y-m-d 23:59:59');
    
    $stmt = $conn->prepare("SELECT device_id, device_model, timestamp, logs FROM device_logs WHERE timestamp BETWEEN ? AND ? ORDER BY timestamp DESC");
    $stmt->bind_param("ss", $fromTime, $toTime);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $allLogs = [];
    while ($row = $result->fetch_assoc()) {
        $allLogs[] = $row;
    }
    
    $response['success'] = true;
    $response['data'] = $allLogs;
    $stmt->close();
} else {
    $response['message'] = 'Invalid request method';
}

$conn->close();
echo json_encode($response);
?>

-- SQL to create the table:
-- CREATE TABLE device_logs (
--     id INT AUTO_INCREMENT PRIMARY KEY,
--     device_id VARCHAR(255) NOT NULL,
--     device_model VARCHAR(255),
--     app_version VARCHAR(50),
--     timestamp DATETIME,
--     logs LONGTEXT,
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );