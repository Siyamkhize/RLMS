<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'connection.php';

try {
    if (!isset($_GET['facilitator_id'])) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Facilitator ID is required'
        ]);
        exit;
    }

    $facilitator_id = $_GET['facilitator_id'];

    // Fetch classes for the facilitator
    $query = "SELECT DISTINCT 
                c.project_id,
                c.classID,
                c.className,
                c.classDescription,
                c.numberOfLearners,
                c.siteID
              FROM class c
              INNER JOIN learner l ON c.classID = l.classID
              WHERE c.facilitator_id = ?
              ORDER BY c.className";

    $stmt = $conn->prepare($query);
    $stmt->bind_param("s", $facilitator_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $classes = [];
    while ($row = $result->fetch_assoc()) {
        $classes[] = $row;
    }

    echo json_encode([
        'status' => 'success',
        'data' => $classes
    ]);

} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Error fetching classes: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
