<?php
/**
 * ARPL PDF Generation - Helper Functions
 * These functions are extracted for reusability
 */

/**
 * Fetch appendix data from database
 */
function fetchAppendixData($conn, $table, $learnerID, $ofo_code) {
    $sql = "SELECT * FROM `$table` WHERE learnerID = ? AND ofo_number = ? LIMIT 1";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return [];
    }
    
    $stmt->bind_param('is', $learnerID, $ofo_code);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = $result->fetch_assoc();
    $stmt->close();
    
    return $data ?: [];
}

/**
 * Fetch theory activities for a learner from trade-specific table
 */
function fetchTheoryActivities($conn, $learnerID, $tradeLower) {
    $table = "arplappxb_" . $tradeLower . "_activities";
    $sql = "SELECT a.activity_id, a.activity_number, a.activity_name, 
                   r.competency_scale_id, r.rating_date, r.comments
            FROM `$table` a
            LEFT JOIN arplappxb_activity_ratings r 
                ON a.activity_id = r.activity_id AND r.learnerID = ?
            ORDER BY a.activity_number ASC";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return [];
    }
    
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $activities = [];
    while ($row = $result->fetch_assoc()) {
        $activities[] = $row;
    }
    $stmt->close();
    
    return $activities;
}

/**
 * Fetch workplace activities for a learner from trade-specific table
 */
function fetchWorkplaceActivities($conn, $learnerID, $tradeLower) {
    $table = "arplappxe_" . $tradeLower . "_activities";
    $ratingsTable = "arplappxe_" . $tradeLower . "_activity_ratings";
    
    $sql = "SELECT a.activity_id, a.activity_number, a.activity_name, 
                   r.competency_scale_id, r.rating_date, r.comments
            FROM `$table` a
            LEFT JOIN `$ratingsTable` r 
                ON a.activity_id = r.activity_id AND r.learnerID = ?
            ORDER BY a.activity_number ASC";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return [];
    }
    
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $activities = [];
    while ($row = $result->fetch_assoc()) {
        $activities[] = $row;
    }
    $stmt->close();
    
    return $activities;
}

/**
 * Fetch ACR (Access Confirmation Recommendation) data for a learner
 */
function fetchAccessRecommendation($conn, $learnerID, $tradeLower) {
    $table = "arpl" . $tradeLower . "_access_recommendation";
    $sql = "SELECT * FROM `$table` WHERE LearnerID = ? LIMIT 1";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return null;
    }
    
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = $result->fetch_assoc();
    $stmt->close();
    
    return $data;
}

/**
 * Format activity responses for display
 */
function formatActivityResponse($activities) {
    $results = [];
    for ($i = 1; $i <= 22; $i++) {
        $key = "activity_$i";
        if (isset($activities[$key])) {
            $results[$i] = ucfirst($activities[$key]);
        }
    }
    return $results;
}

?>
