<?php

require_once __DIR__ . '/../security_functions.php';
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

// Get parameters
$idNumber = isset($_GET['id_number']) ? trim($_GET['id_number']) : '';
$sdpId = isset($_GET['sdp_id']) ? trim($_GET['sdp_id']) : '';

// Validate input
if (empty($idNumber)) {
    echo json_encode([
        'success' => false,
        'message' => 'ID number is required'
    ]);
    exit;
}

try {
    // Check if site table exists
    $tableCheck = $conn->query("SHOW TABLES LIKE 'site'");
    $siteTableExists = ($tableCheck && $tableCheck->num_rows > 0);
    
    // Build query based on table existence
    if ($siteTableExists) {
        $query = "
            SELECT 
                l.LearnerID as learner_id,
                l.Name as name,
                l.Surname as surname,
                l.IDNumber as id_number,
                l.classID as class_id,
                c.className as class_name,
                s.siteName as site_name,
                s.siteID as site_id,
                s.sdp_id,
                s.sdp_name
            FROM learnerdetails l
            LEFT JOIN class c ON l.classID = c.classID
            LEFT JOIN site s ON c.siteID = s.siteID
            WHERE l.IDNumber = ?
            LIMIT 1
        ";
    } else {
        // Fallback query without site table
        $query = "
            SELECT 
                l.LearnerID as learner_id,
                l.Name as name,
                l.Surname as surname,
                l.IDNumber as id_number,
                l.classID as class_id,
                c.className as class_name
            FROM learnerdetails l
            LEFT JOIN class c ON l.classID = c.classID
            WHERE l.IDNumber = ?
            LIMIT 1
        ";
    }
    
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        throw new Exception('Query preparation failed: ' . $conn->error);
    }
    
    $stmt->bind_param('s', $idNumber);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $learner = $result->fetch_assoc();
        
        echo json_encode([
            'success' => true,
            'learner' => $learner,
            'message' => 'Learner found'
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'No learner found with this ID number',
            'searched_id' => $idNumber
        ]);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
