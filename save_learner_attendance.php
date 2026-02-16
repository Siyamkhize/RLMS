<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

// Get POST data
$learner_id = isset($_POST['learner_id']) ? $_POST['learner_id'] : '';
$class_id = isset($_POST['class_id']) ? $_POST['class_id'] : '';
$finance_id = isset($_POST['finance_id']) ? $_POST['finance_id'] : '';
$month = isset($_POST['month']) ? intval($_POST['month']) : 0;
$year = isset($_POST['year']) ? intval($_POST['year']) : 0;
$dates_json = isset($_POST['dates']) ? $_POST['dates'] : '[]';

// Validate required fields
if (empty($learner_id) || empty($class_id) || $month == 0 || $year == 0) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing required fields'
    ]);
    exit;
}

try {
    // Parse dates
    $dates = json_decode($dates_json, true);
    
    if (!is_array($dates)) {
        echo json_encode([
            'success' => false,
            'message' => 'Invalid dates format'
        ]);
        exit;
    }
    
    // Start transaction
    $conn->begin_transaction();
    
    // Delete existing attendance for this month
    $deleteQuery = "
        DELETE FROM learner_attendance 
        WHERE learner_id = ? 
        AND attendance_month = ? 
        AND attendance_year = ?
    ";
    
    $deleteStmt = $conn->prepare($deleteQuery);
    $deleteStmt->bind_param('sii', $learner_id, $month, $year);
    $deleteStmt->execute();
    $deleteStmt->close();
    
    // Insert new attendance records
    if (count($dates) > 0) {
        $insertQuery = "
            INSERT INTO learner_attendance 
            (learner_id, class_id, finance_id, attendance_date, attendance_month, attendance_year, marked_by)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ";
        
        $insertStmt = $conn->prepare($insertQuery);
        
        foreach ($dates as $date) {
            $insertStmt->bind_param('ssssiis', $learner_id, $class_id, $finance_id, $date, $month, $year, $finance_id);
            $insertStmt->execute();
        }
        
        $insertStmt->close();
    }
    
    // Commit transaction
    $conn->commit();
    
    echo json_encode([
        'success' => true,
        'message' => 'Attendance saved successfully',
        'days_marked' => count($dates)
    ]);
    
} catch (Exception $e) {
    // Rollback on error
    $conn->rollback();
    
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
