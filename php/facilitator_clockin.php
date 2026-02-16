<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

// Get JSON input
$input = file_get_contents('php://input');
$data = json_decode($input, true);

// Log the request
error_log("[FACILITATOR_CLOCKIN] Received request: " . print_r($data, true));

if (!$data) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid JSON data'
    ]);
    exit();
}

// Extract data
$facilitator_id = isset($data['facilitator_id']) ? intval($data['facilitator_id']) : null;
$clock_in_time = isset($data['clock_in_time']) ? $data['clock_in_time'] : null;
$clock_date = isset($data['clock_date']) ? $data['clock_date'] : null;
$user_latitude = isset($data['user_latitude']) ? $data['user_latitude'] : '0.0';
$user_longitude = isset($data['user_longitude']) ? $data['user_longitude'] : '0.0';
$user_accuracy = isset($data['user_accuracy']) ? $data['user_accuracy'] : '10.0';

// Validate required fields
if (!$facilitator_id || !$clock_in_time || !$clock_date) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing required fields: facilitator_id, clock_in_time, clock_date'
    ]);
    exit();
}

try {
    // Check if facilitator exists
    $stmt = $conn->prepare("SELECT facilitator_id, firstName, lastName FROM facilitator WHERE facilitator_id = ?");
    $stmt->bind_param("i", $facilitator_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode([
            'success' => false,
            'message' => 'Facilitator not found'
        ]);
        exit();
    }
    
    $facilitator = $result->fetch_assoc();
    $stmt->close();
    
    // Check if already clocked in for this date
    $stmt = $conn->prepare("SELECT clocking_id FROM facilitator_clocking WHERE facilitator_id = ? AND clock_date = ?");
    $stmt->bind_param("is", $facilitator_id, $clock_date);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        // Update existing record
        $row = $result->fetch_assoc();
        $clocking_id = $row['clocking_id'];
        $stmt->close();
        
        $stmt = $conn->prepare("UPDATE facilitator_clocking SET clock_in_time = ?, user_latitude = ?, user_longitude = ?, user_accuracy = ? WHERE clocking_id = ?");
        $stmt->bind_param("ssssi", $clock_in_time, $user_latitude, $user_longitude, $user_accuracy, $clocking_id);
        
        if ($stmt->execute()) {
            error_log("[FACILITATOR_CLOCKIN] Updated clock-in for facilitator $facilitator_id on $clock_date");
            echo json_encode([
                'success' => true,
                'message' => 'Clock-in updated successfully',
                'facilitator_name' => $facilitator['firstName'] . ' ' . $facilitator['lastName'],
                'clock_in_time' => $clock_in_time
            ]);
        } else {
            throw new Exception("Failed to update clock-in: " . $stmt->error);
        }
    } else {
        // Insert new record
        $stmt->close();
        $stmt = $conn->prepare("INSERT INTO facilitator_clocking (facilitator_id, clock_date, clock_in_time, user_latitude, user_longitude, user_accuracy) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("isssss", $facilitator_id, $clock_date, $clock_in_time, $user_latitude, $user_longitude, $user_accuracy);
        
        if ($stmt->execute()) {
            error_log("[FACILITATOR_CLOCKIN] Created new clock-in for facilitator $facilitator_id on $clock_date");
            echo json_encode([
                'success' => true,
                'message' => 'Clock-in recorded successfully',
                'facilitator_name' => $facilitator['firstName'] . ' ' . $facilitator['lastName'],
                'clock_in_time' => $clock_in_time
            ]);
        } else {
            throw new Exception("Failed to insert clock-in: " . $stmt->error);
        }
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    error_log("[FACILITATOR_CLOCKIN] Error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>

