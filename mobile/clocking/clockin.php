<?php
// Security functions
if (!defined('SECURITY_FUNCTIONS_LOADED')) {
    require_once __DIR__ . '/../../security_functions.php';
}

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
    include '../connection.php';
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn->connect_error ?? "Connection not initialized"));
    }

    session_start();

    $response = array("success" => false, "message" => "Unknown error occurred");

    function logClockingAttempt($conn, $learnerID, $reason, $action = 'clock_in') {
        $learnerID = $learnerID !== null ? $learnerID : '0';
        $reason = $reason !== null ? $reason : 'Unknown reason';
        $action = $action !== null ? $action : 'clock_in';

        $stmt = $conn->prepare("INSERT INTO clocking_log (learnerID, action, attempt_time, reason) VALUES (?, ?, NOW(), ?)");
        if (!$stmt) {
            file_put_contents('debug_clockin.log', "Prepare failed for clocking_log: " . $conn->error . PHP_EOL, FILE_APPEND);
            return false;
        }
        $stmt->bind_param("iss", $learnerID, $action, $reason);
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
            $isSynced = isset($_POST['isSynced']) ? (int)$_POST['isSynced'] : 0;
            $classID = $_POST['classID'] ?? ($_SESSION['classID'] ?? null);
            
            // Geofencing data
            $latitude = isset($_POST['latitude']) ? floatval($_POST['latitude']) : null;
            $longitude = isset($_POST['longitude']) ? floatval($_POST['longitude']) : null;
            $accuracy = isset($_POST['accuracy']) ? floatval($_POST['accuracy']) : null;
            $isMocked = isset($_POST['is_mocked']) ? (bool)$_POST['is_mocked'] : false;
            $passedSanity = isset($_POST['passed_sanity']) ? (bool)$_POST['passed_sanity'] : true;

            // Get geofencing data if provided
            $latitude = isset($_POST['latitude']) ? floatval($_POST['latitude']) : null;
            $longitude = isset($_POST['longitude']) ? floatval($_POST['longitude']) : null;
            $accuracy = isset($_POST['accuracy']) ? floatval($_POST['accuracy']) : null;
            $isMocked = isset($_POST['is_mocked']) ? (bool)$_POST['is_mocked'] : false;
            $passedSanity = isset($_POST['passed_sanity']) ? (bool)$_POST['passed_sanity'] : true;

            // Log received POST data
            $debugLog = "Received POST data: " . json_encode([
                'LearnerID' => $learnerID,
                'classID' => $classID,
                'isSynced' => $isSynced,
                'signature' => isset($_POST['signature']) ? 'Provided' : 'Not provided',
                'geofencing' => [
                    'latitude' => $latitude,
                    'longitude' => $longitude,
                    'accuracy' => $accuracy,
                    'is_mocked' => $isMocked,
                    'passed_sanity' => $passedSanity
                ]
            ], JSON_UNESCAPED_SLASHES);
            file_put_contents('debug_clockin.log', $debugLog . PHP_EOL, FILE_APPEND);

            // Validate inputs
            if (empty($learnerID) || empty($classID)) {
                $reason = "Invalid input data: " . (empty($learnerID) ? "Missing LearnerID" : "") . 
                          (empty($classID) ? " Missing classID" : "");
                logClockingAttempt($conn, $learnerID, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }

            // GEOFENCING VALIDATION
            $geofenceResult = validateGeofence($conn, $learnerID, $classID, $_POST);
            if (!$geofenceResult['success']) {
                $reason = "Geofence validation failed: " . $geofenceResult['error'];
                logClockingAttempt($conn, $learnerID, $reason);
                
                // Log security event for geofence violation
                logSecurityEvent($conn, 'geofence_violation', $learnerID, $classID, [
                    'error' => $geofenceResult['error'],
                    'distance' => $geofenceResult['distance'] ?? null,
                    'location_data' => $geofenceResult['location_data'] ?? null
                ]);
                
                $response['message'] = $geofenceResult['error'];
                $response['geofence_error'] = true;
                $response['distance'] = $geofenceResult['distance'] ?? null;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockin.log', "Geofence failed: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }

            // Log successful geofence validation
            file_put_contents('debug_clockin.log', "Geofence validation passed for learner $learnerID" . PHP_EOL, FILE_APPEND);

            // GEOFENCING VALIDATION
            $geofenceResult = validateGeofence($conn, $learnerID, $classID, $_POST);
            if (!$geofenceResult['success']) {
                $reason = "Geofence validation failed: " . $geofenceResult['error'];
                logClockingAttempt($conn, $learnerID, $reason);
                
                // Log security event for geofence violation
                logSecurityEvent($conn, 'geofence_violation', $learnerID, $classID, [
                    'error' => $geofenceResult['error'],
                    'distance' => $geofenceResult['distance'] ?? null,
                    'location_data' => $geofenceResult['location_data'] ?? null
                ]);
                
                $response['message'] = $geofenceResult['error'];
                $response['geofence_error'] = true;
                $response['distance'] = $geofenceResult['distance'] ?? null;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockin.log', "Geofence failed: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }

            // Log successful geofence validation
            file_put_contents('debug_clockin.log', "Geofence validation passed for learner $learnerID" . PHP_EOL, FILE_APPEND);

            // GEOFENCING VALIDATION
            if ($latitude !== null && $longitude !== null) {
                file_put_contents('debug_clockin.log', "Starting geofencing validation..." . PHP_EOL, FILE_APPEND);
                
                // Check for mock location
                if ($isMocked) {
                    $reason = "Clock-in denied: Mock location detected";
                    logClockingAttempt($conn, $learnerID, $reason);
                    
                    // Log security event
                    logSecurityEvent($conn, 'mock_location_detected', $learnerID, $classID, [
                        'latitude' => $latitude,
                        'longitude' => $longitude,
                        'accuracy' => $accuracy,
                        'action' => 'clock_in'
                    ]);
                    
                    $response['message'] = $reason;
                    $response['geofence_error'] = true;
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }

                // Check sanity (impossible movement)
                if (!$passedSanity) {
                    $reason = "Clock-in denied: Suspicious movement detected";
                    logClockingAttempt($conn, $learnerID, $reason);
                    
                    // Log security event
                    logSecurityEvent($conn, 'suspicious_movement', $learnerID, $classID, [
                        'latitude' => $latitude,
                        'longitude' => $longitude,
                        'accuracy' => $accuracy,
                        'action' => 'clock_in'
                    ]);
                    
                    $response['message'] = $reason;
                    $response['geofence_error'] = true;
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }

                // Check GPS accuracy
                if ($accuracy > 60) {
                    $reason = "Clock-in denied: GPS accuracy too low ({$accuracy}m). Required: ≤60m";
                    logClockingAttempt($conn, $learnerID, $reason);
                    
                    // Log security event
                    logSecurityEvent($conn, 'low_gps_accuracy', $learnerID, $classID, [
                        'latitude' => $latitude,
                        'longitude' => $longitude,
                        'accuracy' => $accuracy,
                        'action' => 'clock_in'
                    ]);
                    
                    $response['message'] = $reason;
                    $response['geofence_error'] = true;
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }

                // Get site coordinates for this class
                $stmt = $conn->prepare(
                    "SELECT s.latitude, s.longitude, s.siteName 
                     FROM class c 
                     JOIN sites s ON c.siteID = s.siteID 
                     WHERE c.classID = ? LIMIT 1"
                );
                if (!$stmt) {
                    $reason = "Geofencing error: Failed to prepare site query - " . $conn->error;
                    logClockingAttempt($conn, $learnerID, $reason);
                    $response['message'] = $reason;
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }
                
                $stmt->bind_param("s", $classID);
                $stmt->execute();
                $result = $stmt->get_result();

                if ($result->num_rows === 0) {
                    $reason = "Geofencing error: Site coordinates not found for class {$classID}";
                    logClockingAttempt($conn, $learnerID, $reason);
                    $response['message'] = $reason;
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }

                $row = $result->fetch_assoc();
                $siteLat = floatval($row['latitude'] ?? 0);
                $siteLon = floatval($row['longitude'] ?? 0);
                $siteName = $row['siteName'] ?? 'Site';
                $stmt->close();

                if ($siteLat == 0 && $siteLon == 0) {
                    $reason = "Geofencing error: Invalid site coordinates for {$siteName}";
                    logClockingAttempt($conn, $learnerID, $reason);
                    $response['message'] = $reason;
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }

                // Calculate distance using Haversine formula
                $earthRadius = 6371000; // meters
                $lat1 = deg2rad($latitude);
                $lat2 = deg2rad($siteLat);
                $deltaLat = deg2rad($siteLat - $latitude);
                $deltaLon = deg2rad($siteLon - $longitude);
                $a = sin($deltaLat / 2) ** 2 + cos($lat1) * cos($lat2) * sin($deltaLon / 2) ** 2;
                $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
                $distance = $earthRadius * $c;

                // Geofence validation: 50m base radius + GPS accuracy
                $geofenceRadius = 50.0;
                $effectiveRadius = $geofenceRadius + $accuracy;

                file_put_contents('debug_clockin.log', "Geofencing check: Distance={$distance}m, EffectiveRadius={$effectiveRadius}m, Site={$siteName}" . PHP_EOL, FILE_APPEND);

                if ($distance > $effectiveRadius) {
                    $reason = "Clock-in denied: You are " . round($distance) . "m from {$siteName}. Must be within 50m.";
                    logClockingAttempt($conn, $learnerID, $reason);
                    
                    // Log security event
                    logSecurityEvent($conn, 'geofence_violation', $learnerID, $classID, [
                        'user_latitude' => $latitude,
                        'user_longitude' => $longitude,
                        'site_latitude' => $siteLat,
                        'site_longitude' => $siteLon,
                        'distance' => round($distance, 2),
                        'effective_radius' => $effectiveRadius,
                        'site_name' => $siteName,
                        'accuracy' => $accuracy,
                        'action' => 'clock_in'
                    ]);
                    
                    $response['message'] = $reason;
                    $response['geofence_error'] = true;
                    $response['distance'] = round($distance, 2);
                    $response['site_name'] = $siteName;
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }

                // Log successful geofencing validation
                file_put_contents('debug_clockin.log', "Geofencing validation passed: Distance={$distance}m within {$effectiveRadius}m of {$siteName}" . PHP_EOL, FILE_APPEND);
                
                // Log successful geofence validation
                logSecurityEvent($conn, 'geofence_validation_passed', $learnerID, $classID, [
                    'user_latitude' => $latitude,
                    'user_longitude' => $longitude,
                    'site_latitude' => $siteLat,
                    'site_longitude' => $siteLon,
                    'distance' => round($distance, 2),
                    'effective_radius' => $effectiveRadius,
                    'site_name' => $siteName,
                    'accuracy' => $accuracy,
                    'action' => 'clock_in'
                ]);
            } else {
                file_put_contents('debug_clockin.log', "No geofencing data provided - proceeding without location validation" . PHP_EOL, FILE_APPEND);
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
                // Insert clock-in time
                $stmt = $conn->prepare("INSERT INTO learner_clocking (LearnerID, clock_date, clock_in_time, synced) VALUES (?, ?, ?, ?)");
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
                $stmt->bind_param("issi", $learnerID, $currentDate, $currentTime, $isSynced);
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

                    logClockingAttempt($conn, $learnerID, "Successful clock-in");

                    $response['success'] = true;
                    $response['message'] = 'Learner successfully clocked in.' . ($signatureSaved ? '' : ' (Signature not saved)');
                    $response['clock_in_time'] = $currentTime;
                    $response['clock_out_time'] = null;
                    $response['contact_time'] = null;
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
                    $stmt = $conn->prepare("UPDATE learner_clocking SET synced = 1 WHERE LearnerID = ? AND clock_date = ?");
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
                    $stmt->bind_param("is", $learnerID, $currentDate);
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