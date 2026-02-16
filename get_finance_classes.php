<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

try {
    // Get all classes with learner count and site information
    $query = "
        SELECT 
            c.classID as class_id,
            c.className as class_name,
            c.siteID as site_id,
            COALESCE(s.siteName, 'No Site') as site_name,
            COUNT(DISTINCT l.LearnerID) as learner_count
        FROM class c
        LEFT JOIN sites s ON c.siteID = s.siteID
        LEFT JOIN learnerdetails l ON c.classID = l.classID
        GROUP BY c.classID, c.className, c.siteID, s.siteName
        ORDER BY s.siteName ASC, c.className ASC
    ";
    
    $result = $conn->query($query);
    
    if ($result) {
        $classes = [];
        while ($row = $result->fetch_assoc()) {
            $classes[] = $row;
        }
        echo json_encode($classes);
    } else {
        echo json_encode(['error' => 'Failed to fetch classes: ' . $conn->error]);
    }
    
} catch (Exception $e) {
    echo json_encode(['error' => 'Error: ' . $e->getMessage()]);
}

$conn->close();
?>
