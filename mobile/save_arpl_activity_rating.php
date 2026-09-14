<?php
/**
 * Save ARPL Activity Rating
 * Stores learner rating for an electrician activity
 */

header('Content-Type: application/json');
require_once '../connection.php';

$learnerID = intval($_POST['learnerID'] ?? 0);
$activity_id = intval($_POST['activity_id'] ?? 0);
$rating_score = intval($_POST['rating_score'] ?? 0);
$assessor_id = intval($_POST['assessor_id'] ?? 0);
$comments = $_POST['comments'] ?? '';
$ofo_number = intval($_POST['ofo_number'] ?? 671101);
$activity_name = $_POST['activity_name'] ?? '';

if (!$learnerID || !$activity_id || !$rating_score) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Missing required parameters']);
    exit;
}

if ($rating_score < 1 || $rating_score > 5) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Rating must be between 1 and 5']);
    exit;
}

// Check if rating exists for this learner and activity
$checkSQL = "
    SELECT activity_rating_id FROM arplappxb_activity_ratings
    WHERE learnerID = $learnerID AND activity_id = $activity_id
";

$checkResult = $conn->query($checkSQL);
if (!$checkResult) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database error']);
    exit;
}

$escaped_comments = $conn->real_escape_string($comments);
$escaped_activity_name = $conn->real_escape_string($activity_name);

if ($checkResult->num_rows > 0) {
    // Update existing rating
    $updateSQL = "
        UPDATE arplappxb_activity_ratings
        SET 
            competency_scale_id = $rating_score,
            assessor_id = " . ($assessor_id ? $assessor_id : 'NULL') . ",
            comments = '$escaped_comments',
            rating_date = NOW()
        WHERE learnerID = $learnerID AND activity_id = $activity_id
    ";
    
    if ($conn->query($updateSQL)) {
        echo json_encode(['status' => 'success', 'message' => 'Rating updated']);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to update rating: ' . $conn->error]);
    }
} else {
    // Insert new rating
    $insertSQL = "
        INSERT INTO arplappxb_activity_ratings 
        (learnerID, ofo_number, activity_id, activity_name, competency_scale_id, assessor_id, comments, rating_date)
        VALUES ($learnerID, $ofo_number, $activity_id, '$escaped_activity_name', $rating_score, " . ($assessor_id ? $assessor_id : 'NULL') . ", '$escaped_comments', NOW())
    ";
    
    if ($conn->query($insertSQL)) {
        $newId = $conn->insert_id;
        echo json_encode(['status' => 'success', 'message' => 'Rating saved', 'activity_rating_id' => $newId]);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to save rating: ' . $conn->error]);
    }
}

$conn->close();

