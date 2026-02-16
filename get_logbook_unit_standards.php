<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include('connection.php');

// Get learner_id from GET or POST
$learnerID = 0;
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $learnerID = isset($_POST['learner_id']) ? intval($_POST['learner_id']) : 0;
} else {
    $learnerID = isset($_GET['learner_id']) ? intval($_GET['learner_id']) : 0;
}

if ($learnerID <= 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Invalid learner_id provided'
    ]);
    exit();
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8mb4");
    
    // Hardcoded unit standards for Pothole Checklist: 13958 and 14555
    $unit_standard_ids = ['13958', '14555'];
    $unit_standards = [];
    
    foreach ($unit_standard_ids as $unitStandardId) {
        // Get unit standard name from unitstandard table
        $us_query = "SELECT unitstandard_id, unit_standard_name 
                     FROM unitstandard 
                     WHERE unitstandard_id = ?
                     LIMIT 1";
        
        $us_stmt = $conn->prepare($us_query);
        $us_stmt->bind_param('s', $unitStandardId);
        $us_stmt->execute();
        $us_result = $us_stmt->get_result();
        
        if ($us_result->num_rows > 0) {
            $us_row = $us_result->fetch_assoc();
            $unitStandardName = $unitStandardId . ' - ' . $us_row['unit_standard_name'];
        } else {
            // Fallback name if not in database
            $unitStandardName = $unitStandardId == '13958' 
                ? '13958 - Maintain and repair bituminous road surfaces'
                : '14555 - Conduct a bituminous seal operation';
        }
        $us_stmt->close();
        
        // Get specific outcomes for this unit standard from outcomes table
        $outcomes_query = "SELECT outcome_id, outcome_text
                          FROM outcomes
                          WHERE unitstandard_id = ?
                          AND outcome_text IS NOT NULL
                          AND outcome_text != ''
                          ORDER BY outcome_id";
        
        $outcomes_stmt = $conn->prepare($outcomes_query);
        $outcomes_stmt->bind_param('s', $unitStandardId);
        $outcomes_stmt->execute();
        $outcomes_result = $outcomes_stmt->get_result();
        
        $specific_outcomes = [];
        
        while ($outcome_row = $outcomes_result->fetch_assoc()) {
            $specific_outcomes[] = [
                'outcome_id' => $outcome_row['outcome_id'],
                'outcome_text' => $outcome_row['outcome_text']
            ];
        }
        $outcomes_stmt->close();
        
        // Add unit standard to results (even if no outcomes found)
        $unit_standards[] = [
            'unit_standard_id' => $unitStandardId,
            'unit_standard_name' => $unitStandardName,
            'unit_standard_number' => $unitStandardId,
            'specific_outcomes' => $specific_outcomes
        ];
    }
    
    $conn->close();
    
    echo json_encode([
        'status' => 'success',
        'data' => $unit_standards
    ]);
    
} catch (Exception $e) {
    if (isset($conn)) {
        $conn->close();
    }
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
