<?php
session_start();
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

include 'connection.php';

// Get the SDP name from the session or query string
$sdp_name = $_SESSION['sdp_name'] ?? $_GET['sdp_name'] ?? '';

// Log sdp_name for debugging
error_log("SDP Name: " . $sdp_name);

// Prepare the SQL query

include 'db_connection.php'; // Include your database connection file

if (!isset($_SESSION["logged_in"]) || $_SESSION["logged_in"] !== true) {
    echo json_encode(['success' => false, 'message' => 'User not logged in']);
    exit;
}

$client_name = $_SESSION['client_name'] ?? '';
$sdp_name = $_SESSION['sdp_name'] ?? '';

// Prepare and execute the SQL statement
$sql = "SELECT 
            sites.siteID AS 'siteID', 
            sites.siteName AS 'SiteName', 
            sites.beneficiaries AS 'Beneficiaries', 
            (SELECT COUNT(classId) FROM class WHERE class.siteId = sites.siteId) AS 'Classes', 
            sites.Project_pathway AS 'LearningPathway', 
            IF(sites.latitude IS NOT NULL AND sites.longitude IS NOT NULL, 
                CONCAT(FORMAT(sites.latitude, 3), ',', FORMAT(sites.longitude, 3)), 
                'No Coordinates Available') AS 'Coordinates', 
            sites.Category AS 'Category', 
            sites.province AS 'Province' 
        FROM sites 
        JOIN sdp ON sites.project_id = sdp.sdp_id 
        WHERE sdp.sdp_name = ?";

$stmt_sites = $conn->prepare($sql);

if ($stmt_sites) {
    $stmt_sites->bind_param("s", $sdp_name);
    $stmt_sites->execute();
    $result_sites = $stmt_sites->get_result();

    $data = array();

    // Fetch data and convert all values to strings
    if ($result_sites->num_rows > 0) {
        while ($site_row = $result_sites->fetch_assoc()) {
            $site_row = array_map(function($value) {
                return (string)$value;
            }, $site_row);
            $data[] = $site_row;
        }
    }

    // Return the JSON response with the data
    echo json_encode([
        'success' => true,
        'role' => $_SESSION['role'], // Include the role from the session
        'sdp_name' => $sdp_name,
        'data' => $data
    ]);
} else {
    // Handle SQL preparation error
    echo json_encode(['success' => false, 'message' => 'Database error']);
}

$stmt_sites->close();
$conn->close();
?>

?>
