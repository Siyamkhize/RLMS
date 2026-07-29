<?php
header('Content-Type: application/json');
include('connection.php');

$facilitator_id = isset($_GET['facilitator_id']) ? $_GET['facilitator_id'] : '';
$date = isset($_GET['date']) ? $_GET['date'] : date('Y-m-d');

if (empty($facilitator_id)) {
    echo json_encode(['success' => false, 'message' => 'Facilitator ID is required']);
    exit;
}

try {
    $stmt = $conn->prepare("SELECT clock_in_time, clock_out_time FROM facilitator_clocking WHERE facilitator_id = ? AND clock_date = ? LIMIT 1");
    $stmt->bind_param("is", $facilitator_id, $date);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        echo json_encode([
            'success' => true,
            'attendance' => [
                'clock_in_time' => $row['clock_in_time'],
                'clock_out_time' => $row['clock_out_time']
            ]
        ]);
    } else {
        echo json_encode([
            'success' => true,
            'attendance' => null,
            'message' => 'No record found for this date'
        ]);
    }
    
    $stmt->close();
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}

$conn->close();
?>
