<?php
/**
 * Get learners with POE for moderation
 * Returns 25% random selection of all learners who have uploaded POE
 */

// Enable error reporting for debugging (remove in production)
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Include database connection
include('connection.php');

// Set proper headers for API response
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

/**
 * Get database connection from connection.php
 */
function getDatabaseConnection() {
    global $conn;
    
    if (!$conn) {
        throw new Exception("Database connection not available");
    }
    
    return $conn;
}

/**
 * Get all learners who have uploaded POE and return 25% random selection
 */
function getLearnersWithPOE($mysqli) {
    // Query to get all learners who have uploaded POE
    $sql = "SELECT DISTINCT 
                l.LearnerID,
                l.Name,
                l.Surname,
                l.IDNumber,
                l.Email,
                l.PhoneNumber,
                l.classID,
                COALESCE(c.className, 'Unknown Class') as className,
                COUNT(p.poe_id) as poe_count,
                MAX(p.submitted_at) as last_poe_submission
            FROM learnerdetails l
            INNER JOIN poe p ON l.LearnerID = p.learnerID
            LEFT JOIN class c ON l.classID = c.classID
            WHERE p.filePath IS NOT NULL 
            AND p.filePath != ''
            GROUP BY l.LearnerID, l.Name, l.Surname, l.IDNumber, l.Email, l.PhoneNumber, l.classID, c.className
            ORDER BY RAND()";
    
    $stmt = $mysqli->prepare($sql);
    if (!$stmt) {
        throw new Exception("Failed to prepare statement: " . $mysqli->error);
    }
    
    if (!$stmt->execute()) {
        throw new Exception("Failed to execute query: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $allLearners = [];
    
    while ($row = $result->fetch_assoc()) {
        $allLearners[] = $row;
    }
    
    $stmt->close();
    
    // Calculate 25% of total learners
    $totalLearners = count($allLearners);
    $selectionCount = max(1, ceil($totalLearners * 0.25)); // At least 1 learner
    
    // Get random selection
    $selectedLearners = array_slice($allLearners, 0, $selectionCount);
    
    return [
        'total_learners_with_poe' => $totalLearners,
        'selected_count' => $selectionCount,
        'learners' => $selectedLearners
    ];
}

// Main API logic
try {
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        // Create database connection
        $mysqli = getDatabaseConnection();
        
        // Get learners with POE (25% random selection)
        $result = getLearnersWithPOE($mysqli);
        
        // Return success response
        http_response_code(200);
        echo json_encode([
            'status' => 'success',
            'message' => 'Learners with POE retrieved successfully',
            'data' => $result
        ]);
        
    } else {
        // Method not allowed
        http_response_code(405);
        echo json_encode([
            'status' => 'error',
            'message' => 'Method not allowed. Use GET to retrieve learners with POE.'
        ]);
    }
    
} catch (Exception $e) {
    // Log error
    error_log("Get Learners with POE API Error: " . $e->getMessage());
    
    // Return error response
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
