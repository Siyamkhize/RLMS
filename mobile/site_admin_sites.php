<?php
// Site Admin Sites Management API - COMPLETE AUTHENTICATION BYPASS FOR TESTING
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
    
    $response = array("success" => false, "message" => "Unknown error occurred");
    
    if ($_SERVER["REQUEST_METHOD"] == "GET") {
        $search = $_GET['search'] ?? '';
        
        // Get only workplace sites with optional search
        $query = "SELECT siteID, siteName, latitude, longitude, Category, province FROM sites WHERE Category = 'Workplace'";
        $params = [];
        
        if (!empty($search)) {
            $query .= " AND (siteName LIKE ? OR province LIKE ?)";
            $searchTerm = "%$search%";
            $params = [$searchTerm, $searchTerm];
        }
        
        $query .= " ORDER BY siteName ASC";
        
        $stmt = $conn->prepare($query);
        
        if (!empty($params)) {
            $stmt->bind_param("ss", ...$params);
        }
        
        if ($stmt->execute()) {
            $result = $stmt->get_result();
            $sites = [];
            while ($row = $result->fetch_assoc()) {
                $sites[] = $row;
            }
            
            $response['success'] = true;
            $response['sites'] = $sites;
            $response['count'] = count($sites);
            $response['message'] = 'Workplace sites retrieved successfully (AUTH BYPASSED)';
            $response['debug_info'] = [
                'search_term' => $search,
                'query_used' => $query,
                'authentication' => 'COMPLETELY BYPASSED'
            ];
        } else {
            $response['message'] = 'Failed to retrieve sites: ' . $stmt->error;
        }
        $stmt->close();
    }
    
    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        $action = $_POST['action'] ?? '';
        
        switch ($action) {
            case 'add_site':
                $siteName = $_POST['site_name'] ?? '';
                $category = $_POST['category'] ?? 'Workplace';
                $latitude = $_POST['latitude'] ?? '';
                $longitude = $_POST['longitude'] ?? '';
                $province = $_POST['province'] ?? '';
                
                if (empty($siteName) || empty($latitude) || empty($longitude)) {
                    $response['message'] = 'Site name, latitude, and longitude are required';
                    break;
                }
                
                // Insert new site
                $stmt = $conn->prepare("INSERT INTO sites (siteName, latitude, longitude, Category, province) VALUES (?, ?, ?, ?, ?)");
                $stmt->bind_param("sssss", $siteName, $latitude, $longitude, $category, $province);
                
                if ($stmt->execute()) {
                    $response['success'] = true;
                    $response['message'] = "Site '$siteName' added successfully (AUTH BYPASSED)";
                    $response['site_id'] = $conn->insert_id;
                } else {
                    $response['message'] = 'Failed to add site: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            case 'delete_site':
                $siteID = $_POST['site_id'] ?? '';
                
                if (empty($siteID)) {
                    $response['message'] = 'Site ID is required';
                    break;
                }
                
                // Check if site is a workplace (only allow deletion of workplace sites)
                $checkStmt = $conn->prepare("SELECT siteName, Category FROM sites WHERE siteID = ?");
                $checkStmt->bind_param("i", $siteID);
                $checkStmt->execute();
                $siteResult = $checkStmt->get_result()->fetch_assoc();
                $checkStmt->close();
                
                if (!$siteResult) {
                    $response['message'] = 'Site not found';
                    break;
                }
                
                if ($siteResult['Category'] !== 'Workplace') {
                    $response['message'] = 'Only workplace sites can be deleted';
                    break;
                }
                
                // Delete site
                $stmt = $conn->prepare("DELETE FROM sites WHERE siteID = ? AND Category = 'Workplace'");
                $stmt->bind_param("i", $siteID);
                
                if ($stmt->execute()) {
                    if ($stmt->affected_rows > 0) {
                        $response['success'] = true;
                        $response['message'] = "Site '{$siteResult['siteName']}' deleted successfully (AUTH BYPASSED)";
                    } else {
                        $response['message'] = 'No workplace site found with that ID';
                    }
                } else {
                    $response['message'] = 'Failed to delete site: ' . $stmt->error;
                }
                $stmt->close();
                break;
                
            case 'update_site':
                $siteID = $_POST['site_id'] ?? '';
                $siteName = $_POST['site_name'] ?? '';
                $category = $_POST['category'] ?? '';
                $latitude = $_POST['latitude'] ?? '';
                $longitude = $_POST['longitude'] ?? '';
                $province = $_POST['province'] ?? '';
                
                if (empty($siteID) || empty($siteName)) {
                    $response['message'] = 'Site ID and name are required';
                    break;
                }
                
                // Update site
                $stmt = $conn->prepare("UPDATE sites SET siteName = ?, Category = ?, latitude = ?, longitude = ?, province = ? WHERE siteID = ?");
                $stmt->bind_param("sssssi", $siteName, $category, $latitude, $longitude, $province, $siteID);
                
                if ($stmt->execute()) {
                    if ($stmt->affected_rows > 0) {
                        $response['success'] = true;
                        $response['message'] = "Site '$siteName' updated successfully (AUTH BYPASSED)";
                    } else {
                        $response['message'] = 'No changes made or site not found';
                    }
                } else {
                    $response['message'] = 'Failed to update site: ' . $stmt->error;
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
        'timestamp' => date('Y-m-d H:i:s'),
        'method' => $_SERVER['REQUEST_METHOD']
    ];
    
} catch (Exception $e) {
    $response = [
        'success' => false,
        'message' => 'Error: ' . $e->getMessage(),
        'debug_info' => [
            'authentication' => 'BYPASSED',
            'error_occurred' => true
        ]
    ];
}

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
?>