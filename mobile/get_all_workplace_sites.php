<?php
// Get All Workplace Sites - For Admin Management Interface
// This endpoint is for the web-based admin management tool, not for site admins
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

try {
    @include 'connection_correct.php';
    if (!isset($conn)) {
        @include 'connection.php';
    }
    if (!isset($conn) && isset($con)) {
        $conn = $con;
    }
    
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed");
    }

    $response = array("success" => false, "message" => "Unknown error occurred");
    
    if ($_SERVER["REQUEST_METHOD"] == "GET") {
        // Get all workplace sites (for admin management purposes)
        $query = "SELECT siteID, siteName, latitude, longitude, Category, province 
                  FROM sites 
                  WHERE Category = 'Workplace' 
                  ORDER BY siteName ASC";
        
        $result = $conn->query($query);
        
        if ($result) {
            $sites = [];
            while ($row = $result->fetch_assoc()) {
                $sites[] = $row;
            }
            
            $response['success'] = true;
            $response['sites'] = $sites;
            $response['count'] = count($sites);
            $response['message'] = 'Workplace sites retrieved successfully';
        } else {
            $response['message'] = 'Failed to retrieve sites: ' . $conn->error;
        }
    } else {
        $response['message'] = 'Invalid request method';
    }
    
} catch (Exception $e) {
    $response = [
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ];
}

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
?>
