<?php
// Register shutdown function for fatal errors
register_shutdown_function(function () {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        file_put_contents('debug_clockout.log', "Fatal error: {$error['message']} in {$error['file']} at line {$error['line']}" . PHP_EOL, FILE_APPEND);
        ob_end_clean();
        header('Content-Type: application/json; charset=UTF-8');
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Server error: Fatal error occurred'], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        exit;
    }
});

ob_start();
date_default_timezone_set('Africa/Johannesburg');
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

try {
    include 'connection.php';
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn->connect_error ?? "Connection not initialized"));
    }

    $response = ['success' => false, 'message' => 'Unknown error occurred'];

    function logClockingAttempt($conn, $learnerID, $reason, $isSuccess = false) {
        if ($isSuccess) {
            file_put_contents('debug_clockout.log', "Successful clock-out: LearnerID=$learnerID, reason=$reason" . PHP_EOL, FILE_APPEND);
            return true;
        }
        $stmt = $conn->prepare("INSERT INTO induction_clocking (LearnerID, clock_date, clock_in_time, signature) VALUES (?, ?, ?, ?)");
        if (!$stmt) {
            file_put_contents('debug_clockout.log', "Prepare failed for logging: " . $conn->error . PHP_EOL, FILE_APPEND);
            return false;
        }
        $currentDate = date('Y-m-d');
        $currentTime = date('Y-m-d H:i:s');
        $stmt->bind_param("isss", $learnerID ?? 0, $currentDate, $currentTime, $reason ?? 'Unknown reason');
        $result = $stmt->execute();
        if (!$result) {
            file_put_contents('debug_clockout.log', "Log failed: " . $stmt->error . PHP_EOL, FILE_APPEND);
        }
        $stmt->close();
        return $result;
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !isset($_POST['clock_out'])) {
        $reason = $_SERVER['REQUEST_METHOD'] !== 'POST' ? 'Invalid request method' : 'Missing clock_out parameter';
        logClockingAttempt($conn, null, $reason);
        $response['message'] = $reason;
        throw new Exception($reason);
    }

    $learnerID = $_POST['LearnerID'] ?? null;
    $currentTime = date('Y-m-d H:i:s');
    $currentDate = date('Y-m-d');
    $isSynced = (int)($_POST['synced'] ?? 0);
    $classID = $_POST['classID'] ?? ($_SESSION['classID'] ?? null);

    file_put_contents('debug_clockout.log', "Received POST: " . json_encode([
        'LearnerID' => $learnerID, 'classID' => $classID, 'synced' => $isSynced,
        'signature' => isset($_POST['signature']) ? 'Provided' : 'Not provided'
    ], JSON_UNESCAPED_SLASHES) . PHP_EOL, FILE_APPEND);

    // Validate inputs
    if (empty($learnerID) || empty($classID)) {
        $reason = "Invalid input: " . (empty($learnerID) ? "Missing LearnerID" : "") .
                  (empty($classID) ? " Missing classID" : "");
        logClockingAttempt($conn, $learnerID, $reason);
        $response['message'] = $reason;
        throw new Exception($reason);
    }

    // Check clock-in entry
    $stmt = $conn->prepare("SELECT clock_in_time, clock_out_time, contact_time, synced FROM induction_clocking WHERE LearnerID = ? AND clock_date = ?");
    if (!$stmt) {
        $reason = "Prepare failed for checking clock-in: " . $conn->error;
        logClockingAttempt($conn, $learnerID, $reason);
        $response['message'] = $reason;
        throw new Exception($reason);
    }
    $stmt->bind_param("is", $learnerID, $currentDate);
    if (!$stmt->execute()) {
        $reason = "Database error checking clock-in: " . $stmt->error;
        logClockingAttempt($conn, $learnerID, $reason);
        $response['message'] = $reason;
        throw new Exception($reason);
    }
    $result = $stmt->get_result();
    if ($result->num_rows == 0) {
        $reason = "You need to clock in before clocking out.";
        logClockingAttempt($conn, $learnerID, $reason);
        $response['message'] = $reason;
        throw new Exception($reason);
    }

    $row = $result->fetch_assoc();
    $stmt->close();

    if (!is_null($row['clock_out_time'])) {
        $response = [
            'success' => true,
            'message' => 'Learner has already clocked out today.',
            'clock_in_time' => $row['clock_in_time'],
            'clock_out_time' => $row['clock_out_time'],
            'contact_time' => $row['contact_time']
        ];
        logClockingAttempt($conn, $learnerID, "Already clocked out");
        throw new Exception($response['message']);
    }

    // Calculate contact time
    $interval = (new DateTime($row['clock_in_time']))->diff(new DateTime($currentTime));
    $contactTime = $interval->format('%H:%I:%S');

    // Handle signature
    $signatureFileName = null;
    if (isset($_POST['signature']) && !empty($_POST['signature'])) {
        try {
            $signatureBase64 = preg_replace('#^data:image/\w+;base64,#i', '', $_POST['signature']);
            if ($signatureBase64 === false) throw new Exception("Invalid signature format");
            $signatureImage = base64_decode($signatureBase64, true);
            if ($signatureImage === false) throw new Exception("Invalid signature data");
            $signatureFileName = "learner{$learnerID}_clockout_" . time() . ".png";
            $signatureFilePath = "signatures/$signatureFileName";

            if (!is_dir('signatures') && !mkdir('signatures', 0755, true)) {
                throw new Exception("Failed to create signatures directory");
            }
            if (!file_put_contents($signatureFilePath, $signatureImage)) {
                throw new Exception("Failed to save signature file");
            }
        } catch (Exception $e) {
            logClockingAttempt($conn, $learnerID, "Signature error: " . $e->getMessage());
            $signatureFileName = null;
        }
    }

    // Update clock-out
    $query = $row['synced'] == 0 && $isSynced == 1
        ? "UPDATE induction_clocking SET clock_out_time = ?, contact_time = ?, synced = ?, signature = ? WHERE LearnerID = ? AND clock_date = ?"
        : "UPDATE induction_clocking SET clock_out_time = ?, contact_time = ?, signature = ? WHERE LearnerID = ? AND clock_date = ?";
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        $reason = "Prepare failed for updating clock-out: " . $conn->error;
        logClockingAttempt($conn, $learnerID, $reason);
        $response['message'] = $reason;
        throw new Exception($reason);
    }
    if ($row['synced'] == 0 && $isSynced == 1) {
        $stmt->bind_param("ssisis", $currentTime, $contactTime, $isSynced, $signatureFileName, $learnerID, $currentDate);
    } else {
        $stmt->bind_param("sssis", $currentTime, $contactTime, $signatureFileName, $learnerID, $currentDate);
    }
    if (!$stmt->execute()) {
        $reason = "Failed to update clock-out: " . $stmt->error;
        logClockingAttempt($conn, $learnerID, $reason);
        $response['message'] = $reason;
        throw new Exception($reason);
    }
    $stmt->close();

    $response = [
        'success' => true,
        'message' => 'Learner successfully clocked out.' . ($signatureFileName ? '' : ' (Signature not saved)'),
        'clock_in_time' => $row['clock_in_time'],
        'clock_out_time' => $currentTime,
        'contact_time' => $contactTime
    ];
    logClockingAttempt($conn, $learnerID, "Successful clock-out", true);

    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    file_put_contents('debug_clockout.log', "Response: $jsonResponse" . PHP_EOL, FILE_APPEND);
    ob_end_clean();
    echo $jsonResponse;

} catch (Exception $e) {
    if (isset($conn)) $conn->close();
    $response['message'] = $e->getMessage();
    $jsonResponse = json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    file_put_contents('debug_clockout.log', "Error response: $jsonResponse" . PHP_EOL, FILE_APPEND);
    ob_end_clean();
    echo $jsonResponse;
    exit;
}
?>