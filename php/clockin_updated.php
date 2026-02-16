<?php
// No whitespace before <?php
// Register shutdown function to catch fatal errors
register_shutdown_function(function () {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        $reason = "Fatal error: {$error['message']} in {$error['file']} at line {$error['line']}";
        file_put_contents('debug_clockin.log', $reason . PHP_EOL, FILE_APPEND);
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

file_put_contents('debug_clockin.log', "Script started: " . date('Y-m-d H:i:s') . PHP_EOL, FILE_APPEND);

header('Content-Type: application/json; charset=UTF-8');

try {
    include 'connection.php';
    
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn->connect_error ?? "Connection not initialized"));
    }
    
    session_start();
    $response = array("success" => false, "message" => "Unknown error occurred");
    
    function logClockingAttempt($conn, $learnerID, $reason, $action = 'clock_in', $gpsData = null) {
        $learnerID = $learnerID !== null ? $learnerID : '0';
        $reason = $reason !== null ? $reason : 'Unknown reason';
        $action = $action !== null ? $action : 'clock_in';
        
        // GEOFENCING: Log GPS data if provided
        if ($gpsData !== null && isset($gpsData['user_latitude']) && isset($gpsData['user_longitude'])) {
            $stmt = $conn->prepare("INSERT INTO clocking_log (learnerID, action, attempt_time, reason, user_latitude, user_longitude, accuracy, site_latitude, site_longitude) VALUES (?, ?, NOW(), ?, ?, ?, ?, ?, ?)");
            if (!$stmt) {
                file_put_contents('debug_clockin.log', "Prepare failed for clocking_log with GPS: " . $conn->error . PHP_EOL, FILE_APPEND);
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
                file_put_contents('debug_clockin.log', "Prepare failed for clocking_log: " . $conn->error . PHP_EOL, FILE_APPEND);
                return false;
            }
            
            $stmt->bind_param("iss", $learnerID, $action, $reason);
        }
        
        if (!$stmt->execute()) {
            file_put_contents('debug_clockin.log', "Failed to log clock-in attempt: " . $stmt->error . PHP_EOL, FILE_APPEND);
            $stmt->close();
            return false;
        }
        
        $stmt->close();
        return true;
    }
    
    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        if (isset($_POST['clock_in'])) {
            $learnerID = $_POST['LearnerID'] ?? null;
            $currentTime = date('Y-m-d H:i:s');
            $currentDate = date('Y-m-d');
            $isSynced = isset($_POST['isSynced']) ? (int)$_POST['isSynced'] : 1;
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
            file_put_contents('debug_clockin.log', $debugLog . PHP_EOL, FILE_APPEND);
            
            // Validate inputs
            if (empty($learnerID) || empty($classID)) {
                $reason = "Invalid input data: " . 
                          (empty($learnerID) ? "Missing LearnerID" : "") . 
                          (empty($classID) ? " Missing classID" : "");
                logClockingAttempt($conn, $learnerID, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }
            
            // Check if learner has already clocked in
            $stmt = $conn->prepare("SELECT clock_in_time, clock_out_time, contact_time, synced FROM learner_clocking WHERE LearnerID = ? AND clock_date = ?");
            if (!$stmt) {
                $reason = "Prepare failed for checking clock-in: " . $conn->error;
                logClockingAttempt($conn, $learnerID, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
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
                file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }
            
            $result = $stmt->get_result();
            
            if ($result->num_rows == 0) {
                // GEOFENCING: Insert clock-in time WITH GPS coordinates
                // Use INSERT ... ON DUPLICATE KEY UPDATE to prevent duplicate records
                $stmt = $conn->prepare("INSERT INTO learner_clocking (LearnerID, clock_date, clock_in_time, synced, user_latitude, user_longitude, user_accuracy) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE clock_in_time = VALUES(clock_in_time), synced = VALUES(synced), user_latitude = VALUES(user_latitude), user_longitude = VALUES(user_longitude), user_accuracy = VALUES(user_accuracy)");
                if (!$stmt) {
                    $reason = "Prepare failed for inserting clock-in: " . $conn->error;
                    logClockingAttempt($conn, $learnerID, $reason);
                    $response['message'] = $reason;
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }
                
                // GEOFENCING: Bind GPS parameters (issiddd = int, string, string, int, double, double, double)
                $stmt->bind_param("issiddd", $learnerID, $currentDate, $currentTime, $isSynced, $userLatitude, $userLongitude, $userAccuracy);
                
                if ($stmt->execute()) {
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
                            
                            $signatureFileName = "learner{$learnerID}_" . time() . ".png";
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
                                $stmt->close();
                            } else {
                                throw new Exception("Signatures directory is not writable");
                            }
                        } catch (Exception $e) {
                            $reason = "Signature error: " . $e->getMessage();
                            logClockingAttempt($conn, $learnerID, $reason);
                            file_put_contents('debug_clockin.log', $reason . PHP_EOL, FILE_APPEND);
                            $signatureSaved = false;
                        }
                    }
                    
                    logClockingAttempt($conn, $learnerID, "Successful clock-in with GPS: lat=$userLatitude, lon=$userLongitude, acc=$userAccuracy", 'clock_in', [
                        'user_latitude' => $userLatitude,
                        'user_longitude' => $userLongitude,
                        'user_accuracy' => $userAccuracy
                    ]);
                    $response['success'] = true;
                    $response['message'] = 'Learner successfully clocked in.' . ($signatureSaved ? '' : ' (Signature not saved)');
                    $response['clock_in_time'] = $currentTime;
                    $response['clock_out_time'] = null;
                    $response['contact_time'] = null;
                    $response['learner_id'] = $learnerID;
                    
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                } else {
                    $reason = "Database error inserting clock-in: " . $stmt->error;
                    logClockingAttempt($conn, $learnerID, $reason);
                    $response['message'] = $reason;
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }
                $stmt->close();
            } else {
                $row = $result->fetch_assoc();
                
                if ($row['synced'] == 0 && $isSynced == 1) {
                    // GEOFENCING: Update synced status AND GPS coordinates if syncing
                    $stmt = $conn->prepare("UPDATE learner_clocking SET synced = 1, user_latitude = ?, user_longitude = ?, user_accuracy = ? WHERE LearnerID = ? AND clock_date = ?");
                    if (!$stmt) {
                        $reason = "Prepare failed for syncing clock-in: " . $conn->error;
                        logClockingAttempt($conn, $learnerID, $reason);
                        $response['message'] = $reason;
                        $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                        file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                        ob_end_clean();
                        echo $jsonResponse;
                        exit;
                    }
                    
                    $stmt->bind_param("dddis", $userLatitude, $userLongitude, $userAccuracy, $learnerID, $currentDate);
                    
                    if ($stmt->execute()) {
                        $response['success'] = true;
                        $response['message'] = 'Clock-in data synced successfully.';
                        $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                        file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                        ob_end_clean();
                        echo $jsonResponse;
                        exit;
                    } else {
                        $reason = "Failed to sync clock-in data: " . $stmt->error;
                        logClockingAttempt($conn, $learnerID, $reason);
                        $response['message'] = $reason;
                        $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                        file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                        ob_end_clean();
                        echo $jsonResponse;
                        exit;
                    }
                    $stmt->close();
                } else {
                    $reason = "Learner has already clocked in today";
                    $response['success'] = true;
                    $response['message'] = $reason;
                    $response['clock_in_time'] = $row['clock_in_time'];
                    $response['clock_out_time'] = $row['clock_out_time'];
                    $response['contact_time'] = $row['contact_time'];
                    
                    logClockingAttempt($conn, $learnerID, $reason);
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }
            }
            $stmt->close();
            
            $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
            file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
            ob_end_clean();
            echo $jsonResponse;
            exit;
        } else {
            $reason = "Invalid request: clock_in not set";
            logClockingAttempt($conn, null, $reason);
            $response['message'] = $reason;
            $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
            file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
            ob_end_clean();
            echo $jsonResponse;
            exit;
        }
    } else {
        $reason = "Invalid request method: " . $_SERVER["REQUEST_METHOD"];
        logClockingAttempt($conn, null, $reason);
        $response['message'] = $reason;
        $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
        ob_end_clean();
        echo $jsonResponse;
        exit;
    }
} catch (Exception $e) {
    $reason = "Server error: " . $e->getMessage() . " in " . $e->getFile() . " at line " . $e->getLine();
    file_put_contents('debug_clockin.log', $reason . PHP_EOL, FILE_APPEND);
    
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
    file_put_contents('debug_clockin.log', "About to send error response: $jsonResponse" . PHP_EOL, FILE_APPEND);
    ob_end_clean();
    header('Content-Type: application/json; charset=UTF-8');
    http_response_code(500);
    echo $jsonResponse ?: '{"success":false,"message":"Failed to encode error response"}';
    exit;
}
?>
