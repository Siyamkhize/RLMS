<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// Database configuration
include'connection.php';
try {
    $conn = new mysqli($host, $username, $password, $dbname);
    
    // Check connection
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    // Set charset to utf8
    $conn->set_charset("utf8");
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed: ' . $e->getMessage()]);
    exit;
}

$facilitator_id = isset($_GET['facilitator_id']) ? $conn->real_escape_string($_GET['facilitator_id']) : null;

if (!$facilitator_id) {
    http_response_code(400);
    echo json_encode(['error' => 'Facilitator ID is required']);
    exit;
}

try {
    // Get classes for the facilitator with qualification information
    $query = "
        SELECT 
            c.classID,
            c.className,
            c.numberOfLearners,
            c.siteID,
            c.qualification_id,
            s.project_id,
            s.siteName,
            p.Project_name,
            q.name as qualification_name,
            q.description as qualification_description,
            q.level as qualification_level,
            q.credits as qualification_credits
        FROM class c
        LEFT JOIN sites s ON c.siteID = s.siteID
        LEFT JOIN project p ON s.project_id = p.project_id
        LEFT JOIN qualification q ON c.qualification_id = q.qualification_id
        WHERE c.classID IN (
            SELECT DISTINCT classID 
            FROM facilitator 
            WHERE facilitator_id = '$facilitator_id' AND role = 'Moderator'
        )
        ORDER BY c.className
    ";
    
    $result = $conn->query($query);
    if (!$result) {
        throw new Exception("Query failed: " . $conn->error);
    }
    
    $classes = [];
    while ($row = $result->fetch_assoc()) {
        $classes[] = $row;
    }
    
    // If no direct class assignments found, try to find classes by qualification
    if (empty($classes)) {
        $qualificationQuery = "
            SELECT DISTINCT
                c.classID,
                c.className,
                c.numberOfLearners,
                c.siteID,
                c.qualification_id,
                s.project_id,
                s.siteName,
                p.Project_name,
                q.name as qualification_name,
                q.description as qualification_description,
                q.level as qualification_level,
                q.credits as qualification_credits
            FROM class c
            LEFT JOIN sites s ON c.siteID = s.siteID
            LEFT JOIN project p ON s.project_id = p.project_id
            LEFT JOIN qualification q ON c.qualification_id = q.qualification_id
            WHERE c.qualification_id IN (
                SELECT DISTINCT c2.qualification_id
                FROM class c2
                JOIN facilitator f ON c2.classID = f.classID
                WHERE f.facilitator_id = '$facilitator_id' AND f.role = 'Moderator'
            )
            ORDER BY c.className
        ";
        
        $qualResult = $conn->query($qualificationQuery);
        if (!$qualResult) {
            throw new Exception("Query failed: " . $conn->error);
        }
        
        $classes = [];
        while ($row = $qualResult->fetch_assoc()) {
            $classes[] = $row;
        }
    }
    
    // Prepare response
    $response = [
        'status' => 'success',
        'facilitator_id' => $facilitator_id,
        'classes' => $classes,
        'total_classes' => count($classes)
    ];
    
    echo json_encode($response);
    
    // Close connection
    $conn->close();
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Server error: ' . $e->getMessage()]);
}
?>