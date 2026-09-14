<?php
/**
 * Add Supplemental Learners - Uses existing assignments to determine classes
 * This version doesn't query the facilitator table
 * Instead, it looks at which classes already have assignments
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('max_execution_time', 180);
set_time_limit(180);

include('connection.php');

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function getDatabaseConnection() {
    global $conn;
    if (!$conn) {
        throw new Exception("Database connection not available");
    }
    return $conn;
}

try {
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'POST' || $method === 'GET') {
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
        
        $mysqli = getDatabaseConnection();
        
        // Step 1: Get current count
        $sql = "SELECT COUNT(*) as count FROM moderator_assignments WHERE moderator_id = ?";
        $stmt = $mysqli->prepare($sql);
        $stmt->bind_param("s", $moderatorId);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $currentCount = (int)$row['count'];
        $stmt->close();
        
        $neededCount = $targetCount - $currentCount;
        
        if ($neededCount <= 0) {
            http_response_code(200);
            echo json_encode([
                'status' => 'success',
                'message' => 'Target count already reached',
                'data' => [
                    'current_count' => $currentCount,
                    'target_count' => $targetCount,
                    'needed_count' => 0,
                    'added_count' => 0,
                    'final_count' => $currentCount
                ]
            ]);
            exit();
        }
        
        // Step 2: Get classes from existing assignments (SMART!)
        // This way we don't need to query facilitator table
        $sql = "SELECT DISTINCT class_id 
                FROM moderator_assignments 
                WHERE moderator_id = ? 
                AND class_id IS NOT NULL 
                AND class_id != '' 
                AND class_id != '74'";
        $stmt = $mysqli->prepare($sql);
        $stmt->bind_param("s", $moderatorId);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $classIds = [];
        while ($row = $result->fetch_assoc()) {
            $classId = $row['class_id'];
            if (!empty($classId) && $classId != '74') {
                $classIds[] = $classId;
            }
        }
        $stmt->close();
        
        if (empty($classIds)) {
            throw new Exception("No classes found in existing assignments");
        }
        
        // Step 3: Get available learners from same classes
        $escapedClasses = array_map(function($classId) use ($mysqli) {
            return "'" . $mysqli->real_escape_string($classId) . "'";
        }, $classIds);
        $classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";
        
        // Use LEFT JOIN for better performance
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
                LEFT JOIN moderator_assignments ma ON l.LearnerID = ma.learner_id
                WHERE p.filePath IS NOT NULL 
                AND p.filePath != ''
                AND ma.learner_id IS NULL
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
        
        if (empty($learners)) {
            http_response_code(200);
            echo json_encode([
                'status' => 'success',
                'message' => 'No additional learners available in allocated classes',
                'data' => [
                    'current_count' => $currentCount,
                    'target_count' => $targetCount,
                    'needed_count' => $neededCount,
                    'added_count' => 0,
                    'final_count' => $currentCount,
                    'classes_checked' => $classIds
                ]
            ]);
            exit();
        }
        
        // Step 4: Add supplemental assignments (BATCH INSERT)
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
                if ($mysqli->errno != 1062) { // Ignore duplicate key errors
                    error_log("Failed to assign learner $learnerId: " . $stmt->error);
                }
            }
        }
        $stmt->close();
        
        // Step 5: Get final count
        $sql = "SELECT COUNT(*) as count FROM moderator_assignments WHERE moderator_id = ?";
        $stmt = $mysqli->prepare($sql);
        $stmt->bind_param("s", $moderatorId);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $finalCount = (int)$row['count'];
        $stmt->close();
        
        http_response_code(200);
        echo json_encode([
            'status' => 'success',
            'message' => "Added $addedCount supplemental learners. Total now: $finalCount",
            'data' => [
                'previous_count' => $currentCount,
                'target_count' => $targetCount,
                'needed_count' => $neededCount,
                'added_count' => $addedCount,
                'final_count' => $finalCount,
                'classes_used' => $classIds,
                'excluded_class' => '74 (testing class)',
                'sample_learners' => array_slice($learners, 0, 5) // First 5 only
            ]
        ]);
        
    } else {
        http_response_code(405);
        echo json_encode([
            'status' => 'error',
            'message' => 'Method not allowed. Use POST or GET.'
        ]);
    }
    
} catch (Exception $e) {
    error_log("Add Supplemental Learners Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
