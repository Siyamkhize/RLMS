<?php
// clocking_debug_logger.php - Comprehensive logging system for clocking activities

class ClockingDebugLogger {
    private $logFile;
    private $conn;
    
    public function __construct($dbConnection = null) {
        $this->logFile = 'logs/clocking_debug_' . date('Y-m-d') . '.log';
        $this->conn = $dbConnection;
        $this->ensureLogDirectory();
    }
    
    private function ensureLogDirectory() {
        $logDir = dirname($this->logFile);
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
    }
    
    public function log($level, $message, $data = []) {
        $timestamp = date('Y-m-d H:i:s.u');
        $request_id = $this->getRequestId();
        $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        $user_agent = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
        
        $logEntry = [
            'timestamp' => $timestamp,
            'level' => $level,
            'request_id' => $request_id,
            'ip' => $ip,
            'user_agent' => substr($user_agent, 0, 100),
            'script' => $_SERVER['SCRIPT_NAME'] ?? 'unknown',
            'method' => $_SERVER['REQUEST_METHOD'] ?? 'unknown',
            'message' => $message,
            'data' => $data
        ];
        
        $logLine = json_encode($logEntry, JSON_UNESCAPED_SLASHES) . "\n";
        file_put_contents($this->logFile, $logLine, FILE_APPEND | LOCK_EX);
        
        // Also log to error log for critical issues
        if ($level === 'CRITICAL' || $level === 'ERROR') {
            error_log("CLOCKING_DEBUG [$level]: $message - " . json_encode($data));
        }
    }
    
    private function getRequestId() {
        if (!isset($_SERVER['REQUEST_ID'])) {
            $_SERVER['REQUEST_ID'] = uniqid('req_', true);
        }
        return $_SERVER['REQUEST_ID'];
    }
    
    public function logClockInAttempt($learnerID, $source, $data = []) {
        $this->log('INFO', "CLOCK-IN ATTEMPT", [
            'learner_id' => $learnerID,
            'source' => $source,
            'timestamp' => date('Y-m-d H:i:s'),
            'data' => $data
        ]);
    }
    
    public function logClockOutAttempt($learnerID, $source, $data = []) {
        $this->log('INFO', "CLOCK-OUT ATTEMPT", [
            'learner_id' => $learnerID,
            'source' => $source,
            'timestamp' => date('Y-m-d H:i:s'),
            'data' => $data
        ]);
    }
    
    public function logDatabaseQuery($query, $params = [], $result = null) {
        $this->log('DEBUG', "DATABASE QUERY", [
            'query' => $query,
            'params' => $params,
            'result' => $result,
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
    
    public function logDatabaseUpdate($table, $data, $where = [], $result = null) {
        $this->log('INFO', "DATABASE UPDATE", [
            'table' => $table,
            'data' => $data,
            'where' => $where,
            'result' => $result,
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
    
    public function logAutoClockOutDetection($learnerID, $reason, $data = []) {
        $this->log('CRITICAL', "AUTO CLOCK-OUT DETECTED", [
            'learner_id' => $learnerID,
            'reason' => $reason,
            'timestamp' => date('Y-m-d H:i:s'),
            'data' => $data
        ]);
    }
    
    public function logDataFetch($source, $learnerID, $data = []) {
        $this->log('DEBUG', "DATA FETCH", [
            'source' => $source,
            'learner_id' => $learnerID,
            'timestamp' => date('Y-m-d H:i:s'),
            'data' => $data
        ]);
    }
    
    public function logSuspiciousActivity($activity, $data = []) {
        $this->log('WARNING', "SUSPICIOUS ACTIVITY", [
            'activity' => $activity,
            'timestamp' => date('Y-m-d H:i:s'),
            'data' => $data
        ]);
    }
    
    public function getCurrentDatabaseState($learnerID, $date = null) {
        if (!$this->conn) return null;
        
        $date = $date ?? date('Y-m-d');
        
        try {
            // Check learner_clocking table
            $stmt = $this->conn->prepare("SELECT * FROM learner_clocking WHERE LearnerID = ? AND clock_date = ?");
            $stmt->bind_param("is", $learnerID, $date);
            $stmt->execute();
            $learnerClocking = $stmt->get_result()->fetch_assoc();
            
            // Check clocking_log table
            $stmt = $this->conn->prepare("SELECT * FROM clocking_log WHERE learnerID = ? AND DATE(attempt_time) = ? ORDER BY attempt_time DESC LIMIT 10");
            $stmt->bind_param("ss", $learnerID, $date);
            $stmt->execute();
            $clockingLog = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            
            // Check induction_clocking table if exists
            $inductionClocking = null;
            $stmt = $this->conn->prepare("SELECT * FROM induction_clocking WHERE LearnerID = ? AND clock_date = ?");
            $stmt->bind_param("is", $learnerID, $date);
            if ($stmt->execute()) {
                $inductionClocking = $stmt->get_result()->fetch_assoc();
            }
            
            $state = [
                'learner_clocking' => $learnerClocking,
                'clocking_log' => $clockingLog,
                'induction_clocking' => $inductionClocking,
                'timestamp' => date('Y-m-d H:i:s')
            ];
            
            $this->log('DEBUG', "DATABASE STATE SNAPSHOT", [
                'learner_id' => $learnerID,
                'date' => $date,
                'state' => $state
            ]);
            
            return $state;
            
        } catch (Exception $e) {
            $this->log('ERROR', "Failed to get database state", [
                'learner_id' => $learnerID,
                'error' => $e->getMessage()
            ]);
            return null;
        }
    }
    
    public function detectAutoClockOut($learnerID, $oldState, $newState) {
        // Compare states to detect auto clock-outs
        if ($oldState && $newState) {
            $oldClockOut = $oldState['learner_clocking']['clock_out_time'] ?? null;
            $newClockOut = $newState['learner_clocking']['clock_out_time'] ?? null;
            
            if (empty($oldClockOut) && !empty($newClockOut)) {
                $this->logAutoClockOutDetection($learnerID, "Clock-out time appeared without user action", [
                    'old_state' => $oldState,
                    'new_state' => $newState,
                    'time_diff' => time() - strtotime($oldState['timestamp'])
                ]);
            }
        }
    }
    
    public function logRequestDetails() {
        $this->log('DEBUG', "REQUEST DETAILS", [
            'method' => $_SERVER['REQUEST_METHOD'] ?? 'unknown',
            'uri' => $_SERVER['REQUEST_URI'] ?? 'unknown',
            'query_string' => $_SERVER['QUERY_STRING'] ?? '',
            'post_data' => $_POST ?: [],
            'headers' => $this->getRequestHeaders(),
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
    
    private function getRequestHeaders() {
        $headers = [];
        foreach ($_SERVER as $key => $value) {
            if (strpos($key, 'HTTP_') === 0) {
                $headers[str_replace('HTTP_', '', $key)] = $value;
            }
        }
        return $headers;
    }
}

// Global logger instance
global $clockingLogger;
$clockingLogger = new ClockingDebugLogger();

// Log every request
$clockingLogger->logRequestDetails();

// Function to easily log from other scripts
function logClockingEvent($level, $message, $data = []) {
    global $clockingLogger;
    $clockingLogger->log($level, $message, $data);
}

function logClockIn($learnerID, $source = 'unknown', $data = []) {
    global $clockingLogger;
    $clockingLogger->logClockInAttempt($learnerID, $source, $data);
}

function logClockOut($learnerID, $source = 'unknown', $data = []) {
    global $clockingLogger;
    $clockingLogger->logClockOutAttempt($learnerID, $source, $data);
}

function logAutoClockOut($learnerID, $reason, $data = []) {
    global $clockingLogger;
    $clockingLogger->logAutoClockOutDetection($learnerID, $reason, $data);
}

function logDbQuery($query, $params = [], $result = null) {
    global $clockingLogger;
    $clockingLogger->logDatabaseQuery($query, $params, $result);
}

function logDbUpdate($table, $data, $where = [], $result = null) {
    global $clockingLogger;
    $clockingLogger->logDatabaseUpdate($table, $data, $where, $result);
}
?>