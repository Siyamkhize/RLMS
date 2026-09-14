<?php
// API endpoint to get learners assigned to a specific site - SITE ADMIN ONLY
header('Content-Type: application/json; charset=UTF-8');
date_default_timezone_set('Africa/Johannesburg');

try {
    include 'connection.php';
    
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn->connect_error ?? "Connection not initialized"));
    }
    
    $response = array("success" => false, "message" => "Unknown error occurred");
    
    if ($_SERVER["REQUEST_METHOD"] == "GET") {
        $siteID = $_GET['site_id'] ?? null;
        
        if (!$siteID) {
            $response['message'] = 'Site ID is required';
            echo json_encode($response);
            exit;
        }
        
        // Debug: Log the site ID being requested
        error_log("DEBUG: Requesting learners for site ID: $siteID");
        
        // Get learners assigned to this site (both primary and workplace assignments)
        $sql = "
            SELECT DISTINCT 
                ld.LearnerID,
                ld.Name as first_name,
                ld.Surname as last_name,
                ld.IDNumber as id_number,
                ld.classID,
                c.className,
                lc.clock_in_time,
                lc.clock_out_time,
                lc.clock_date,
                CASE 
                    WHEN ls.is_primary = 1 THEN 'Primary Site'
                    WHEN ls.is_primary = 0 THEN 'Workplace'
                    ELSE 'Class Assignment'
                END as assignment_type
            FROM learnerdetails ld
            LEFT JOIN class c ON ld.classID = c.classID
            LEFT JOIN learner_sites ls ON ld.LearnerID = ls.learner_id AND ls.site_id = ?
            LEFT JOIN learner_clocking lc ON ld.LearnerID = lc.LearnerID AND lc.clock_date = CURDATE()
            WHERE (
                -- Learners assigned via learner_sites table
                ls.learner_id IS NOT NULL
                OR
                -- Learners assigned via class.siteID
                c.siteID = ?
            )
            AND ld.Name IS NOT NULL AND ld.Name != ''
            ORDER BY ld.Name, ld.Surname
        ";
        
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception("Failed to prepare query: " . $conn->error);
        }
        
        $stmt->bind_param("ii", $siteID, $siteID);
        
        if (!$stmt->execute()) {
            throw new Exception("Failed to execute query: " . $stmt->error);
        }
        
        $result = $stmt->get_result();
        $learners = [];
        
        while ($row = $result->fetch_assoc()) {
            $learners[] = $row;
        }
        
        $stmt->close();
        
        // Debug: Log the number of learners found
        error_log("DEBUG: Found " . count($learners) . " learners for site ID: $siteID");
        
        $response['success'] = true;
        $response['learners'] = $learners;
        $response['message'] = 'Learners retrieved successfully';
        $response['count'] = count($learners);
        $response['site_id'] = $siteID;
        $response['debug_sql'] = $sql; // For debugging
    }
    
} catch (Exception $e) {
    $response['success'] = false;
    $response['message'] = 'Error: ' . $e->getMessage();
    error_log("ERROR in get_site_learners.php: " . $e->getMessage());
}

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
?>