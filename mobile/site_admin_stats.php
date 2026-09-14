<?php
// Site Admin Dashboard Statistics API
header('Content-Type: application/json; charset=UTF-8');
date_default_timezone_set('Africa/Johannesburg');

try {
    include 'connection.php';
    
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn->connect_error ?? "Connection not initialized"));
    }
    
    // Verify site admin authentication
    $headers = getallheaders();
    $auth_header = $headers['Authorization'] ?? '';
    
    if (!preg_match('/Bearer\s+(\d+)/', $auth_header, $matches)) {
        throw new Exception("Invalid authorization header");
    }
    
    $admin_id = intval($matches[1]);
    
    // Verify admin exists and is active
    $stmt = $conn->prepare("SELECT admin_id, assigned_sites FROM site_admin WHERE admin_id = ? AND status = 'active'");
    $stmt->bind_param("i", $admin_id);
    $stmt->execute();
    $admin_result = $stmt->get_result();
    
    if ($admin_result->num_rows === 0) {
        throw new Exception("Invalid or inactive admin");
    }
    
    $admin_data = $admin_result->fetch_assoc();
    $assigned_sites = json_decode($admin_data['assigned_sites'], true);
    $stmt->close();
    
    $response = array("success" => false, "message" => "Unknown error occurred");
    
    // Build site filter for admin's assigned sites
    $site_filter = "";
    $site_params = [];
    $site_param_types = "";
    
    if ($assigned_sites !== null) {
        // Admin has specific site assignments
        $site_ids = array_map('intval', $assigned_sites);
        $placeholders = str_repeat('?,', count($site_ids) - 1) . '?';
        $site_filter = " WHERE s.siteID IN ($placeholders)";
        $site_params = $site_ids;
        $site_param_types = str_repeat('i', count($site_ids));
    }
    // If assigned_sites is NULL, admin can see all sites (no filter needed)
    
    $stats = [];
    
    // Total sites count
    $sql = "SELECT COUNT(*) as count FROM sites s" . $site_filter;
    $stmt = $conn->prepare($sql);
    if (!empty($site_params)) {
        $stmt->bind_param($site_param_types, ...$site_params);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    $stats['total_sites'] = $result->fetch_assoc()['count'];
    $stmt->close();
    
    // Workplace sites count
    $sql = "SELECT COUNT(*) as count FROM sites s WHERE s.Category = 'Workplace'" . 
           ($site_filter ? " AND s.siteID IN (" . implode(',', array_map('intval', $assigned_sites ?? [])) . ")" : "");
    $stmt = $conn->prepare($sql);
    $stmt->execute();
    $result = $stmt->get_result();
    $stats['workplace_sites'] = $result->fetch_assoc()['count'];
    $stmt->close();
    
    // Active learners count (learners with site assignments)
    if ($assigned_sites !== null) {
        $sql = "SELECT COUNT(DISTINCT ls.learner_id) as count 
                FROM learner_sites ls 
                WHERE ls.site_id IN (" . implode(',', array_map('intval', $assigned_sites)) . ")
                UNION
                SELECT COUNT(DISTINCT ld.LearnerID) as count
                FROM learnerdetails ld
                JOIN class c ON ld.classID = c.classID
                WHERE c.siteID IN (" . implode(',', array_map('intval', $assigned_sites)) . ")";
    } else {
        $sql = "SELECT COUNT(DISTINCT learner_id) as count FROM learner_sites
                UNION
                SELECT COUNT(DISTINCT LearnerID) as count FROM learnerdetails";
    }
    
    $stmt = $conn->prepare($sql);
    $stmt->execute();
    $result = $stmt->get_result();
    $learner_counts = [];
    while ($row = $result->fetch_assoc()) {
        $learner_counts[] = intval($row['count']);
    }
    $stats['active_learners'] = max($learner_counts); // Take the higher count
    $stmt->close();
    
    // Today's clock-ins count
    $today = date('Y-m-d');
    if ($assigned_sites !== null) {
        // Filter by learners assigned to admin's sites
        $sql = "SELECT COUNT(DISTINCT lc.LearnerID) as count 
                FROM learner_clocking lc
                WHERE lc.clock_date = ? 
                AND lc.clock_in_time IS NOT NULL
                AND (
                    lc.LearnerID IN (
                        SELECT DISTINCT ls.learner_id 
                        FROM learner_sites ls 
                        WHERE ls.site_id IN (" . implode(',', array_map('intval', $assigned_sites)) . ")
                    )
                    OR lc.LearnerID IN (
                        SELECT DISTINCT ld.LearnerID
                        FROM learnerdetails ld
                        JOIN class c ON ld.classID = c.classID
                        WHERE c.siteID IN (" . implode(',', array_map('intval', $assigned_sites)) . ")
                    )
                )";
    } else {
        $sql = "SELECT COUNT(DISTINCT LearnerID) as count 
                FROM learner_clocking 
                WHERE clock_date = ? AND clock_in_time IS NOT NULL";
    }
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $today);
    $stmt->execute();
    $result = $stmt->get_result();
    $stats['todays_clockins'] = $result->fetch_assoc()['count'];
    $stmt->close();
    
    $response['success'] = true;
    $response['stats'] = $stats;
    $response['message'] = 'Statistics retrieved successfully';
    
} catch (Exception $e) {
    $response['success'] = false;
    $response['message'] = 'Error: ' . $e->getMessage();
}

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
?>