<?php
// Simplified API endpoint for site admin testing - NO AUTHENTICATION
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
                    $response['message'] = 'Available workplaces retrieved successfully';
                } else {
                    $response['message'] = 'Failed to retrieve workplaces: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            case 'get_learners':
                // Get learners with correct column names
                $stmt = $conn->prepare("SELECT LearnerID, Name, Surname, IDNumber FROM learnerdetails LIMIT 10");
                
                if ($stmt->execute()) {
                    $result = $stmt->get_result();
                    $learners = [];
                    while ($row = $result->fetch_assoc()) {
                        $learners[] = $row;
                    }
                    
                    $response['success'] = true;
                    $response['learners'] = $learners;
                    $response['count'] = count($learners);
                    $response['message'] = 'Learners retrieved successfully';
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
                    $response['count'] = count($sites);
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
                    $response['message'] = "Learner assigned to {$siteResult['siteName']} successfully";
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
                        $response['message'] = 'Learner removed from workplace successfully';
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
    
} catch (Exception $e) {
    $response['success'] = false;
    $response['message'] = 'Error: ' . $e->getMessage();
}

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
?>