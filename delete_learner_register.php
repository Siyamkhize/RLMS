<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

$learner_id = isset($_POST['learner_id']) ? $_POST['learner_id'] : '';
$month = isset($_POST['month']) ? intval($_POST['month']) : 0;
$year = isset($_POST['year']) ? intval($_POST['year']) : 0;

if (empty($learner_id) || $month == 0 || $year == 0) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing required fields'
    ]);
    exit;
}

try {
    $conn->begin_transaction();
    
    // Delete attendance records for this month
    $deleteAttendance = "
        DELETE FROM learner_attendance 
        WHERE learner_id = ? 
        AND attendance_month = ? 
        AND attendance_year = ?
    ";
    $stmt1 = $conn->prepare($deleteAttendance);
    $stmt1->bind_param('sii', $learner_id, $month, $year);
    $stmt1->execute();
    $stmt1->close();
    
    // Delete register record for this month
    $deleteRegister = "
        DELETE FROM learner_registers 
        WHERE learner_id = ? 
        AND register_month = ? 
        AND register_year = ?
    ";
    $stmt2 = $conn->prepare($deleteRegister);
    $stmt2->bind_param('sii', $learner_id, $month, $year);
    $stmt2->execute();
    $stmt2->close();
    
    $conn->commit();
    
    echo json_encode([
        'success' => true,
        'message' => 'Register deleted successfully'
    ]);
    
} catch (Exception $e) {
    $conn->rollback();
    
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
