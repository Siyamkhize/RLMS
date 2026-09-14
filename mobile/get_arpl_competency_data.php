<?php
/**
 * Get ARPL Competency Scale and Activity Ratings
 * Fetches activities based on learner's OFO number
 */

header('Content-Type: application/json');
require_once '../connection.php';

$learnerID = intval($_GET['learnerID'] ?? 0);
$ofo_number = $_GET['ofo_number'] ?? ''; // Accept as string

if (!$learnerID) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Learner ID required']);
    exit;
}

// If OFO not provided, try to get it from arpl_poe table
if (empty($ofo_number)) {
    $ofoSQL = "
        SELECT DISTINCT ofo_number FROM arpl_poe
        WHERE learnerID = $learnerID
        LIMIT 1
    ";
    $ofoResult = $conn->query($ofoSQL);
    if ($ofoResult && $ofoResult->num_rows > 0) {
        $ofoRow = $ofoResult->fetch_assoc();
        $ofo_text = strtolower(trim($ofoRow['ofo_number'] ?? ''));
        
        // Map OFO text/number to OFO code
        $ofo_map = [
            'electrician' => '671101',
            '671101' => '671101',
            'plumber' => '671201',
            '671201' => '671201',
            'bricklayer' => '641201',
            'bricklaying' => '641201',
            '641201' => '641201',
            'gas fitter' => '671301',
            '671301' => '671301',
            'hvac' => '671401',
            '671401' => '671401',
        ];
        
        $ofo_number = $ofo_map[$ofo_text] ?? '671101'; // Default to Electrician
    } else {
        // Fallback: Default to Electrician (671101) if no ARPL data found
        $ofo_number = '671101';
    }
}

// 1. Get Competency Scale (master reference data)
$scaleSQL = "
    SELECT score, proficiency_level, description
    FROM arpl_competency_scale
    ORDER BY score ASC
";

$scaleResult = $conn->query($scaleSQL);
if (!$scaleResult) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $conn->error]);
    exit;
}

$competencyScale = [];
while ($row = $scaleResult->fetch_assoc()) {
    $competencyScale[] = $row;
}

// 2. Get Activities based on OFO number
// Map OFO to correct activities table
$activitiesTable = '';
$ofo_str = strval($ofo_number); // Ensure string comparison
switch ($ofo_str) {
    case '671101':
        $activitiesTable = 'arplappxb_electrician_activities';
        break;
    case '671201': // Plumber
    case '642601':
        $activitiesTable = 'arplappxb_plumber_activities';
        break;
    case '641201': // Bricklayer
        $activitiesTable = 'arplappxb_bricklaying_activities';
        break;
    default:
        // Default to electrician if unknown OFO
        $activitiesTable = 'arplappxb_electrician_activities';
        break;
}

// Check if table exists first
$tableCheck = $conn->query("SHOW TABLES LIKE '$activitiesTable'");
if (!$tableCheck || $tableCheck->num_rows == 0) {
    echo json_encode([
        'status' => 'error',
        'message' => "Activities table not found for OFO $ofo_number (table: $activitiesTable)",
        'ofo_number' => $ofo_number,
        'table_name' => $activitiesTable
    ]);
    exit;
}

$activitiesSQL = "
    SELECT activity_id, activity_number, activity_name, ofo_number
    FROM `$activitiesTable`
    WHERE ofo_number = '$ofo_number'
    ORDER BY activity_number ASC
";

$activitiesResult = $conn->query($activitiesSQL);
if (!$activitiesResult) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $conn->error]);
    exit;
}

$activities = [];
while ($row = $activitiesResult->fetch_assoc()) {
    $activities[] = $row;
}

// 3. Get Appendix B Activities (same as activities for this implementation)
$appxbActivities = $activities;

// 4. Get Activity Ratings for this learner
$ratingsSQL = "
    SELECT
        aar.activity_rating_id,
        aar.activity_id,
        aar.competency_scale_id as rating_score,
        acs.proficiency_level,
        acs.description as scale_description,
        aar.assessor_id,
        aar.rating_date,
        aar.comments
    FROM arplappxb_activity_ratings aar
    LEFT JOIN arpl_competency_scale acs ON aar.competency_scale_id = acs.score
    WHERE aar.learnerID = $learnerID
    ORDER BY aar.activity_id ASC
";

$ratingsResult = $conn->query($ratingsSQL);
if (!$ratingsResult) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $conn->error]);
    exit;
}

$activityRatings = [];
$appxbRatings = [];
while ($row = $ratingsResult->fetch_assoc()) {
    $activityRatings[] = $row;
    $appxbRatings[] = $row;
}

// Return combined data
echo json_encode([
    'status' => 'success',
    'competency_scale' => $competencyScale,
    'activities' => $activities,
    'appxb_activities' => $appxbActivities,
    'activity_ratings' => $activityRatings,
    'appxb_ratings' => $appxbRatings,
    'ofo_number' => $ofo_number,
    'learnerID' => $learnerID,
    'total_activities' => count($activities),
    'rated_activities' => count($appxbRatings)
]);

$conn->close();
