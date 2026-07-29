<?php
// get_classes.php - Get all classes for a facilitator (assessor/moderator)

// Include database connection
require_once 'connection.php';

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Set headers for CORS and JSON response
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Create database connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    echo json_encode([
        "status" => "error",
        "message" => "Connection failed: " . $conn->connect_error
    ]);
    exit();
}

// Check if facilitator_id is provided
if (!isset($_GET['facilitator_id']) || empty($_GET['facilitator_id'])) {
    echo json_encode([
        "status" => "error",
        "message" => "facilitator_id parameter is required"
    ]);
    exit();
}

$facilitator_id = $conn->real_escape_string($_GET['facilitator_id']);

try {
        SELECT DISTINCT
            c.classID,
            c.className,
            c.siteID,
            s.siteName,
            s.project_id,
            s.Project_pathway,
            p.Project_name,
            COUNT(DISTINCT ld.LearnerID) as numberOfLearners
        FROM facilitator f
        INNER JOIN class c ON f.classID = c.classID
        INNER JOIN sites s ON c.siteID = s.siteID
        LEFT JOIN project p ON s.project_id = p.project_id
        LEFT JOIN learnerdetails ld ON c.classID = ld.classID
        WHERE f.facilitator_id = ?
        GROUP BY c.classID, c.className, c.siteID, s.siteName, s.project_id, s.Project_pathway, p.Project_name
        ORDER BY c.className
    
    $stmt = $conn->prepare($sql);
    
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param("s", $facilitator_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $classes = [];
    while ($row = $result->fetch_assoc()) {
        $classes[] = [
            'classID' => $row['classID'],
            'className' => $row['className'] ?? 'Unknown',
            'siteID' => $row['siteID'],
            'siteName' => $row['siteName'] ?? '',
            'project_id' => $row['project_id'] ?? '',
            'learning_pathway' => $row['Project_pathway'] ?? '',
            'Project_name' => $row['Project_name'] ?? '',
            'numberOfLearners' => (int)$row['numberOfLearners']
        ];
    }
    
    $stmt->close();
    
    // Return the classes
    echo json_encode($classes);
    
} catch (Exception $e) {
    echo json_encode([
        "status" => "error",
        "message" => "Error fetching classes: " . $e->getMessage()
    ]);
}

$conn->close();
?>
