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
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

try {
    include 'connection.php';
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn->connect_error ?? "Connection not initialized"));
    }

    session_start();

    $response = array("success" => false, "message" => "Unknown error occurred");

    function logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason) {
        $userAccuracy = $userAccuracy !== null ? (string)$userAccuracy : '0';
        $learnerID = $learnerID !== null ? $learnerID : '0';
        $reason = $reason !== null ? $reason : 'Unknown reason';

        $stmt = $conn->prepare("INSERT INTO induction_clocking (LearnerID, clock_date, clock_in_time, user_latitude, user_longitude, user_accuracy, signature) VALUES (?, ?, ?, ?, ?, ?, ?)");
        if (!$stmt) {
            file_put_contents('debug_clockin.log', "Prepare failed for clocking_log: " . $conn->error . PHP_EOL, FILE_APPEND);
            return false;
        }
        $currentDate = date('Y-m-d');
        $currentTime = date('Y-m-d H:i:s');
        $stmt->bind_param("issddss", $learnerID, $currentDate, $currentTime, $userLatitude, $userLongitude, $userAccuracy, $reason);
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
            $isSynced = isset($_POST['synced']) ? (int)$_POST['synced'] : 0;
            $userLatitude = isset($_POST['user_latitude']) ? floatval($_POST['user_latitude']) : null;
            $userLongitude = isset($_POST['user_longitude']) ? floatval($_POST['user_longitude']) : null;
            $userAccuracy = isset($_POST['user_accuracy']) ? floatval($_POST['user_accuracy']) : null;
            $classID = $_POST['classID'] ?? ($_SESSION['classID'] ?? null);

            // Log received POST data
            $debugLog = "Received POST data: " . json_encode([
                'LearnerID' => $learnerID,
                'user_latitude' => $userLatitude,
                'user_longitude' => $userLongitude,
                'user_accuracy' => $userAccuracy,
                'classID' => $classID,
                'synced' => $isSynced,
                'signature' => isset($_POST['signature']) ? 'Provided' : 'Not provided'
            ], JSON_UNESCAPED_SLASHES);
            file_put_contents('debug_clockin.log', $debugLog . PHP_EOL, FILE_APPEND);

            // Validate inputs
            if (empty($learnerID) || is_null($userLatitude) || is_null($userLongitude) || is_null($userAccuracy) || empty($classID)) {
                $reason = "Invalid input data: " . 
                          (empty($learnerID) ? "Missing LearnerID" : "") . 
                          (is_null($userLatitude) ? " Missing latitude" : "") . 
                          (is_null($userLongitude) ? " Missing longitude" : "") .
                          (is_null($userAccuracy) ? " Missing accuracy" : "") .
                          (empty($classID) ? " Missing classID" : "");
                logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }

            // Check geolocation accuracy
            if ($userAccuracy > 50) {
                $reason = "Geolocation accuracy too low (" . round($userAccuracy, 2) . " meters). Please enable GPS.";
                logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason);
                $response['message'] = $reason;
                $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                ob_end_clean();
                echo $jsonResponse;
                exit;
            }

            // Check if learner has already clocked in
            $stmt = $conn->prepare("SELECT clock_in_time, clock_out_time, contact_time, synced FROM induction_clocking WHERE LearnerID = ? AND clock_date = ?");
            if (!$stmt) {
                $reason = "Prepare failed for checking clock-in: " . $conn->error;
                logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason);
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
                logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason);
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
                $signatureFileName = null;
                $signatureSaved = true;
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
                        $signatureFileName = "learner{$learnerID}_clockin_" . time() . ".png";
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
                        } else {
                            throw new Exception("Signatures directory is not writable");
                        }
                    } catch (Exception $e) {
                        $reason = "Signature error: " . $e->getMessage();
                        logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason);
                        file_put_contents('debug_clockin.log', $reason . PHP_EOL, FILE_APPEND);
                        $signatureSaved = false;
                    }
                }

                $stmt = $conn->prepare("INSERT INTO induction_clocking (LearnerID, clock_date, clock_in_time, synced, user_latitude, user_longitude, user_accuracy, signature) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
                if (!$stmt) {
                    $reason = "Prepare failed for inserting clock-in: " . $conn->error;
                    logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason);
                    $response['message'] = $reason;
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }
                $stmt->bind_param("issiddss", $learnerID, $currentDate, $currentTime, $isSynced, $userLatitude, $userLongitude, $userAccuracy, $signatureFileName);
                if ($stmt->execute()) {
                    logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, "Successful clock-in");
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
                    logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason);
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
                    $stmt = $conn->prepare("UPDATE induction_clocking SET synced = 1 WHERE LearnerID = ? AND clock_date = ?");
                    if (!$stmt) {
                        $reason = "Prepare failed for syncing clock-in: " . $conn->error;
                        logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason);
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
                        $response['clock_in_time'] = $row['clock_in_time'];
                        $response['clock_out_time'] = $row['clock_out_time'];
                        $response['contact_time'] = $row['contact_time'];
                        logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, "Successful sync");
                        $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                        file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                        ob_end_clean();
                        echo $jsonResponse;
                        exit;
                    } else {
                        $reason = "Failed to sync clock-in data: " . $stmt->error;
                        logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason);
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
                    logClockingAttempt($conn, $learnerID, $userLatitude, $userLongitude, $userAccuracy, $reason);
                    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                    file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
                    ob_end_clean();
                    echo $jsonResponse;
                    exit;
                }
            }
            $stmt->close();
        } else {
            $reason = "Invalid request: clock_in not set";
            logClockingAttempt($conn, null, null, null, null, $reason);
            $response['message'] = $reason;
            $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
            file_put_contents('debug_clockin.log', "About to send response: $jsonResponse" . PHP_EOL, FILE_APPEND);
            ob_end_clean();
            echo $jsonResponse;
            exit;
        }
    } else {
        $reason = "Invalid request method: " . $_SERVER["REQUEST_METHOD"];
        logClockingAttempt($conn, null, null, null, null, $reason);
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
        logClockingAttempt($conn, null, null, null, null, $reason);
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