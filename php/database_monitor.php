<?php
// database_monitor.php - Monitor database changes and triggers

header('Content-Type: application/json');
include 'connection.php';
include 'clocking_debug_logger.php';

$response = array("success" => false, "message" => "Unknown error occurred");

try {
    logClockingEvent('INFO', 'DATABASE MONITOR STARTED', [
        'request_time' => date('Y-m-d H:i:s')
    ]);

    // Check for database triggers
    $triggers = [];
    $result = $conn->query("SHOW TRIGGERS");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $triggers[] = $row;
        }
    }

    logClockingEvent('INFO', 'Database triggers found', [
        'triggers' => $triggers
    ]);

    // Check for stored procedures
    $procedures = [];
    $result = $conn->query("SHOW PROCEDURE STATUS WHERE Db = DATABASE()");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $procedures[] = $row;
        }
    }

    logClockingEvent('INFO', 'Stored procedures found', [
        'procedures' => $procedures
    ]);

    // Check for events (scheduled tasks)
    $events = [];
    $result = $conn->query("SHOW EVENTS");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $events[] = $row;
        }
    }

    logClockingEvent('INFO', 'Database events found', [
        'events' => $events
    ]);

    // Check recent changes to clocking tables
    $recentChanges = [];
    
    // Get recent learner_clocking records
    $result = $conn->query("SELECT LearnerID, clock_date, clock_in_time, clock_out_time, contact_time, UNIX_TIMESTAMP(clock_in_time) as clock_in_timestamp, UNIX_TIMESTAMP(clock_out_time) as clock_out_timestamp FROM learner_clocking WHERE clock_date >= CURDATE() - INTERVAL 1 DAY ORDER BY clock_date DESC, clock_in_time DESC LIMIT 50");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $recentChanges[] = $row;
            
            // Check for suspicious patterns
            if (!empty($row['clock_in_time']) && !empty($row['clock_out_time'])) {
                $clockInTime = strtotime($row['clock_in_time']);
                $clockOutTime = strtotime($row['clock_out_time']);
                $timeDiff = $clockOutTime - $clockInTime;
                
                // Flag sessions that are suspiciously short (less than 5 minutes)
                if ($timeDiff < 300) {
                    logClockingEvent('WARNING', 'Suspicious short session detected', [
                        'learner_id' => $row['LearnerID'],
                        'clock_in_time' => $row['clock_in_time'],
                        'clock_out_time' => $row['clock_out_time'],
                        'duration_seconds' => $timeDiff,
                        'duration_minutes' => round($timeDiff / 60, 2)
                    ]);
                }
                
                // Flag sessions where clock-out is exactly 2 minutes after clock-in
                if ($timeDiff >= 115 && $timeDiff <= 125) { // 2 minutes +/- 5 seconds
                    logClockingEvent('CRITICAL', 'AUTO CLOCK-OUT PATTERN DETECTED - 2 MINUTE SESSION', [
                        'learner_id' => $row['LearnerID'],
                        'clock_in_time' => $row['clock_in_time'],
                        'clock_out_time' => $row['clock_out_time'],
                        'duration_seconds' => $timeDiff,
                        'pattern' => 'EXACTLY_2_MINUTES'
                    ]);
                }
            }
        }
    }

    // Check clocking_log for recent activity
    $clockingLogEntries = [];
    $result = $conn->query("SELECT learnerID, action, attempt_time, user_latitude, user_longitude, accuracy, reason FROM clocking_log WHERE DATE(attempt_time) >= CURDATE() ORDER BY attempt_time DESC LIMIT 100");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $clockingLogEntries[] = $row;
        }
    }

    logClockingEvent('INFO', 'Recent clocking activity', [
        'recent_changes_count' => count($recentChanges),
        'clocking_log_entries_count' => count($clockingLogEntries)
    ]);

    // Check for database schema information
    $tableStructures = [];
    $tables = ['learner_clocking', 'clocking_log', 'induction_clocking'];
    
    foreach ($tables as $table) {
        $result = $conn->query("DESCRIBE $table");
        if ($result) {
            $structure = [];
            while ($row = $result->fetch_assoc()) {
                $structure[] = $row;
            }
            $tableStructures[$table] = $structure;
        }
    }

    logClockingEvent('INFO', 'Table structures analyzed', [
        'tables' => $tableStructures
    ]);

    $response = [
        'success' => true,
        'message' => 'Database monitoring completed',
        'data' => [
            'triggers' => $triggers,
            'procedures' => $procedures,
            'events' => $events,
            'recent_changes' => $recentChanges,
            'clocking_log_entries' => $clockingLogEntries,
            'table_structures' => $tableStructures,
            'timestamp' => date('Y-m-d H:i:s')
        ]
    ];

    logClockingEvent('INFO', 'DATABASE MONITOR COMPLETED', [
        'findings' => [
            'triggers_count' => count($triggers),
            'procedures_count' => count($procedures),
            'events_count' => count($events),
            'recent_changes_count' => count($recentChanges),
            'log_entries_count' => count($clockingLogEntries)
        ]
    ]);

} catch (Exception $e) {
    logClockingEvent('CRITICAL', 'Exception in database monitor', [
        'error' => $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ]);
    
    $response['success'] = false;
    $response['message'] = 'Database monitoring error';
    $response['error_details'] = $e->getMessage();
}

$conn->close();
echo json_encode($response, JSON_PRETTY_PRINT);
?>