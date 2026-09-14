<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

try {
    // Get parameters
    $class_id = $_GET['classID'] ?? '';

    if (empty($class_id)) {
        throw new Exception('Missing required parameter: classID');
    }

    // Get learners who have received PPE from poe_sizes table
    $sql = "SELECT DISTINCT 
                l.LearnerID,
                l.Name,
                l.Surname,
                l.IDNumber,
                p.conti_suits_size,
                p.safety_boots_size,
                p.created_at as issued_date
            FROM poe_sizes p
            INNER JOIN learnerdetails l ON p.learner_id = l.LearnerID
            WHERE l.classID = ? 
              AND (p.conti_suits_size IS NOT NULL OR p.safety_boots_size IS NOT NULL)
            ORDER BY l.Surname, l.Name";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $class_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $learners_with_ppe = [];
    while ($row = $result->fetch_assoc()) {
        $learners_with_ppe[] = $row;
    }

    echo json_encode($learners_with_ppe);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
