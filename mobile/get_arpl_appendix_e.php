<?php
// API Endpoint: Get ARPL Appendix E Activities and Ratings
// Fetches activities from arplappxe_electrician_activities
// Fetches existing ratings from arplappxe_electrician_activity_ratings

require_once 'connection.php';
header('Content-Type: application/json');

$response = [
    'status' => 'error',
    'message' => '',
    'activities' => [],
    'existing_ratings' => []
];

try {
    // Accept both GET and POST for flexibility
    if (isset($_POST['learnerID'])) {
        $learnerID = intval($_POST['learnerID']);
    } elseif (isset($_GET['learnerID'])) {
        $learnerID = intval($_GET['learnerID']);
    } else {
        $learnerID = 0;
    }

    if (isset($_POST['ofo_number'])) {
        $ofo_number = $conn->real_escape_string(trim($_POST['ofo_number']));
    } elseif (isset($_GET['ofo_number'])) {
        $ofo_number = $conn->real_escape_string(trim($_GET['ofo_number']));
    } else {
        $ofo_number = '671101';
    }

    if (isset($_POST['facilitator_id'])) {
        $facilitator_id = intval($_POST['facilitator_id']);
    } elseif (isset($_GET['facilitator_id'])) {
        $facilitator_id = intval($_GET['facilitator_id']);
    } else {
        $facilitator_id = 0;
    }
    
    if ($learnerID <= 0) {
        throw new InvalidArgumentException("Valid learnerID is required");
    }
    
    // Fetch all activities for the OFO number
    $stmt = $conn->prepare("
        SELECT
            activity_id,
            activity_number,
            activity_name,
            ofo_number,
            created_at
        FROM arplappxe_electrician_activities
        WHERE ofo_number = ?
        ORDER BY activity_number ASC, activity_id ASC
    ");
    $stmt->bind_param('s', $ofo_number);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $response['activities'][] = $row;
    }
    $stmt->close();
    
    // Fetch existing ratings for this learner
    $stmt = $conn->prepare("
        SELECT
            activity_rating_id,
            learnerID,
            ofo_number,
            activity_id,
            activity_name,
            competency_scale_id,
            facilitator_id,
            rating_date,
            comments,
            created_at
        FROM arplappxe_electrician_activity_ratings
        WHERE learnerID = ?
        AND ofo_number = ?
    ");
    $stmt->bind_param('is', $learnerID, $ofo_number);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $existing = [];
    while ($row = $result->fetch_assoc()) {
        $existing[] = $row;
    }
    $stmt->close();
    
    // Create a map of activity_id => rating
    $ratingsMap = [];
    foreach ($existing as $rating) {
        $ratingsMap[$rating['activity_id']] = [
            'activity_rating_id' => $rating['activity_rating_id'],
            'competency_scale_id' => $rating['competency_scale_id'],
            'comments' => $rating['comments'],
            'rating_date' => $rating['rating_date'],
            'facilitator_id' => $rating['facilitator_id']
        ];
    }
    
    $response['existing_ratings'] = $ratingsMap;
    $response['status'] = 'success';
    $response['message'] = 'Activities and ratings retrieved successfully';
    $response['total_activities'] = count($response['activities']);
    $response['rated_count'] = count($existing);

} catch (InvalidArgumentException $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in get_arpl_appendix_e.php: " . $e->getMessage());
} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in get_arpl_appendix_e.php: " . $e->getMessage());
}

echo json_encode($response);
