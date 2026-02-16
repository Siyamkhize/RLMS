<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

$learner_id = isset($_GET['learner_id']) ? $_GET['learner_id'] : ''; 
$month = isset($_GET['month']) ? intval($_GET['month']) : 0;
$year = isset($_GET['year']) ? intval($_GET['year']) : 0; 

if (empty($learner_id) || $month == 0 || $year == 0) {
    echo json_encode(['error' => 'Missing required parameters']);
    exit;
}

try {
    $query = "
        SELECT 
            id,
            learner_id,
            class_id,
            attendance_date,
            attendance_month,
            attendance_year,
            marked_by,
            created_at
        FROM learner_attendance
        WHERE learner_id = ?
        AND attendance_month = ?
        AND attendance_year = ?
        ORDER BY attendance_date ASC
    ";
    
    $stmt = $conn->prepare($query);
    $stmt->bind_param('sii', $learner_id, $month, $year);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result) {
        $attendance = [];
        while ($row = $result->fetch_assoc()) {
            $attendance[] = $row;
        }
        echo json_encode($attendance);
    } else {
        echo json_encode(['error' => 'Failed to fetch attendance']);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    echo json_encode(['error' => 'Error: ' . $e->getMessage()]);
}

$conn->close();
?>
