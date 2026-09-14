<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'connection.php';

$id_number = isset($_GET['id_number']) ? trim($_GET['id_number']) : '';
$sdp_id = isset($_GET['sdp_id']) ? trim($_GET['sdp_id']) : '';

if (empty($id_number)) {
    echo json_encode([
        'success' => false,
        'message' => 'ID number is required'
    ]);
    exit;
}

if (empty($sdp_id)) {
    echo json_encode([
        'success' => false,
        'message' => 'SDP ID is required'
    ]);
    exit;
}

try {
    // Check if sdp_id is numeric or a name
    $isNumeric = is_numeric($sdp_id);
    
    // Build query to handle both numeric sdp_id and sdp_name
    if ($isNumeric) {
        // Search by numeric sdp_id
        $query = "
            SELECT 
                l.LearnerID as learner_id,
                l.Name as name,
                l.Surname as surname,
                l.IDNumber as id_number,
                l.classID as class_id,
                c.ClassName as class_name,
                c.siteID as site_id,
                s.siteName as site_name,
                s.sdp_id
            FROM learnerdetails l
            INNER JOIN class c ON l.classID = c.classID
            INNER JOIN sites s ON c.siteID = s.siteID
            WHERE l.IDNumber = ? AND s.sdp_id = ?
            LIMIT 1
        ";
        
        $stmt = $conn->prepare($query);
        if (!$stmt) {
            throw new Exception('Prepare failed: ' . $conn->error);
        }
        
        $stmt->bind_param('si', $id_number, $sdp_id);
    } else {
        // Search by sdp_name (case-insensitive)
        $query = "
            SELECT 
                l.LearnerID as learner_id,
                l.Name as name,
                l.Surname as surname,
                l.IDNumber as id_number,
                l.classID as class_id,
                c.ClassName as class_name,
                c.siteID as site_id,
                s.siteName as site_name,
                s.sdp_id
            FROM learnerdetails l
            INNER JOIN class c ON l.classID = c.classID
            INNER JOIN sites s ON c.siteID = s.siteID
            INNER JOIN sdp sd ON s.sdp_id = sd.sdp_id
            WHERE l.IDNumber = ? AND LOWER(sd.sdp_name) = LOWER(?)
            LIMIT 1
        ";
        
        $stmt = $conn->prepare($query);
        if (!$stmt) {
            throw new Exception('Prepare failed: ' . $conn->error);
        }
        
        $stmt->bind_param('ss', $id_number, $sdp_id);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $learner = null;
    if ($row = $result->fetch_assoc()) {
        $learner = $row;
    }
    
    $stmt->close();
    
    if ($learner) {
        echo json_encode([
            'success' => true,
            'learner' => $learner,
            'message' => 'Learner found'
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'No learner found with ID number: ' . $id_number . ' in your sites',
            'learner' => null
        ]);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
