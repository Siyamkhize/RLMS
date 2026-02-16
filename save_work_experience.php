<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/work_experience_errors.log');

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Log the request
file_put_contents(__DIR__ . '/work_experience_debug.log', 
    date('Y-m-d H:i:s') . " - Request received\n", FILE_APPEND);

// Include database connection
try {
    require_once __DIR__ . '/connection.php';
    file_put_contents(__DIR__ . '/work_experience_debug.log', 
        date('Y-m-d H:i:s') . " - Database connection successful\n", FILE_APPEND);
} catch (Exception $e) {
    file_put_contents(__DIR__ . '/work_experience_debug.log', 
        date('Y-m-d H:i:s') . " - Database connection failed: " . $e->getMessage() . "\n", FILE_APPEND);
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database connection failed: ' . $e->getMessage()
    ]);
    exit();
}

try {
    // Get JSON input
    $input = file_get_contents('php://input');
    file_put_contents(__DIR__ . '/work_experience_debug.log', 
        date('Y-m-d H:i:s') . " - Raw input: " . $input . "\n", FILE_APPEND);
    
    $data = json_decode($input, true);
    
    if (!$data) {
        file_put_contents(__DIR__ . '/work_experience_debug.log', 
            date('Y-m-d H:i:s') . " - JSON decode failed\n", FILE_APPEND);
        throw new Exception('Invalid JSON data');
    }
    
    file_put_contents(__DIR__ . '/work_experience_debug.log', 
        date('Y-m-d H:i:s') . " - Data decoded successfully\n", FILE_APPEND);
    
    // Validate required fields
    $required_fields = ['learner_id', 'employer_name', 'position_held', 'period_from', 'period_to'];
    foreach ($required_fields as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    $learner_id = $conn->real_escape_string($data['learner_id']);
    $employer_name = $conn->real_escape_string($data['employer_name']);
    $position_held = $conn->real_escape_string($data['position_held']);
    $period_from = $conn->real_escape_string($data['period_from']);
    $period_to = $conn->real_escape_string($data['period_to']);
    $responsibilities = isset($data['responsibilities']) ? $conn->real_escape_string($data['responsibilities']) : '';
    
    // Validate dates
    $from_date = DateTime::createFromFormat('Y-m-d', $period_from);
    $to_date = DateTime::createFromFormat('Y-m-d', $period_to);
    
    if (!$from_date || !$to_date) {
        throw new Exception('Invalid date format. Use YYYY-MM-DD');
    }
    
    if ($to_date < $from_date) {
        throw new Exception('End date must be after start date');
    }
    
    // Check if updating existing record
    if (isset($data['id']) && !empty($data['id'])) {
        // Update existing record
        $id = intval($data['id']);
        $sql = "UPDATE work_experience 
                SET employer_name = '$employer_name',
                    position_held = '$position_held',
                    period_from = '$period_from',
                    period_to = '$period_to',
                    responsibilities = '$responsibilities',
                    updated_at = NOW()
                WHERE id = $id AND learner_id = '$learner_id'";
        
        if ($conn->query($sql)) {
            $work_exp_id = $id;
            $message = 'Work experience updated successfully';
            file_put_contents(__DIR__ . '/work_experience_debug.log', 
                date('Y-m-d H:i:s') . " - Updated record ID: $work_exp_id\n", FILE_APPEND);
        } else {
            throw new Exception('Update failed: ' . $conn->error);
        }
        
    } else {
        // Insert new record
        $sql = "INSERT INTO work_experience 
                (learner_id, employer_name, position_held, period_from, period_to, responsibilities, created_at, updated_at)
                VALUES 
                ('$learner_id', '$employer_name', '$position_held', '$period_from', '$period_to', '$responsibilities', NOW(), NOW())";
        
        if ($conn->query($sql)) {
            $work_exp_id = $conn->insert_id;
            $message = 'Work experience saved successfully';
            file_put_contents(__DIR__ . '/work_experience_debug.log', 
                date('Y-m-d H:i:s') . " - Inserted record ID: $work_exp_id\n", FILE_APPEND);
        } else {
            throw new Exception('Insert failed: ' . $conn->error);
        }
    }
    
    echo json_encode([
        'success' => true,
        'message' => $message,
        'work_experience_id' => $work_exp_id
    ]);
    
} catch (Exception $e) {
    $errorMsg = "Error: " . $e->getMessage();
    error_log($errorMsg);
    file_put_contents(__DIR__ . '/work_experience_debug.log', 
        date('Y-m-d H:i:s') . " - " . $errorMsg . "\n", FILE_APPEND);
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>
