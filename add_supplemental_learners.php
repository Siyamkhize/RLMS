<?php
/**
 * Add Supplemental Learners to Existing Moderation Assignments
 * 
 * This script adds additional learners to reach a target count (402)
 * WITHOUT removing or modifying existing assignments (some already moderated)
 * 
 * EXCLUDES: classID 74 (testing class)
 * TARGET: 402 total learners (currently 373, need 29 more)
 */

// Enable error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Increase timeout for safety
ini_set('max_execution_time', 300);
set_time_limit(300);

// Include database connection
include('connection.php');

// Set proper headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

/**
 * Get database connection
 */
function getDatabaseConnection() {
    global $conn;
    if (!$conn) {
        throw new Exception("Database connection not available");
    }
    return $conn;
}

/**
 * Get moderator's allocated classes (excluding classID 74)
 */
function getModeratorClasses($mysqli, $moderatorId) {
    $sql = "SELECT DISTINCT classID FROM facilitator WHERE facilitator_id = ?";
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param("s", $moderatorId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $classIds = [];
    while ($row = $result->fetch_assoc()) {
        $classIdValue = $row['classID'];
        
        // Handle comma-separated values
        if (strpos($classIdValue, ',') !== false) {
            $splitIds = explode(',', $classIdValue);
            foreach ($splitIds as $id) {
                $trimmedId = trim($id);
                if (!empty($trimmedId) && $trimmedId != '74' && !in_array($trimmedId, $classIds)) {
                    $classIds[] = $trimmedId;
                }
            }
        } else {
            if (!empty($classIdValue) && $classIdValue != '74' && !in_array($classIdValue, $classIds)) {
                $classIds[] = $classIdValue;
            }
        }
    }
    
    $stmt->close();
    return $classIds;
}

/**
 * Get current assignment count for moderator
 */
function getCurrentAssignmentCount($mysqli, $moderatorId) {
    $sql = "SELECT COUNT(*) as count FROM moderator_assignments WHERE moderator_id = ?";
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param("s", $moderatorId);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    $stmt->close();
    
    return (int)$row['count'];
}

/**
 * Get additional learners to supplement existing assignments
 * Uses same stratified sampling approach but only selects unassigned learners
 */
function getSupplementalLearners($mysqli, $moderatorId, $targetCount) {
    // Get current count
    $currentCount = getCurrentAssignmentCount($mysqli, $moderatorId);
    $neededCount = $targetCount - $currentCount;
    
    if ($neededCount <= 0) {
        return [
            'current_count' => $currentCount,
            'target_count' => $targetCount,
            'needed_count' => 0,
            'learners' => [],
            'message' => 'Target already reached or exceeded'
        ];
    }
    
    // Get moderator's classes (excluding 74)
    $moderatorClasses = getModeratorClasses($mysqli, $moderatorId);
    
    if (empty($moderatorClasses)) {
        throw new Exception("No classes allocated to moderator");
    }
    
    // Build class filter
    $escapedClasses = array_map(function($classId) use ($mysqli) {
        return "'" . $mysqli->real_escape_string($classId) . "'";
    }, $moderatorClasses);
    $classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";
    
    // Get available learners (not already assigned, excluding classID 74)
    $sql = "SELECT DISTINCT 
                l.LearnerID,
                l.Name,
                l.Surname,
                l.IDNumber,
                l.Email,
                l.PhoneNumber,
                l.classID,
                COALESCE(c.className, 'Unknown Class') as className,
                COALESCE(c.siteID, 'Unknown') as siteID,
                COALESCE(s.siteName, 'Unknown Site') as siteName
            FROM learnerdetails l
            INNER JOIN poe p ON l.LearnerID = p.learnerID
            LEFT JOIN class c ON l.classID = c.classID
            LEFT JOIN sites s ON c.siteID = s.siteID
            WHERE p.filePath IS NOT NULL AND p.filePath != ''
            AND l.LearnerID NOT IN (
                SELECT learner_id FROM moderator_assignments
            )
            $classFilter
            ORDER BY RAND()
            LIMIT ?";
    
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param("i", $neededCount);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $learners = [];
    while ($row = $result->fetch_assoc()) {
        $learners[] = $row;
    }
    
    $stmt->close();
    
    return [
        'current_count' => $currentCount,
        'target_count' => $targetCount,
        'needed_count' => $neededCount,
        'found_count' => count($learners),
        'learners' => $learners
    ];
}

/**
 * Add supplemental learners to moderator assignments
 */
function addSupplementalAssignments($mysqli, $moderatorId, $learners) {
    $sql = "INSERT INTO moderator_assignments 
            (moderator_id, learner_id, class_id, site_id, stratum_type, 
             poe_completeness, marking_status, performance_level, poe_count) 
            VALUES (?, ?, ?, ?, 'supplemental', 'Unknown', 'Unknown', 'Unknown', 0)";
    $stmt = $mysqli->prepare($sql);
    
    $addedCount = 0;
    foreach ($learners as $learner) {
        $learnerId = $learner['LearnerID'];
        $classId = $learner['classID'] ?? null;
        $siteId = $learner['siteID'] ?? null;
        
        $stmt->bind_param("siss", $moderatorId, $learnerId, $classId, $siteId);
        
        if ($stmt->execute()) {
            $addedCount++;
        } else {
            // Skip if already assigned (duplicate key error)
            if ($mysqli->errno != 1062) {
                error_log("Failed to assign learner $learnerId: " . $stmt->error);
            }
        }
    }
    
    $stmt->close();
    return $addedCount;
}

// Main API logic
try {
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'POST') {
        // Get parameters
        $data = json_decode(file_get_contents("php://input"), true);
        $moderatorId = $data['moderator_id'] ?? $_GET['moderator_id'] ?? '';
        $targetCount = $data['target_count'] ?? $_GET['target_count'] ?? 402;
        
        if (empty($moderatorId)) {
            http_response_code(400);
            echo json_encode([
                'status' => 'error',
                'message' => 'moderator_id parameter is required'
            ]);
            exit();
        }
        
        // Create database connection
        $mysqli = getDatabaseConnection();
        
        // Get supplemental learners
        $supplementalData = getSupplementalLearners($mysqli, $moderatorId, $targetCount);
        
        if ($supplementalData['needed_count'] <= 0) {
            http_response_code(200);
            echo json_encode([
                'status' => 'success',
                'message' => 'Target count already reached',
                'data' => $supplementalData
            ]);
            exit();
        }
        
        // Add supplemental assignments
        $addedCount = addSupplementalAssignments($mysqli, $moderatorId, $supplementalData['learners']);
        
        // Get final count
        $finalCount = getCurrentAssignmentCount($mysqli, $moderatorId);
        
        // Return success response
        http_response_code(200);
        echo json_encode([
            'status' => 'success',
            'message' => "Added $addedCount supplemental learners. Total now: $finalCount",
            'data' => [
                'previous_count' => $supplementalData['current_count'],
                'target_count' => $targetCount,
                'needed_count' => $supplementalData['needed_count'],
                'added_count' => $addedCount,
                'final_count' => $finalCount,
                'excluded_class' => '74 (testing class)',
                'added_learners' => $supplementalData['learners']
            ]
        ]);
        
    } else {
        // Method not allowed
        http_response_code(405);
        echo json_encode([
            'status' => 'error',
            'message' => 'Method not allowed. Use POST to add supplemental learners.'
        ]);
    }
    
} catch (Exception $e) {
    // Log error
    error_log("Add Supplemental Learners API Error: " . $e->getMessage());
    
    // Return error response
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
