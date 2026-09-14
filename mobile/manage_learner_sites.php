<?php
// API endpoint to manage learner site assignments (workplaces) - SITE ADMIN ONLY
header('Content-Type: application/json; charset=UTF-8');
date_default_timezone_set('Africa/Johannesburg');

try {
    include 'connection.php';
    
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn->connect_error ?? "Connection not initialized"));
    }
    
    // SITE ADMIN ROLE VERIFICATION
    session_start();
    
    // Check if user is logged in as site_admin
    if (!isset($_SESSION['role']) || $_SESSION['role'] !== 'site_admin') {
        // Try to verify via Authorization header for API calls
        $headers = getallheaders();
        $auth_header = $headers['Authorization'] ?? '';
        
        if (preg_match('/Bearer\s+(\d+)/', $auth_header, $matches)) {
            $admin_id = intval($matches[1]);
            
            // Verify admin exists and is active
            $stmt = $conn->prepare("SELECT admin_id, can_assign_learners FROM site_admin WHERE admin_id = ? AND status = 'active'");
            $stmt->bind_param("i", $admin_id);
            $stmt->execute();
            $admin_result = $stmt->get_result();
            
            if ($admin_result->num_rows === 0) {
                throw new Exception("Unauthorized: Invalid site admin");
            }
            
            $admin_data = $admin_result->fetch_assoc();
            if (!$admin_data['can_assign_learners']) {
                throw new Exception("Unauthorized: No permission to assign learners");
            }
            $stmt->close();
        } else {
            throw new Exception("Unauthorized: Site admin access required");
        }
    } else {
        // Session-based verification
        if (!isset($_SESSION['can_assign_learners']) || !$_SESSION['can_assign_learners']) {
            throw new Exception("Unauthorized: No permission to assign learners");
        }
    }
    
    $response = array("success" => false, "message" => "Unknown error occurred");
    
    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        $action = $_POST['action'] ?? '';
        $learnerID = $_POST['learner_id'] ?? null;
        $siteID = $_POST['site_id'] ?? null;
        
        if (!$learnerID) {
            $response['message'] = 'Learner ID is required';
            echo json_encode($response);
            exit;
        }
        
        switch ($action) {
            case 'assign_to_workplace':
                if (!$siteID) {
                    $response['message'] = 'Site ID is required';
                    break;
                }
                
                // Check if site exists and is a workplace
                $stmt = $conn->prepare("SELECT siteName, Category FROM sites WHERE siteID = ?");
                $stmt->bind_param("i", $siteID);
                $stmt->execute();
                $siteResult = $stmt->get_result()->fetch_assoc();
                $stmt->close();
                
                if (!$siteResult) {
                    $response['message'] = 'Site not found';
                    break;
                }
                
                // Insert or update learner site assignment
                $stmt = $conn->prepare("INSERT INTO learner_sites (learner_id, site_id, is_primary, created_at) VALUES (?, ?, 0, NOW()) ON DUPLICATE KEY UPDATE created_at = NOW()");
                $stmt->bind_param("ii", $learnerID, $siteID);
                
                if ($stmt->execute()) {
                    $response['success'] = true;
                    $response['message'] = "Learner assigned to {$siteResult['siteName']} successfully";
                } else {
                    $response['message'] = 'Failed to assign learner to site: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            case 'remove_from_workplace':
                if (!$siteID) {
                    $response['message'] = 'Site ID is required';
                    break;
                }
                
                // Don't allow removing primary site
                $stmt = $conn->prepare("DELETE FROM learner_sites WHERE learner_id = ? AND site_id = ? AND is_primary = 0");
                $stmt->bind_param("ii", $learnerID, $siteID);
                
                if ($stmt->execute()) {
                    if ($stmt->affected_rows > 0) {
                        $response['success'] = true;
                        $response['message'] = 'Learner removed from workplace successfully';
                    } else {
                        $response['message'] = 'No workplace assignment found or cannot remove primary site';
                    }
                } else {
                    $response['message'] = 'Failed to remove learner from site: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            case 'get_learner_sites':
                // Get all sites assigned to learner
                $stmt = $conn->prepare("
                    SELECT DISTINCT s.siteID, s.siteName, s.latitude, s.longitude, s.Category,
                           CASE WHEN ls.is_primary = 1 THEN 1 ELSE 0 END as is_primary,
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
                    $response['message'] = 'Learner sites retrieved successfully';
                } else {
                    $response['message'] = 'Failed to retrieve learner sites: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            default:
                $response['message'] = 'Invalid action specified';
        }
    }
    
    if ($_SERVER["REQUEST_METHOD"] == "GET") {
        $action = $_GET['action'] ?? '';
        
        switch ($action) {
            case 'get_available_workplaces':
                // Get all sites that can be used as workplaces
                $stmt = $conn->prepare("SELECT siteID, siteName, latitude, longitude, Category FROM sites WHERE Category = 'Workplace' OR Category IS NULL ORDER BY siteName ASC");
                
                if ($stmt->execute()) {
                    $result = $stmt->get_result();
                    $workplaces = [];
                    while ($row = $result->fetch_assoc()) {
                        $workplaces[] = $row;
                    }
                    
                    $response['success'] = true;
                    $response['workplaces'] = $workplaces;
                    $response['message'] = 'Available workplaces retrieved successfully';
                } else {
                    $response['message'] = 'Failed to retrieve workplaces: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            case 'get_learner_sites':
                $learnerID = $_GET['learner_id'] ?? null;
                
                if (!$learnerID) {
                    $response['message'] = 'Learner ID is required';
                    break;
                }
                
                // Same logic as POST get_learner_sites
                $stmt = $conn->prepare("
                    SELECT DISTINCT s.siteID, s.siteName, s.latitude, s.longitude, s.Category,
                           CASE WHEN ls.is_primary = 1 THEN 1 ELSE 0 END as is_primary,
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
                    $response['message'] = 'Learner sites retrieved successfully';
                } else {
                    $response['message'] = 'Failed to retrieve learner sites: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            default:
                $response['message'] = 'Invalid action specified';
        }
    }
    
} catch (Exception $e) {
    $response['success'] = false;
    $response['message'] = 'Error: ' . $e->getMessage();
}

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
?>