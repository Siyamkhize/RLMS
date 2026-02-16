<?php
// No whitespace before <?php
// Register shutdown function to catch fatal errors
register_shutdown_function(function () {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        $reason = "Fatal error: {$error['message']} in {$error['file']} at line {$error['line']}";
        file_put_contents('debug_clockout.log', $reason . PHP_EOL, FILE_APPEND);
        ob_end_clean();
        header('Content-Type: application/json; charset=UTF-8');
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Server error: Fatal error occurred',
            'error_details' => $error
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        exit;
    }
});

ob_start(); // Start output buffering

// Set South African time zone
date_default_timezone_set('Africa/Johannesburg');

// Disable HTML error output
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL); // Log errors for debugging

file_put_contents('debug_clockout.log', "Script started: " . date('Y-m-d H:i:s') . PHP_EOL, FILE_APPEND);

header('Content-Type: application/json; charset=UTF-8');

try {
    include 'connection.php';
    
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn->connect_error ?? "Connection not initialized"));
    }
    
    session_start();
    $response = array("success" => false, "message" => "Unknown error occurred");
    
    function logClockingAttempt($conn, $learnerID, $reason, $action = 'clock_out', $gpsData = null) {
        $learnerID = $learnerID !== null ? $learnerID : '0';
        $reason = $reason !== null ? $reason : 'Unknown reason';
        $action = $action !== null ? $action : 'clock_out';
        
        // GEOFENCING: Log GPS data if provided
        if ($gpsData !== null && isset($gpsData['user_latitude']) && isset($gpsData['user_longitude'])) {
            $stmt = $conn->prepare("INSERT INTO clocking_log (learnerID, action, attempt_time, reason, user_latitude, user_longitude, accuracy, site_latitude, site_longitude) VALUES (?, ?, NOW(), ?, ?, ?, ?, ?, ?)");
            if (!$stmt) {
                file_put_contents('debug_clockout.log', "Prepare failed for clocking_log with GPS: " . $conn->error . PHP_EOL, FILE_APPEND);
                return false;
            }
            
            $userLat = $gpsData['user_latitude'];
            $userLon = $gpsData['user_longitude'];
            $accuracy = isset($gpsData['user_accuracy']) ? strval($gpsData['user_accuracy']) . 'm' : 'unknown';
            $siteLat = isset($gpsData['site_latitude']) ? strval($gpsData['site_latitude']) : '';
            $siteLon = isset($gpsData['site_longitude']) ? strval($gpsData['site_longitude']) : '';
            
            $stmt->bind_param("issddss", $learnerID, $action, $reason, $userLat, $userLon, $accuracy, $siteLat, $siteLon);
        } else {
            // Original logging without GPS
            $stmt = $conn->prepare("INSERT INTO clocking_log (learnerID, action, attempt_time, reason) VALUES (?, ?, NOW(), ?)");
            if (!$stmt) {
                file_put_contents('debug_clockout.log', "Prepare failed for clocking_log: " . $conn->error . PHP_EOL, FILE_APPEND);
                return false;
            }
            
            $stmt->bind_param("iss", $learnerID, $action, $reason);
        }
        
        if (!$stmt->execute()) {
            file_put_contents('debug_clockout.log', "Failed to log clock-out attempt: " . $stmt->error . PHP_EOL, FILE_APPEND);
            $stmt->close();
            return false;
        }
        
        $stmt->close();
        return true;
    }
    
    function calculateContactTime($clockInTime, $clockOutTime, $currentDate) {
        try {
            // Try parsing as Y-m-d H:i:s (e.g., 2025-06-18 09:00:00)
            $clockIn = DateTime::createFromFormat('Y-m-d H:i:s', $clockInTime);
            if ($clockIn === false) {
                // Fallback to H:i:s (e.g., 09:00:00) with current date
                $clockIn = DateTime::createFromFormat('H:i:s', $clockInTime, new DateTimeZone('Africa/Johannesburg'));
                if ($clockIn === false) {
                    throw new Exception("Invalid clock_in_time format: $clockInTime");
                }
                $clockIn->setDate(
                    intval(substr($currentDate, 0, 4)),
                    intval(substr($currentDate, 5, 2)),
                    intval(substr($currentDate, 8, 2))
                );
            }
            
            $clockOut = new DateTime($clockOutTime, new DateTimeZone('Africa/Johannesburg'));
            $interval = $clockOut->diff($clockIn);
            $contactTime = sprintf('%02d:%02d:%02d', $interval->h, $interval->i, $interval->s);
            
            file_put_contents('debug_clockout.log', "Calculated contact time: $contactTime (clock_in: $clockInTime, clock_out: $clockOutTime)" . PHP_EOL, FILE_APPEND);
            return $contactTime;
        } catch (Exception $e) {
            file_put_contents('debug_clockout.log', "Error calculating contact time: " . $e->getMessage() . PHP_EOL, FILE_APPEND);
            return null;
        }
    }
    
    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        if (isset($_POST['clock_out'])) {
            $learnerID = $_POST['LearnerID'] ?? null;
            $currentTime = date('Y-m-d H:i:s');
            $currentDate = date('Y-m-d');
            $isSynced = isset($_POST['isSynced']) ? (int)$_POST['isSynced'] : 0;
            $classID = $_POST['classID'] ?? ($_SESSION['classID'] ?? null);
            
            // GEOFENCING: Extract GPS coordinates
            $userLatitude = isset($_POST['user_latitude']) ? floatval($_POST['user_latitude']) : 0.0;
            $userLongitude = isset($_POST['user_longitude']) ? floatval($_POST['user_longitude']) : 0.0;
            $userAccuracy = isset($_POST['user_accuracy']) ? floatval($_POST['user_accuracy']) : 50.0;
            
            // Log received POST data including GPS
            $debugLog = "Received POST data: " . json_encode([
                'LearnerID' => $learnerID,
                'classID' => $classID,
                'isSynced' => $isSynced,
                'user_latitude' => $userLatitude,
                'user_longitude' => $userLongitude,
                'user_accuracy' => $userAccuracy,
                'signature' => isset($_POST['signature']) ? 'Provided' : 'Not provided'
            ], JSON_UNESCAPED_SLASHES);
            file_put_contents('debug_clockout.log', $debugLog . PHP_EOL, FILE_APPEND);
            
            // Validate inputs
            if (empty($learnerID) || empty($classID)) {
                $reason = "Invalid input data: " . 
                          (empty($learnerID) ? "Missing LearnerID" : "") . 
                          (empty($classID) ? " Missing classID" : "");
                logClockingAttempt($conn, $learnerID, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockout.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }
            
            // Check if learner has clocked in
            $stmt = $conn->prepare("SELECT clock_in_time, clock_out_time, contact_time, synced FROM learner_clocking WHERE LearnerID = ? AND clock_date = ?");
            if (!$stmt) {
                $reason = "Prepare failed for checking clock-in: " . $conn->error;
                logClockingAttempt($conn, $learnerID, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockout.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }
            
            $stmt->bind_param("is", $learnerID, $currentDate);
            if (!$stmt->execute()) {
                $reason = "Database error checking existing clock-in: " . $stmt->error;
                logClockingAttempt($conn, $learnerID, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockout.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }
            
            $result = $stmt->get_result();
            
            if ($result->num_rows == 0) {
                $reason = "No clock-in record found for today";
                logClockingAttempt($conn, $learnerID, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockout.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }
            
            $row = $result->fetch_assoc();
            
            if (!empty($row['clock_out_time'])) {
                $reason = "Learner has already clocked out today";
                $response['success'] = true;
                $response['message'] = $reason;
                $response['clock_in_time'] = $row['clock_in_time'];
                $response['clock_out_time'] = $row['clock_out_time'];
                $response['contact_time'] = $row['contact_time'];
                
                logClockingAttempt($conn, $learnerID, $reason);
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockout.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }
            
            // Calculate contact time
            $contactTime = null;
            if (!empty($row['clock_in_time'])) {
                $contactTime = calculateContactTime($row['clock_in_time'], $currentTime, $currentDate);
                if ($contactTime === null) {
                    $reason = "Failed to calculate contact time for clock_in_time: {$row['clock_in_time']}";
                    logClockingAttempt($conn, $learnerID, $reason);
                    file_put_contents('debug_clockout.log', "Contact time calculation failed, proceeding with null" . PHP_EOL, FILE_APPEND);
                }
            } else {
                file_put_contents('debug_clockout.log', "No clock_in_time found for learnerID: $learnerID, contact_time set to null" . PHP_EOL, FILE_APPEND);
            }
            
            // GEOFENCING: Update clock-out time, contact time, AND GPS coordinates
            $stmt = $conn->prepare("UPDATE learner_clocking SET clock_out_time = ?, contact_time = ?, synced = ?, user_latitude = ?, user_longitude = ?, user_accuracy = ? WHERE LearnerID = ? AND clock_date = ?");
            if (!$stmt) {
                $reason = "Prepare failed for updating clock-out: " . $conn->error;
                logClockingAttempt($conn, $learnerID, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockout.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }
            
            $contactTime = $contactTime ?? ''; // Ensure empty string if null to avoid binding issues
            
            // GEOFENCING: Bind GPS parameters (ssidddis = string, string, int, double, double, double, int, string)
            $stmt->bind_param("ssidddis", $currentTime, $contactTime, $isSynced, $userLatitude, $userLongitude, $userAccuracy, $learnerID, $currentDate);
            
            if (!$stmt->execute()) {
                $reason = "Database error updating clock-out: " . $stmt->error;
                logClockingAttempt($conn, $learnerID, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockout.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }
            
            file_put_contents('debug_clockout.log', "Updated learner_clocking: clock_out_time=$currentTime, contact_time=$contactTime, synced=$isSynced, GPS: lat=$userLatitude, lon=$userLongitude, acc=$userAccuracy for learnerID=$learnerID, date=$currentDate" . PHP_EOL, FILE_APPEND);
            $stmt->close();
            
            $signatureSaved = true;
            
            // Save signature if provided
            if (isset($_POST['signature']) && !empty($_POST['signature'])) {
                try {
                    $signatureBase64 = preg_replace('#^data:image/\w+;base64,#i', '', $_POST['signature']);
                    if ($signatureBase64 === false) {
                        throw new Exception("Invalid signature format: preg_replace failed");
                    }
                    
                    $signatureImage = base64_decode($signatureBase64, true);
                    if ($signatureImage === false) {
                        throw new Exception("Invalid signature data: base64_decode failed");
                    }
                    
                    $signatureFileName = "learner{$learnerID}_clockout_" . time() . ".png";
                    $signatureFilePath = "signatures/" . $signatureFileName;
                    
                    if (!is_dir('signatures')) {
                        if (!mkdir('signatures', 0755, true)) {
                            throw new Exception("Failed to create signatures directory");
                        }
                    }
                    
                    if (is_dir('signatures') && is_writable('signatures')) {
                        if (!file_put_contents($signatureFilePath, $signatureImage)) {
                            throw new Exception("Failed to save signature file: $signatureFilePath");
                        }
                        
                        $stmt = $conn->prepare("UPDATE learner_clocking SET signature = ? WHERE LearnerID = ? AND clock_date = ?");
                        if (!$stmt) {
                            throw new Exception("Prepare failed for updating signature: " . $conn->error);
                        }
                        
                        $stmt->bind_param("sis", $signatureFileName, $learnerID, $currentDate);
                        if (!$stmt->execute()) {
                            throw new Exception("Failed to update signature: " . $stmt->error);
                        }
                        
                        file_put_contents('debug_clockout.log', "Saved signature: $signatureFileName for learnerID=$learnerID" . PHP_EOL, FILE_APPEND);
                        $stmt->close();
                    } else {
                        throw new Exception("Signatures directory is not writable");
                    }
                } catch (Exception $e) {
                    $reason = "Signature error: " . $e->getMessage();
                    logClockingAttempt($conn, $learnerID, $reason);
                    file_put_contents('debug_clockout.log', $reason . PHP_EOL, FILE_APPEND);
                    $signatureSaved = false;
                }
            }
            
            logClockingAttempt($conn, $learnerID, "Successful clock-out with GPS: lat=$userLatitude, lon=$userLongitude, acc=$userAccuracy", 'clock_out', [
                'user_latitude' => $userLatitude,
                'user_longitude' => $userLongitude,
                'user_accuracy' => $userAccuracy
            ]);
            $response['success'] = true;
            $response['message'] = 'Learner successfully clocked out.' . ($signatureSaved ? '' : ' (Signature not saved)');
            $response['clock_in_time'] = $row['clock_in_time'];
            $response['clock_out_time'] = $currentTime;
            $response['contact_time'] = $contactTime;
            
            $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
            file_put_contents('debug_clockout.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
            ob_end_clean();
            echo $jsonResponse;
            exit;
        } else {
            $reason = "Invalid request: clock_out not set";
            logClockingAttempt($conn, null, $reason);
            $response['message'] = $reason;
            $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
            file_put_contents('debug_clockout.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
            ob_end_clean();
            echo $jsonResponse;
            exit;
        }
    } else {
        $reason = "Invalid request method: " . $_SERVER["REQUEST_METHOD"];
        logClockingAttempt($conn, null, $reason);
        $response['message'] = $reason;
        $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        file_put_contents('debug_clockout.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
        ob_end_clean();
        echo $jsonResponse;
        exit;
    }
} catch (Exception $e) {
    $reason = "Server error: " . $e->getMessage() . " in " . $e->getFile() . " at line " . $e->getLine();
    file_put_contents('debug_clockout.log', $reason . PHP_EOL, FILE_APPEND);
    
    if (isset($conn)) {
        logClockingAttempt($conn, null, $reason);
        $conn->close();
    }
    
    $response = [
        'success' => false,
        'message' => $reason,
        'error_details' => [
            'file' => $e->getFile(),
            'line' => $e->getLine(),
            'trace' => $e->getTraceAsString()
        ]
    ];
    
    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    file_put_contents('debug_clockout.log', "About to send error response: $jsonResponse" . PHP_EOL, FILE_APPEND);
    ob_end_clean();
    header('Content-Type: application/json; charset=UTF-8');
    http_response_code(500);
    echo $jsonResponse ?: '{"success":false,"message":"Failed to encode error response"}';
    exit;
}
?>
