<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

$id_number = isset($_GET['id_number']) ? trim($_GET['id_number']) : '';

if (empty($id_number)) {
    echo json_encode([
        'success' => false,
        'message' => 'ID number is required'
    ]);
    exit;
}

try {
    $query = "
        SELECT 
            l.LearnerID as learner_id,
            l.Name as name,
            l.Surname as surname,
            l.IDNumber as id_number,
            l.classID as class_id,
            c.ClassName as class_name,
            COUNT(DISTINCT lr.id) as register_count
        FROM learnerdetails l
        LEFT JOIN class c ON l.classID = c.classID
        LEFT JOIN learner_registers lr ON l.LearnerID = lr.learner_id
        WHERE l.IDNumber LIKE ?
        GROUP BY l.LearnerID, l.Name, l.Surname, l.IDNumber, l.classID, c.ClassName
        ORDER BY l.Name, l.Surname
    ";
    
    $stmt = $conn->prepare($query);
    $searchTerm = '%' . $id_number . '%';
    $stmt->bind_param('s', $searchTerm);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $learners = [];
    while ($row = $result->fetch_assoc()) {
        $learners[] = $row;
    }
    
    $stmt->close();
    
    if (count($learners) > 0) {
        echo json_encode([
            'success' => true,
            'learners' => $learners,
            'count' => count($learners)
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'No learner found with ID number: ' . $id_number,
            'learners' => []
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
