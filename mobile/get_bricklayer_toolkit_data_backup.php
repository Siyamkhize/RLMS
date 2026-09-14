<?php
/**
 * Get Bricklayer ARPL Toolkit Data
 * Simplified endpoint for Bricklayer trade
 */

header('Content-Type: application/json');
require_once 'connection.php';

try {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    $learnerID = isset($data['learnerID']) ? intval($data['learnerID']) : 0;
    $classID = isset($data['classID']) ? intval($data['classID']) : 0;
    
    if (!$learnerID || !$classID) {
        throw new Exception('Missing learnerID or classID');
    }
    
    // Load learner details
    $stmt = $conn->prepare("
        SELECT 
            LearnerID, Title, Name, Surname, IDNumber, DateOfBirth,
            PhoneNumber, Email, Gender, Race, Language,
            AddressLine1, AddressLine2, AddressLine3, PostalCode,
            SchoolName, SchoolCompletion, SchoolGrade
        FROM learnerdetails
        WHERE LearnerID = ?
    ");
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $learner = $result->fetch_assoc();
    $stmt->close();
    
    // Load class info
    $stmt = $conn->prepare("
        SELECT c.className, c.classID, s.siteName
        FROM class c
        LEFT JOIN sites s ON c.siteID = s.siteID
        WHERE c.classID = ?
    ");
    $stmt->bind_param('i', $classID);
    $stmt->execute();
    $result = $stmt->get_result();
    $class_info = $result->fetch_assoc();
    $stmt->close();
    
    // Get Bricklayer activities from trade-specific table
    $activities_result = $conn->query("
        SELECT activity_id, activity_number, activity_name
        FROM arplappxb_bricklaying_activities
        ORDER BY activity_number ASC
    ");
    
    if (!$activities_result) {
        throw new Exception('Failed to load activities: ' . $conn->error);
    }
    
    // Get saved ratings for this learner - use prepared statement
    $stmt = $conn->prepare("
        SELECT activity_id, competency_scale_id, comments, rating_date
        FROM arplappxb_activity_ratings
        WHERE learnerID = ?
    ");
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $ratings_result = $stmt->get_result();
    
    $ratings = [];
    while ($row = $ratings_result->fetch_assoc()) {
        $ratings[$row['activity_id']] = $row;
    }
    $stmt->close();
    
    // Build appendixB data in the expected format
    $appendixB = [];
    while ($activity = $activities_result->fetch_assoc()) {
        $activity_id = $activity['activity_id'];
        $has_rating = isset($ratings[$activity_id]);
        
        $rating_data = [];
        if ($has_rating) {
            $rating_data = [
                'rating_score' => $ratings[$activity_id]['competency_scale_id'],
                'comments' => $ratings[$activity_id]['comments'],
                'rating_date' => $ratings[$activity_id]['rating_date']
            ];
        }
        
        $appendixB[] = [
            'activity_id' => $activity_id,
            'activity_name' => $activity['activity_name'],
            'rating' => $has_rating ? $rating_data : null,
            'has_rating' => $has_rating
        ];
    }
    
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'learnerID' => $learnerID,
        'classID' => $classID,
        'trade' => 'bricklayer',
        'ofo_number' => '671103',
        'learner' => $learner,
        'facilitator' => null,
        'class_info' => $class_info,
        'appendixA' => null,
        'appendixB' => $appendixB,
        'appendixC' => null,
        'appendixD' => (object)[],
        'appendixE' => [],
        'appendixF' => null,
        'appendixG' => null,
        'appendixH' => (object)[
            'items' => [],
            'recommendations' => [],
            'gap_standards' => []
        ],
        'appendixI' => null,
        'appendixJ' => null
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
