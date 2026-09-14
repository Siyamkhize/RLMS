<?php
// Site Admin API - COMPLETE AUTHENTICATION BYPASS FOR TESTING
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

try {
    include 'connection.php';
    
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed");
    }
    
    // NO AUTHENTICATION - BYPASS ALL CHECKS FOR TESTING
    
    // Check if learner_sites table exists, create if not
    $table_check = $conn->query("SHOW TABLES LIKE 'learner_sites'");
    if ($table_check->num_rows == 0) {
        // Create the table
        $create_table = "
            CREATE TABLE learner_sites (
                id INT AUTO_INCREMENT PRIMARY KEY,
                learner_id INT NOT NULL,
                site_id INT NOT NULL,
                is_primary TINYINT(1) DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_learner_id (learner_id),
                INDEX idx_site_id (site_id),
                UNIQUE KEY unique_learner_site (learner_id, site_id)
            )
        ";
        
        if (!$conn->query($create_table)) {
            throw new Exception("Failed to create learner_sites table: " . $conn->error);
        }
        
        // Populate with existing relationships
        $populate = "
            INSERT IGNORE INTO learner_sites (learner_id, site_id, is_primary) 
            SELECT l.LearnerID, c.siteID, 1 
            FROM learnerdetails l 
            JOIN class c ON l.classID = c.classID
            WHERE c.siteID IS NOT NULL
        ";
        $conn->query($populate);
        
        // Add workplace sites if none exist
        $workplace_check = $conn->query("SELECT COUNT(*) as count FROM sites WHERE Category = 'Workplace'");
        $workplace_count = $workplace_check->fetch_assoc()['count'];
        
        if ($workplace_count == 0) {
            $add_workplaces = "
                INSERT IGNORE INTO sites (siteName, latitude, longitude, Category) VALUES 
                ('Grinaker', '-29.664908', '30.410028', 'Workplace'),
                ('Grinaker In-Site', '-29.640338', '30.411801', 'Workplace'),
                ('JCP', '-29.814186', '30.859310', 'Workplace'),
                ('Skhelekehleni', '-25.5180667', '28.0185823', 'Workplace')
            ";
            $conn->query($add_workplaces);
        }
    }
    
    $response = array("success" => false, "message" => "Unknown error occurred");
    
    if ($_SERVER["REQUEST_METHOD"] == "GET") {
        $action = $_GET['action'] ?? '';
        
        switch ($action) {
            case 'get_available_workplaces':
                // Get all workplace sites
                $stmt = $conn->prepare("SELECT siteID, siteName, latitude, longitude, Category FROM sites WHERE Category = 'Workplace' ORDER BY siteName ASC");
                
                if ($stmt->execute()) {
                    $result = $stmt->get_result();
                    $workplaces = [];
                    while ($row = $result->fetch_assoc()) {
                        $workplaces[] = $row;
                    }
                    
                    $response['success'] = true;
                    $response['workplaces'] = $workplaces;
                    $response['count'] = count($workplaces);
                    $response['message'] = 'Available workplaces retrieved successfully (AUTH BYPASSED)';
                    $response['debug'] = 'Authentication completely bypassed for testing';
                } else {
                    $response['message'] = 'Failed to retrieve workplaces: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            case 'get_learners':
                // Get learners with correct column names - increased limit and better query
                $stmt = $conn->prepare("SELECT LearnerID, Name, Surname, IDNumber, classID FROM learnerdetails WHERE Name IS NOT NULL AND Name != '' ORDER BY Name ASC LIMIT 100");
                
                if ($stmt->execute()) {
                    $result = $stmt->get_result();
                    $learners = [];
                    while ($row = $result->fetch_assoc()) {
                        $learners[] = $row;
                    }
                    
                    $response['success'] = true;
                    $response['learners'] = $learners;
                    $response['count'] = count($learners);
                    $response['message'] = 'Learners retrieved successfully (AUTH BYPASSED)';
                    $response['debug_query'] = 'SELECT LearnerID, Name, Surname, IDNumber, classID FROM learnerdetails WHERE Name IS NOT NULL ORDER BY Name ASC LIMIT 100';
                } else {
                    $response['message'] = 'Failed to retrieve learners: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            case 'get_learner_sites':
                $learnerID = $_GET['learner_id'] ?? null;
                
                if (!$learnerID) {
                    $response['message'] = 'Learner ID is required';
                    break;
                }
                
                // Get sites assigned to learner
                $stmt = $conn->prepare("
                    SELECT DISTINCT s.siteID, s.siteName, s.latitude, s.longitude, s.Category,
                           COALESCE(ls.is_primary, 0) as is_primary,
                           ls.created_at as assigned_date
                    FROM sites s
                    LEFT JOIN learner_sites ls ON s.siteID = ls.site_id AND ls.learner_id = ?
                    LEFT JOIN class c ON s.siteID = c.siteID
                    LEFT JOIN learnerdetails ld ON c.classID = ld.classID AND ld.LearnerID = ?
                    WHERE ls.learner_id = ? OR ld.LearnerID = ?
                    ORDER BY is_primary DESC, s.siteName ASC
                ");
                $stmt->bind_param("iiii", $learnerID, $learnerID, $learnerID, $learnerID);
                
                if ($stmt->execute()) {
                    $result = $stmt->get_result();
                    $sites = [];
                    while ($row = $result->fetch_assoc()) {
                        $sites[] = $row;
                    }
                    
                    $response['success'] = true;
                    $response['sites'] = $sites;
                    $response['count'] = count($sites);
                    $response['message'] = 'Learner sites retrieved successfully (AUTH BYPASSED)';
                } else {
                    $response['message'] = 'Failed to retrieve learner sites: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            default:
                $response['message'] = 'Invalid action specified';
        }
    }
    
    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        $action = $_POST['action'] ?? '';
        $learnerID = $_POST['learner_id'] ?? null;
        $siteID = $_POST['site_id'] ?? null;
        
        switch ($action) {
            case 'assign_to_workplace':
                if (!$learnerID || !$siteID) {
                    $response['message'] = 'Learner ID and Site ID are required';
                    break;
                }
                
                // Check if site exists
                $stmt = $conn->prepare("SELECT siteName, Category FROM sites WHERE siteID = ?");
                $stmt->bind_param("i", $siteID);
                $stmt->execute();
                $siteResult = $stmt->get_result()->fetch_assoc();
                $stmt->close();
                
                if (!$siteResult) {
                    $response['message'] = 'Site not found';
                    break;
                }
                
                // Insert assignment
                $stmt = $conn->prepare("INSERT INTO learner_sites (learner_id, site_id, is_primary, created_at) VALUES (?, ?, 0, NOW()) ON DUPLICATE KEY UPDATE created_at = NOW()");
                $stmt->bind_param("ii", $learnerID, $siteID);
                
                if ($stmt->execute()) {
                    $response['success'] = true;
                    $response['message'] = "Learner assigned to {$siteResult['siteName']} successfully (AUTH BYPASSED)";
                } else {
                    $response['message'] = 'Failed to assign learner to site: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            case 'remove_from_workplace':
                if (!$learnerID || !$siteID) {
                    $response['message'] = 'Learner ID and Site ID are required';
                    break;
                }
                
                // Remove assignment (only non-primary)
                $stmt = $conn->prepare("DELETE FROM learner_sites WHERE learner_id = ? AND site_id = ? AND is_primary = 0");
                $stmt->bind_param("ii", $learnerID, $siteID);
                
                if ($stmt->execute()) {
                    if ($stmt->affected_rows > 0) {
                        $response['success'] = true;
                        $response['message'] = 'Learner removed from workplace successfully (AUTH BYPASSED)';
                    } else {
                        $response['message'] = 'No workplace assignment found or cannot remove primary site';
                    }
                } else {
                    $response['message'] = 'Failed to remove learner from site: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            default:
                $response['message'] = 'Invalid action specified';
        }
    }
    
    // Add debug info
    $response['debug_info'] = [
        'authentication' => 'COMPLETELY BYPASSED',
        'table_auto_created' => 'YES',
        'workplaces_auto_added' => 'YES',
        'timestamp' => date('Y-m-d H:i:s')
    ];
    
} catch (Exception $e) {
    $response['success'] = false;
    $response['message'] = 'Error: ' . $e->getMessage();
    $response['debug_info'] = [
        'authentication' => 'BYPASSED',
        'error_occurred' => true
    ];
}

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
?>