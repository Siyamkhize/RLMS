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
error_log("[FACILITATOR_CLOCKOUT] Received request: " . print_r($data, true));

if (!$data) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid JSON data'
    ]);
    exit();
}

// Extract data
$facilitator_id = isset($data['facilitator_id']) ? intval($data['facilitator_id']) : null;
$clock_out_time = isset($data['clock_out_time']) ? $data['clock_out_time'] : null;
$contact_time = isset($data['contact_time']) ? $data['contact_time'] : null;
$clock_date = isset($data['clock_date']) ? $data['clock_date'] : null;

// Validate required fields
if (!$facilitator_id || !$clock_out_time || !$clock_date) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing required fields: facilitator_id, clock_out_time, clock_date'
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
    
    // Check if clock-in exists for this date
    $stmt = $conn->prepare("SELECT clocking_id, clock_in_time FROM facilitator_clocking WHERE facilitator_id = ? AND clock_date = ?");
    $stmt->bind_param("is", $facilitator_id, $clock_date);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode([
            'success' => false,
            'message' => 'No clock-in record found for this date. Please clock in first.'
        ]);
        exit();
    }
    
    $row = $result->fetch_assoc();
    $clocking_id = $row['clocking_id'];
    $clock_in_time = $row['clock_in_time'];
    $stmt->close();
    
    // Update with clock-out time
    $stmt = $conn->prepare("UPDATE facilitator_clocking SET clock_out_time = ?, contact_time = ? WHERE clocking_id = ?");
    $stmt->bind_param("ssi", $clock_out_time, $contact_time, $clocking_id);
    
    if ($stmt->execute()) {
        error_log("[FACILITATOR_CLOCKOUT] Clock-out recorded for facilitator $facilitator_id on $clock_date");
        echo json_encode([
            'success' => true,
            'message' => 'Clock-out recorded successfully',
            'facilitator_name' => $facilitator['firstName'] . ' ' . $facilitator['lastName'],
            'clock_in_time' => $clock_in_time,
            'clock_out_time' => $clock_out_time,
            'contact_time' => $contact_time
        ]);
    } else {
        throw new Exception("Failed to update clock-out: " . $stmt->error);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    error_log("[FACILITATOR_CLOCKOUT] Error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>

