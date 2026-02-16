<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

$classID = isset($_GET['classID']) ? $_GET['classID'] : '';

if (empty($classID)) {
    echo json_encode(['error' => 'Class ID is required']);
    exit;
}

try {
    // Get learners with register count
    $query = "
        SELECT 
            l.LearnerID as learner_id,
            l.Name as name,
            l.Surname as surname,
            l.IDNumber as id_number,
            l.classID as class_id,
            COUNT(lr.id) as register_count
        FROM learnerdetails l
        LEFT JOIN learner_registers lr ON l.LearnerID = lr.learner_id
        WHERE l.classID = ?
        GROUP BY l.LearnerID, l.Name, l.Surname, l.IDNumber, l.classID
        ORDER BY l.Surname ASC, l.Name ASC
    ";
    
    $stmt = $conn->prepare($query);
    $stmt->bind_param('s', $classID);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result) {
        $learners = [];
        while ($row = $result->fetch_assoc()) {
            $learners[] = $row;
        }
        echo json_encode($learners);
    } else {
        echo json_encode(['error' => 'Failed to fetch learners']);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    echo json_encode(['error' => 'Error: ' . $e->getMessage()]);
}

$conn->close();
?>
