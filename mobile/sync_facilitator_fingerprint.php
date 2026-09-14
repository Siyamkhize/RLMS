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
error_log("[SYNC_FAC_FINGERPRINT] Received request: " . print_r($data, true));

if (!$data) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid JSON data'
    ]);
    exit();
}

// Extract data
$facilitator_id = isset($data['facilitator_id']) ? intval($data['facilitator_id']) : null;
$template_type = isset($data['template_type']) ? $data['template_type'] : null; // zkteco_left, zkteco_right, futronic_left, futronic_right
$template_data = isset($data['template_data']) ? $data['template_data'] : null;

// Validate required fields
if (!$facilitator_id || !$template_type || !$template_data) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing required fields: facilitator_id, template_type, template_data',
        'received' => [
            'facilitator_id' => $facilitator_id,
            'template_type' => $template_type,
            'template_data_length' => strlen($template_data ?? '')
        ]
    ]);
    exit();
}

// Validate template type
$valid_types = ['zkteco_left_template', 'zkteco_right_template', 'futronic_left_template', 'futronic_right_template'];
if (!in_array($template_type, $valid_types)) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid template_type. Must be one of: ' . implode(', ', $valid_types)
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
    
    // Check if the column exists (in case table structure is old)
    $column_check = $conn->query("SHOW COLUMNS FROM facilitator LIKE '$template_type'");
    if ($column_check->num_rows === 0) {
        // Column doesn't exist, try to add it
        $alter_sql = "ALTER TABLE facilitator ADD COLUMN `$template_type` LONGTEXT DEFAULT NULL";
        if ($conn->query($alter_sql)) {
            error_log("[SYNC_FAC_FINGERPRINT] Added column $template_type to facilitator table");
        } else {
            throw new Exception("Column $template_type does not exist and could not be created: " . $conn->error);
        }
    }
    
    // Update the fingerprint template
    $sql = "UPDATE facilitator SET `$template_type` = ? WHERE facilitator_id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("si", $template_data, $facilitator_id);
    
    if ($stmt->execute()) {
        error_log("[SYNC_FAC_FINGERPRINT] Updated $template_type for facilitator $facilitator_id (template length: " . strlen($template_data) . ")");
        
        echo json_encode([
            'success' => true,
            'message' => 'Fingerprint template synced successfully',
            'facilitator_name' => $facilitator['firstName'] . ' ' . $facilitator['lastName'],
            'template_type' => $template_type,
            'template_length' => strlen($template_data)
        ]);
    } else {
        throw new Exception("Failed to update fingerprint template: " . $stmt->error);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    error_log("[SYNC_FAC_FINGERPRINT] Error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>

