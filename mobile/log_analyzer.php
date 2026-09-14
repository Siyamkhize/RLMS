<?php
// log_analyzer.php - Analyze clocking logs to identify patterns

header('Content-Type: text/html; charset=UTF-8');
include 'connection.php';
include 'clocking_debug_logger.php';

?>
<!DOCTYPE html>
<html>
<head>
    <title>Clocking Debug Log Analyzer</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .log-entry { margin: 10px 0; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
        .critical { background-color: #ffebee; border-color: #f44336; }
        .warning { background-color: #fff3e0; border-color: #ff9800; }
        .error { background-color: #ffebee; border-color: #f44336; }
        .info { background-color: #e3f2fd; border-color: #2196f3; }
        .debug { background-color: #f5f5f5; border-color: #9e9e9e; }
        .timestamp { font-weight: bold; color: #666; }
        .learner-id { font-weight: bold; color: #1976d2; }
        .auto-clockout { background-color: #ffcdd2; border: 2px solid #d32f2f; }
        .filter-controls { margin: 20px 0; padding: 15px; background: #f0f0f0; border-radius: 5px; }
        .stats { background: #e8f5e8; padding: 15px; margin: 20px 0; border-radius: 5px; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 3px; white-space: pre-wrap; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .pattern-alert { background: #ffccd5; padding: 10px; margin: 10px 0; border-radius: 5px; border-left: 5px solid #d32f2f; }
    </style>
</head>
<body>
    <h1>🔍 Clocking Debug Log Analyzer</h1>
    
    <?php
    try {
        // Get current date for log file
        $currentDate = $_GET['date'] ?? date('Y-m-d');
        $logFile = "logs/clocking_debug_$currentDate.log";
        
        echo "<div class='filter-controls'>";
        echo "<h3>Log Analysis for: $currentDate</h3>";
        echo "<form method='GET'>";
        echo "<label>Date: <input type='date' name='date' value='$currentDate'></label> ";
        echo "<input type='submit' value='Load Logs'>";
        echo "</form>";
        echo "</div>";
        
        if (!file_exists($logFile)) {
            echo "<div class='pattern-alert'>❌ Log file not found: $logFile</div>";
            echo "<p>Make sure the debug logging scripts are being used and have write permissions to the logs/ directory.</p>";
            exit;
        }
        
        $logContents = file_get_contents($logFile);
        $logLines = explode("\n", $logContents);
        
        $entries = [];
        $stats = [
            'total_entries' => 0,
            'clock_in_attempts' => 0,
            'clock_out_attempts' => 0,
            'auto_clockouts' => 0,
            'errors' => 0,
            'critical_events' => 0,
            'suspicious_patterns' => []
        ];
        
        // Parse log entries
        foreach ($logLines as $line) {
            if (empty(trim($line))) continue;
            
            $entry = json_decode($line, true);
            if ($entry) {
                $entries[] = $entry;
                $stats['total_entries']++;
                
                // Count different types of events
                if (strpos($entry['message'], 'CLOCK-IN ATTEMPT') !== false) {
                    $stats['clock_in_attempts']++;
                }
                if (strpos($entry['message'], 'CLOCK-OUT ATTEMPT') !== false) {
                    $stats['clock_out_attempts']++;
                }
                if (strpos($entry['message'], 'AUTO CLOCK-OUT DETECTED') !== false) {
                    $stats['auto_clockouts']++;
                }
                if ($entry['level'] === 'ERROR') {
                    $stats['errors']++;
                }
                if ($entry['level'] === 'CRITICAL') {
                    $stats['critical_events']++;
                }
            }
        }
        
        // Analyze patterns
        $learnerSessions = [];
        foreach ($entries as $entry) {
            if (isset($entry['data']['learner_id'])) {
                $learnerId = $entry['data']['learner_id'];
                if (!isset($learnerSessions[$learnerId])) {
                    $learnerSessions[$learnerId] = [];
                }
                $learnerSessions[$learnerId][] = $entry;
            }
        }
        
        // Look for auto clock-out patterns
        foreach ($learnerSessions as $learnerId => $sessions) {
            $clockInTime = null;
            $clockOutTime = null;
            
            foreach ($sessions as $session) {
                if (strpos($session['message'], 'CLOCK-IN ATTEMPT') !== false) {
                    $clockInTime = strtotime($session['timestamp']);
                }
                if (strpos($session['message'], 'CLOCK-OUT') !== false) {
                    $clockOutTime = strtotime($session['timestamp']);
                }
                
                if ($clockInTime && $clockOutTime) {
                    $timeDiff = $clockOutTime - $clockInTime;
                    if ($timeDiff > 0 && $timeDiff < 300) { // Less than 5 minutes
                        $stats['suspicious_patterns'][] = [
                            'learner_id' => $learnerId,
                            'pattern' => 'Short session',
                            'duration' => $timeDiff,
                            'clock_in' => date('Y-m-d H:i:s', $clockInTime),
                            'clock_out' => date('Y-m-d H:i:s', $clockOutTime)
                        ];
                    }
                }
            }
        }
        
        // Display statistics
        echo "<div class='stats'>";
        echo "<h3>📊 Log Statistics</h3>";
        echo "<table>";
        echo "<tr><th>Metric</th><th>Count</th></tr>";
        echo "<tr><td>Total Log Entries</td><td>{$stats['total_entries']}</td></tr>";
        echo "<tr><td>Clock-in Attempts</td><td>{$stats['clock_in_attempts']}</td></tr>";
        echo "<tr><td>Clock-out Attempts</td><td>{$stats['clock_out_attempts']}</td></tr>";
        echo "<tr><td>Auto Clock-outs Detected</td><td style='color: red; font-weight: bold;'>{$stats['auto_clockouts']}</td></tr>";
        echo "<tr><td>Errors</td><td>{$stats['errors']}</td></tr>";
        echo "<tr><td>Critical Events</td><td>{$stats['critical_events']}</td></tr>";
        echo "</table>";
        echo "</div>";
        
        // Display suspicious patterns
        if (!empty($stats['suspicious_patterns'])) {
            echo "<div class='pattern-alert'>";
            echo "<h3>🚨 Suspicious Patterns Detected</h3>";
            echo "<table>";
            echo "<tr><th>Learner ID</th><th>Pattern</th><th>Duration (seconds)</th><th>Clock In</th><th>Clock Out</th></tr>";
            foreach ($stats['suspicious_patterns'] as $pattern) {
                echo "<tr>";
                echo "<td>{$pattern['learner_id']}</td>";
                echo "<td>{$pattern['pattern']}</td>";
                echo "<td style='color: red; font-weight: bold;'>{$pattern['duration']}</td>";
                echo "<td>{$pattern['clock_in']}</td>";
                echo "<td>{$pattern['clock_out']}</td>";
                echo "</tr>";
            }
            echo "</table>";
            echo "</div>";
        }
        
        // Display recent critical and error entries
        echo "<h3>🔴 Critical and Error Events</h3>";
        $criticalEntries = array_filter($entries, function($entry) {
            return in_array($entry['level'], ['CRITICAL', 'ERROR']);
        });
        
        if (empty($criticalEntries)) {
            echo "<p style='color: green;'>✅ No critical or error events found.</p>";
        } else {
            foreach (array_slice($criticalEntries, -20) as $entry) {
                $cssClass = strtolower($entry['level']);
                echo "<div class='log-entry $cssClass'>";
                echo "<div class='timestamp'>{$entry['timestamp']} - {$entry['level']}</div>";
                echo "<div><strong>{$entry['message']}</strong></div>";
                if (!empty($entry['data'])) {
                    echo "<pre>" . json_encode($entry['data'], JSON_PRETTY_PRINT) . "</pre>";
                }
                echo "</div>";
            }
        }
        
        // Display auto clock-out events
        echo "<h3>⚠️ Auto Clock-out Events</h3>";
        $autoClockoutEntries = array_filter($entries, function($entry) {
            return strpos($entry['message'], 'AUTO CLOCK-OUT') !== false || 
                   strpos($entry['message'], 'REJECTING SERVER CLOCK-OUT') !== false;
        });
        
        if (empty($autoClockoutEntries)) {
            echo "<p style='color: green;'>✅ No auto clock-out events detected.</p>";
        } else {
            foreach ($autoClockoutEntries as $entry) {
                echo "<div class='log-entry auto-clockout'>";
                echo "<div class='timestamp'>{$entry['timestamp']} - {$entry['level']}</div>";
                echo "<div><strong>{$entry['message']}</strong></div>";
                if (isset($entry['data']['learner_id'])) {
                    echo "<div class='learner-id'>Learner ID: {$entry['data']['learner_id']}</div>";
                }
                if (!empty($entry['data'])) {
                    echo "<pre>" . json_encode($entry['data'], JSON_PRETTY_PRINT) . "</pre>";
                }
                echo "</div>";
            }
        }
        
        // Show filter options
        echo "<div class='filter-controls'>";
        echo "<h3>🔍 Filter Options</h3>";
        echo "<a href='?date=$currentDate&level=CRITICAL'>Show Critical Only</a> | ";
        echo "<a href='?date=$currentDate&level=ERROR'>Show Errors Only</a> | ";
        echo "<a href='?date=$currentDate&message=CLOCK-OUT'>Show Clock-out Events</a> | ";
        echo "<a href='?date=$currentDate'>Show All</a>";
        echo "</div>";
        
        // Apply filters if requested
        $levelFilter = $_GET['level'] ?? null;
        $messageFilter = $_GET['message'] ?? null;
        
        if ($levelFilter || $messageFilter) {
            $filteredEntries = array_filter($entries, function($entry) use ($levelFilter, $messageFilter) {
                if ($levelFilter && $entry['level'] !== $levelFilter) return false;
                if ($messageFilter && strpos($entry['message'], $messageFilter) === false) return false;
                return true;
            });
            
            echo "<h3>📋 Filtered Results (" . count($filteredEntries) . " entries)</h3>";
            
            foreach (array_slice($filteredEntries, -50) as $entry) {
                $cssClass = strtolower($entry['level']);
                echo "<div class='log-entry $cssClass'>";
                echo "<div class='timestamp'>{$entry['timestamp']} - {$entry['level']}</div>";
                echo "<div><strong>{$entry['message']}</strong></div>";
                if (isset($entry['data']['learner_id'])) {
                    echo "<div class='learner-id'>Learner ID: {$entry['data']['learner_id']}</div>";
                }
                if (!empty($entry['data'])) {
                    echo "<details><summary>Show Details</summary>";
                    echo "<pre>" . json_encode($entry['data'], JSON_PRETTY_PRINT) . "</pre>";
                    echo "</details>";
                }
                echo "</div>";
            }
        }
        
    } catch (Exception $e) {
        echo "<div class='pattern-alert'>❌ Error analyzing logs: " . $e->getMessage() . "</div>";
    }
    ?>
    
    <div style="margin-top: 50px; padding: 20px; background: #f0f0f0; border-radius: 5px;">
        <h3>📝 How to Use This Log Analyzer</h3>
        <ol>
            <li><strong>Replace your PHP scripts</strong> with the debug versions (get_clocking_data_debug.php, clockin_debug.php, etc.)</li>
            <li><strong>Make sure logs/ directory exists</strong> and is writable</li>
            <li><strong>Reproduce the auto clock-out issue</strong> with a test learner</li>
            <li><strong>Check this page</strong> for patterns and suspicious activity</li>
            <li><strong>Look for red alerts</strong> indicating auto clock-out patterns</li>
        </ol>
        
        <h4>🎯 What to Look For:</h4>
        <ul>
            <li><strong>AUTO CLOCK-OUT DETECTED</strong> - Direct evidence of unwanted clock-outs</li>
            <li><strong>Sessions under 5 minutes</strong> - Unusually short sessions</li>
            <li><strong>Exactly 2-minute sessions</strong> - The specific pattern you mentioned</li>
            <li><strong>Database state changes</strong> - Unexpected modifications</li>
            <li><strong>REJECTING SERVER CLOCK-OUT</strong> - App protecting against server auto clock-outs</li>
        </ul>
    </div>
</body>
</html>