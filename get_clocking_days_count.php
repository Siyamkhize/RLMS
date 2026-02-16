<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Include database connection
require_once 'php/connection_pdo.php';

try {
    // Get parameters
    $learner_id = $_GET['learner_id'] ?? $_POST['learner_id'] ?? null;
    $include_today = $_GET['include_today'] ?? $_POST['include_today'] ?? 'false';
    
    if (!$learner_id) {
        throw new Exception('Learner ID is required');
    }
    
    // Convert include_today to boolean
    $include_today = filter_var($include_today, FILTER_VALIDATE_BOOLEAN);
    
    // Get current date in South African timezone (UTC+2)
    $now = new DateTime('now', new DateTimeZone('Africa/Johannesburg'));
    $first_day_of_month = new DateTime($now->format('Y-m-01'), new DateTimeZone('Africa/Johannesburg'));
    
    // Determine the end date based on include_today parameter
    if ($include_today) {
        $last_day = $now;
    } else {
        $last_day = clone $now;
        $last_day->modify('-1 day');
    }
    
    // Format dates for SQL query
    $start_date = $first_day_of_month->format('Y-m-d');
    $end_date = $last_day->format('Y-m-d');
    
    // Query to count distinct clocking days for the learner in the current month
    $sql = "SELECT COUNT(DISTINCT clock_date) as count
            FROM learner_clocking 
            WHERE LearnerID = ? 
            AND clock_in_time IS NOT NULL 
            AND clock_in_time != ''
            AND clock_date >= ? 
            AND clock_date <= ?";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Failed to prepare statement: ' . $conn->error);
    }
    
    $stmt->bind_param('sss', $learner_id, $start_date, $end_date);
    
    if (!$stmt->execute()) {
        throw new Exception('Failed to execute query: ' . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    $clocking_days = $row ? (int)$row['count'] : 0;
    
    // Calculate working days in the current month (excluding weekends)
    $working_days = 0;
    $current_date = clone $first_day_of_month;
    $month_end = new DateTime($now->format('Y-m-t'), new DateTimeZone('Africa/Johannesburg'));
    
    while ($current_date <= $month_end) {
        $day_of_week = (int)$current_date->format('N'); // 1 = Monday, 7 = Sunday
        if ($day_of_week >= 1 && $day_of_week <= 5) { // Monday to Friday
            $working_days++;
        }
        $current_date->modify('+1 day');
    }
    
    // Prepare response
    $response = [
        'success' => true,
        'data' => [
            'learner_id' => $learner_id,
            'clocking_days' => $clocking_days,
            'working_days' => $working_days,
            'month' => $now->format('F Y'),
            'include_today' => $include_today,
            'date_range' => [
                'start' => $start_date,
                'end' => $end_date
            ]
        ],
        'message' => "Found {$clocking_days} clocking days out of {$working_days} working days for learner {$learner_id} in " . $now->format('F Y')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'data' => [
            'learner_id' => $learner_id ?? null,
            'clocking_days' => 0,
            'working_days' => 0
        ]
    ]);
}

// Close database connection
if (isset($stmt)) {
    $stmt->close();
}
if (isset($conn)) {
    $conn->close();
}
?>