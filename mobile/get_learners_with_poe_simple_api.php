<?php
/**
 * SIMPLE POE LEARNERS API - NO COMPLEX STRATIFICATION
 * Just returns learners with POE files, filtered by moderator's classes
 * No timeouts, no complex calculations, just simple queries
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);
set_time_limit(120); // 2 minutes max

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

// DATABASE CONNECTION - EMBEDDED (no external files)
$servername = "localhost";
$username = "rlmsrlmsco_ezxcmacd_rlms";
$password = "aV~4RP=_G{Uxm-Mp";
$dbname = "rlmsrlmsco_ezxcmacd_rlms";

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8");
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Database connection failed: ' . $e->getMessage()
    ]);
    exit(1);
}

// Get moderator ID from request
$moderatorId = isset($_GET['moderator_id']) ? trim($_GET['moderator_id']) : '';

if (empty($moderatorId)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'moderator_id parameter is required'
    ]);
    exit(1);
}

try {
    // STEP 1: Count total distinct learners with POE (simple count)
    $sql_count = "SELECT COUNT(DISTINCT learnerID) as total FROM poe";
    $result_count = $conn->query($sql_count);
    
    if (!$result_count) {
        throw new Exception("Count query failed: " . $conn->error);
    }
    
    $row_count = $result_count->fetch_assoc();
    $totalPOELearners = (int)$row_count['total'];
    
    // STEP 2: Get moderator's allocated classes (handle comma-separated values)
    $sql1 = "SELECT DISTINCT classID FROM facilitator WHERE facilitator_id = ?";
    $stmt1 = $conn->prepare($sql1);
    $stmt1->bind_param("s", $moderatorId);
    $stmt1->execute();
    $result1 = $stmt1->get_result();
    
    $moderatorClasses = [];
    while ($row1 = $result1->fetch_assoc()) {
        $classIdValue = $row1['classID'];
        
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
    $stmt1->close();
    
    if (empty($moderatorClasses)) {
        // No classes allocated to this moderator
        echo json_encode([
            'success' => true,
            'learners' => [],
            'total_count' => 0,
            'total_learners_with_poe' => $totalPOELearners,
            'message' => 'No classes allocated to this moderator'
        ]);
        exit(0);
    }
    
    // STEP 3: Get learners with POE in moderator's classes
    // Simple query - just get learners with POE files
    $escapedClasses = array_map(function($classId) use ($conn) {
        return "'" . $conn->real_escape_string($classId) . "'";
    }, $moderatorClasses);
    $classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";
    
    $sql2 = "SELECT DISTINCT 
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
            WHERE p.filePath IS NOT NULL 
            AND p.filePath != ''
            $classFilter
            GROUP BY l.LearnerID, l.Name, l.Surname, l.IDNumber, l.Email, 
                     l.PhoneNumber, l.classID, c.className, c.siteID
            ORDER BY c.className, l.Surname, l.Name
            LIMIT 2000";
    
    $result2 = $conn->query($sql2);
    
    if (!$result2) {
        throw new Exception("Query failed: " . $conn->error);
    }
    
    $learners = [];
    while ($row2 = $result2->fetch_assoc()) {
        $learners[] = [
            'LearnerID' => $row2['LearnerID'],
            'Name' => $row2['Name'],
            'Surname' => $row2['Surname'],
            'IDNumber' => $row2['IDNumber'],
            'Email' => $row2['Email'],
            'PhoneNumber' => $row2['PhoneNumber'],
            'classID' => $row2['classID'],
            'className' => $row2['className'],
            'siteID' => $row2['siteID'],
            'poe_count' => (int)$row2['poe_count'],
            'unit_standards_count' => (int)$row2['poe_count'] // For UI compatibility
        ];
    }
    
    // Success response
    echo json_encode([
        'success' => true,
        'learners' => $learners,
        'total_count' => count($learners),
        'total_learners_with_poe' => $totalPOELearners,
        'moderator_id' => $moderatorId,
        'moderator_classes' => $moderatorClasses,
        'class_count' => count($moderatorClasses),
        'message' => 'Simple POE query - returns all ' . $totalPOELearners . ' learners with POE'
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
} finally {
    $conn->close();
}
?>
