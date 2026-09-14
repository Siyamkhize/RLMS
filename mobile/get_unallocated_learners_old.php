<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'connection.php';

try {
    $projectId = $_GET['projectId'] ?? '';
    
    if (empty($projectId)) {
        throw new Exception('Project ID is required');
    }

    // Get learners who are NOT in learner_assignments for this project
    $sql = "
       SELECT DISTINCT
    ld.LearnerID,
    ld.Name,
    ld.Surname,
    ld.IDNumber,
    ld.PhoneNumber,
    ld.Email
FROM learnerdetails ld
INNER JOIN learner_assignments ls 
    ON ld.LearnerID = ls.LearnerID
WHERE ls.projectID = ?
AND ld.classID IS NULL
ORDER BY ld.Surname asc ,ld.Name asc;
    ";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $projectId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $learners = [];
    while ($row = $result->fetch_assoc()) {
        $learners[] = $row;
    }
    
    $stmt->close();

    echo json_encode([
        'success' => true,
        'learners' => $learners,
        'count' => count($learners)
    ]);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
