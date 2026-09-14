<?php
/**
 * Direct test - Exactly what the app should receive
 * Visit this URL to see the exact JSON the app gets
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'connection.php';

// Hardcode test values
$learnerID = 11701;
$ofoNumber = '641201';

$response = [
    'status' => 'success',
    'data' => [
        'knowledge' => [],
        'practical' => [],
        'workplace_observations' => []
    ],
    'debug' => []
];

try {
    // Get all activities for this OFO
    $activitiesTable = 'arplappxe_bricklaying_activities';
    
    $response['debug']['table'] = $activitiesTable;
    $response['debug']['learnerID'] = $learnerID;
    $response['debug']['ofoNumber'] = $ofoNumber;
    
    $sqlObservations = "
        SELECT 
            a.activity_id,
            a.activity_name as task_observed,
            COALESCE(wo.technical_knowledge, 1) as technical_knowledge,
            COALESCE(wo.interpretation_of_instructions, 1) as interpretation_of_instructions,
            COALESCE(wo.team_work_attitude, 1) as team_work_attitude,
            wo.id as observation_id
        FROM `$activitiesTable` a
        LEFT JOIN arpl_appendix_f_workplace_observations wo
            ON a.activity_id = wo.activity_id 
            AND wo.learnerID = ? 
            AND wo.ofoNumber = ?
        ORDER BY a.activity_id ASC
    ";
    
    $stmt = $conn->prepare($sqlObservations);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $count = 0;
    while ($row = $result->fetch_assoc()) {
        $response['data']['workplace_observations'][] = [
            'activity_id' => intval($row['activity_id']),
            'task_observed' => $row['task_observed'],
            'technical_knowledge' => intval($row['technical_knowledge']),
            'interpretation_of_instructions' => intval($row['interpretation_of_instructions']),
            'team_work_attitude' => intval($row['team_work_attitude']),
            'has_rating' => !is_null($row['observation_id'])
        ];
        $count++;
    }
    
    $response['debug']['observations_loaded'] = $count;
    $stmt->close();
    
} catch (Exception $e) {
    $response['status'] = 'error';
    $response['message'] = $e->getMessage();
    $response['debug']['error_details'] = [
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ];
}

$conn->close();

echo json_encode($response, JSON_PRETTY_PRINT);
?>
