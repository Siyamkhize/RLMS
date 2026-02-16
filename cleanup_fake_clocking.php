<?php
// cleanup_fake_clocking.php - Remove all fake clock-ins and clock-outs
// Set South African timezone (SAST - UTC+2)
date_default_timezone_set('Africa/Johannesburg');

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include 'connection.php';

$response = array("success" => false, "message" => "Unknown error occurred");

try {
    // Log the cleanup operation
    $logEntry = date('Y-m-d H:i:s') . " - CLEANUP STARTED - Removing fake clock-ins/outs" . PHP_EOL;
    file_put_contents('cleanup_log.txt', $logEntry, FILE_APPEND);

    // Get current date
    $currentDate = date('Y-m-d');
    
    // Find all clock-in records for today that look suspicious
    // These are records with clock-in times around 00:29-00:30 (the batch auto-clocking time)
    $stmt = $conn->prepare("
        SELECT * FROM learner_clocking 
        WHERE clock_date = ? 
        AND clock_in_time LIKE '00:2%' 
        AND clock_in_time LIKE '%:3%'
        AND clock_out_time IS NULL
        AND contact_time IS NULL
    ");
    $stmt->bind_param("s", $currentDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $suspiciousRecords = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $deletedCount = 0;
    $errorCount = 0;

    if (!empty($suspiciousRecords)) {
        $logEntry = date('Y-m-d H:i:s') . " - Found " . count($suspiciousRecords) . " suspicious records to delete" . PHP_EOL;
        file_put_contents('cleanup_log.txt', $logEntry, FILE_APPEND);

        foreach ($suspiciousRecords as $record) {
            try {
                // Delete the suspicious record
                $deleteStmt = $conn->prepare("DELETE FROM learner_clocking WHERE clocking_id = ?");
                $deleteStmt->bind_param("i", $record['clocking_id']);
                
                if ($deleteStmt->execute()) {
                    $deletedCount++;
                    $logEntry = date('Y-m-d H:i:s') . " - DELETED: LearnerID " . $record['LearnerID'] . 
                               ", Clock-in: " . $record['clock_in_time'] . 
                               ", ID: " . $record['clocking_id'] . PHP_EOL;
                    file_put_contents('cleanup_log.txt', $logEntry, FILE_APPEND);
                } else {
                    $errorCount++;
                    $logEntry = date('Y-m-d H:i:s') . " - ERROR deleting record ID " . $record['clocking_id'] . 
                               ": " . $deleteStmt->error . PHP_EOL;
                    file_put_contents('cleanup_log.txt', $logEntry, FILE_APPEND);
                }
                $deleteStmt->close();
            } catch (Exception $e) {
                $errorCount++;
                $logEntry = date('Y-m-d H:i:s') . " - EXCEPTION deleting record ID " . $record['clocking_id'] . 
                           ": " . $e->getMessage() . PHP_EOL;
                file_put_contents('cleanup_log.txt', $logEntry, FILE_APPEND);
            }
        }
    } else {
        $logEntry = date('Y-m-d H:i:s') . " - No suspicious records found for today" . PHP_EOL;
        file_put_contents('cleanup_log.txt', $logEntry, FILE_APPEND);
    }

    // Also clean up any records with empty or invalid clock-in times
    $stmt = $conn->prepare("
        DELETE FROM learner_clocking 
        WHERE clock_date = ? 
        AND (clock_in_time IS NULL OR clock_in_time = '' OR clock_in_time = 'NULL')
    ");
    $stmt->bind_param("s", $currentDate);
    $stmt->execute();
    $additionalDeleted = $stmt->affected_rows;
    $stmt->close();

    if ($additionalDeleted > 0) {
        $logEntry = date('Y-m-d H:i:s') . " - DELETED " . $additionalDeleted . " additional invalid records" . PHP_EOL;
        file_put_contents('cleanup_log.txt', $logEntry, FILE_APPEND);
        $deletedCount += $additionalDeleted;
    }

    $totalDeleted = $deletedCount;
    
    $logEntry = date('Y-m-d H:i:s') . " - CLEANUP COMPLETED - Total deleted: " . $totalDeleted . 
               ", Errors: " . $errorCount . PHP_EOL;
    file_put_contents('cleanup_log.txt', $logEntry, FILE_APPEND);

    $response['success'] = true;
    $response['message'] = "Cleanup completed successfully";
    $response['deleted_count'] = $totalDeleted;
    $response['error_count'] = $errorCount;
    $response['date'] = $currentDate;

} catch (Exception $e) {
    $logEntry = date('Y-m-d H:i:s') . " - CLEANUP ERROR: " . $e->getMessage() . PHP_EOL;
    file_put_contents('cleanup_log.txt', $logEntry, FILE_APPEND);
    
    $response['success'] = false;
    $response['message'] = "Cleanup failed: " . $e->getMessage();
}

echo json_encode($response);
?>
