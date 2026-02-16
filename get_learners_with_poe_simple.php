<?php
/**
 * Simple API - Just return learners with POE
 * No stratification, no sampling, no complex queries
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

include('connection.php');

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        $moderatorId = $_GET['moderator_id'] ?? '';
        
        if (empty($moderatorId)) {
            http_response_code(400);
            echo json_encode([
                'status' => 'error',
                'message' => 'moderator_id parameter is required'
            ]);
            exit();
        }
        
        // Get moderator's classes
        $sql = "SELECT DISTINCT classID FROM facilitator WHERE facilitator_id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $moderatorId);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $moderatorClasses = [];
        while ($row = $result->fetch_assoc()) {
            $classIdValue = $row['classID'];
            
            // Handle comma-separated class IDs
            if (strpos($classIdValue, ',') !== false) {
                $splitIds = explode(',', $classIdValue);
                foreach ($splitIds as $id) {
                    $trimmedId = trim($id);
                    if (!empty($trimmedId) && !in_array($trimmedId, $moderatorClasses)) {
                        $moderatorClasses[] = $trimmedId;
                    }
                }
            } else {
                if (!empty($classIdValue) && !in_array($classIdValue, $moderatorClasses)) {
                    $moderatorClasses[] = $classIdValue;
                }
            }
        }
        $stmt->close();
        
        if (empty($moderatorClasses)) {
            http_response_code(200);
            echo json_encode([
                'status' => 'success',
                'message' => 'No classes allocated to this moderator',
                'data' => [
                    'total_learners_with_poe' => 0,
                    'learners' => []
                ]
            ]);
            exit();
        }
        
        // Build class filter
        $escapedClasses = array_map(function($classId) use ($conn) {
            return "'" . $conn->real_escape_string($classId) . "'";
        }, $moderatorClasses);
        $classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";
        
        // Simple query - just get learners with POE
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
                    COUNT(DISTINCT p.id) as poe_count
                FROM poe p
                INNER JOIN learnerdetails l ON p.learnerID = l.LearnerID
                LEFT JOIN class c ON l.classID = c.classID
                WHERE p.filePath IS NOT NULL AND p.filePath != ''
                $classFilter
                GROUP BY l.LearnerID, l.Name, l.Surname, l.IDNumber, l.Email, 
                         l.PhoneNumber, l.classID, c.className, c.siteID
                ORDER BY l.Surname, l.Name
                LIMIT 2000";
        
        $result = $conn->query($sql);
        
        if (!$result) {
            throw new Exception("Query failed: " . $conn->error);
        }
        
        $learners = [];
        while ($row = $result->fetch_assoc()) {
            $learners[] = $row;
        }
        
        $totalCount = count($learners);
        
        http_response_code(200);
        echo json_encode([
            'status' => 'success',
            'message' => 'Learners with POE retrieved successfully',
            'data' => [
                'total_learners_with_poe' => $totalCount,
                'learners' => $learners
            ]
        ]);
        
    } else {
        http_response_code(405);
        echo json_encode([
            'status' => 'error',
            'message' => 'Method not allowed. Use GET to retrieve learners with POE.'
        ]);
    }
    
} catch (Exception $e) {
    error_log("Get Learners with POE API Error: " . $e->getMessage());
    
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
