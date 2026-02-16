<?php
/**
 * Sync Learner Clocking Data
 * 
 * NEW: Supports date and classID filtering
 * 
 * Usage:
 * - Get all records: sync_learner_clocking.php
 * - Get specific date: sync_learner_clocking.php?clock_date=2025-10-11
 * - Get specific class + date: sync_learner_clocking.php?clock_date=2025-10-11&classID=123
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Database connection
require_once 'connection.php'; // Adjust path as needed

try {
    // Check if parameters are provided
    $clock_date = isset($_GET['clock_date']) ? $_GET['clock_date'] : date('Y-m-d'); // Default to current date
    $classID = isset($_GET['classID']) ? $_GET['classID'] : null;
    
    // Build SQL query based on provided parameters
    $sql = "SELECT 
                lc.clocking_id,
                lc.LearnerID,
                lc.clock_date,
                lc.clock_in_time,
                lc.clock_out_time,
                lc.contact_time,
                lc.signature,
                lc.synced,
                lc.user_latitude,
                lc.user_longitude,
                lc.user_accuracy
            FROM learner_clocking lc";
    
    // Add JOIN if classID is provided (need to filter by learner's class)
    if ($classID) {
        $sql .= " INNER JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID";
    }
    
    // Build WHERE clause
    $whereClauses = array();
    $params = array();
    $types = "";
    
    if ($clock_date) {
        $whereClauses[] = "lc.clock_date = ?";
        $params[] = $clock_date;
        $types .= "s";
    }
    
    if ($classID) {
        $whereClauses[] = "ld.classID = ?";
        $params[] = $classID;
        $types .= "s";
    }
    
    if (count($whereClauses) > 0) {
        $sql .= " WHERE " . implode(" AND ", $whereClauses);
    }
    
    $sql .= " ORDER BY lc.clocking_id DESC";
    
    $stmt = $conn->prepare($sql);
    
    // Bind parameters if any
    if (count($params) > 0) {
        $stmt->bind_param($types, ...$params);
    }
    
    // Log what we're fetching
    if ($clock_date && $classID) {
        error_log("[SYNC] Fetching learner_clocking for date: $clock_date, classID: $classID");
    } else if ($clock_date) {
        error_log("[SYNC] Fetching learner_clocking for date: $clock_date");
    } else if ($classID) {
        error_log("[SYNC] Fetching learner_clocking for classID: $classID");
    } else {
        error_log("[SYNC] Fetching ALL learner_clocking records");
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $clockingData = array();
    while ($row = $result->fetch_assoc()) {
        $clockingData[] = $row;
    }
    
    $count = count($clockingData);
    if ($clock_date && $classID) {
        error_log("[SYNC] Returning $count records for date: $clock_date, classID: $classID");
    } else if ($clock_date) {
        error_log("[SYNC] Returning $count records for date: $clock_date");
    } else if ($classID) {
        error_log("[SYNC] Returning $count records for classID: $classID");
    } else {
        error_log("[SYNC] Returning $count total records");
    }
    
    echo json_encode($clockingData);
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    error_log("[SYNC] Error: " . $e->getMessage());
    echo json_encode(array(
        'success' => false,
        'error' => 'Database error: ' . $e->getMessage()
    ));
}
?>

