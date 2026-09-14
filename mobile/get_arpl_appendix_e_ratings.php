<?php
/**
 * ARPL APPENDIX E: Get Electrician Activity Ratings
 * Endpoint: GET /mobile/get_arpl_appendix_e_ratings.php
 * 
 * Retrieves electrician activities with their competency ratings
 * 
 * Query Parameters:
 * - learnerID: required (int)
 * - facilitator_id: optional (int)
 * - ofo_number: optional (string)
 * 
 * Response:
 * {
 *   "status": "success",
 *   "data": {
 *     "activities": [
 *       {
 *         "activity_id": 1,
 *         "activity_name": "Activity Name",
 *         "competency_scale_id": 1,
 *         "rating": 4,
 *         "comments": "Good performance",
 *         "rating_date": "2026-07-08"
 *       },
 *       ...
 *     ],
 *     "learnerID": 11515,
 *     "facilitator_id": 1,
 *     "ofo_number": "671101"
 *   }
 * }
 */

header('Content-Type: application/json');

try {
    // Get parameters
    $learnerID = isset($_GET['learnerID']) ? intval($_GET['learnerID']) : null;
    $facilitator_id = isset($_GET['facilitator_id']) ? intval($_GET['facilitator_id']) : null;
    $ofo_number = isset($_GET['ofo_number']) ? $_GET['ofo_number'] : null;
    
    if (!$learnerID) {
        throw new Exception('Missing required parameter: learnerID');
    }
    
    require_once(__DIR__ . '/../connection.php');
    
    if (!$conn) {
        throw new Exception('Database connection failed');
    }
    
    // Get all electrician activities
    $query = "SELECT 
                activity_id,
                activity_number,
                activity_name,
                ofo_number
              FROM arplappxe_electrician_activities
              ORDER BY activity_number ASC, activity_id ASC";
    
    $result = $conn->query($query);
    
    if (!$result) {
        throw new Exception('Query failed: ' . $conn->error);
    }
    
    $activities = [];
    while ($row = $result->fetch_assoc()) {
        $activity_id = $row['activity_id'];
        
        // Get the rating for this activity if it exists
        $rating_query = "SELECT 
                            competency_scale_id,
                            comments,
                            rating_date
                         FROM arplappxe_electrician_activity_ratings
                         WHERE learnerID = ?";
        
        $params = [$learnerID];
        
        if ($facilitator_id) {
            $rating_query .= " AND facilitator_id = ?";
            $params[] = $facilitator_id;
        }
        
        if ($ofo_number) {
            $rating_query .= " AND ofo_number = ?";
            $params[] = $ofo_number;
        }
        
        $rating_query .= " AND activity_id = ?";
        $params[] = $activity_id;
        
        $stmt = $conn->prepare($rating_query);
        
        if (!$stmt) {
            throw new Exception('Prepare failed: ' . $conn->error);
        }
        
        // Build type string for bind_param
        $types = 'i';
        for ($i = 1; $i < count($params); $i++) {
            $types .= is_int($params[$i]) ? 'i' : 's';
        }
        
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $rating_result = $stmt->get_result();
        $rating_row = $rating_result->fetch_assoc();
        $stmt->close();
        
        $activities[] = [
            'activity_id' => intval($activity_id),
            'activity_number' => intval($row['activity_number']),
            'activity_name' => $row['activity_name'],
            'ofo_number' => $row['ofo_number'],
            'competency_scale_id' => $rating_row ? intval($rating_row['competency_scale_id']) : null,
            'comments' => $rating_row ? $rating_row['comments'] : '',
            'rating_date' => $rating_row ? $rating_row['rating_date'] : null
        ];
    }
    
    echo json_encode([
        'status' => 'success',
        'data' => [
            'activities' => $activities,
            'learnerID' => $learnerID,
            'facilitator_id' => $facilitator_id,
            'ofo_number' => $ofo_number
        ]
    ]);
    
    $conn->close();
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
