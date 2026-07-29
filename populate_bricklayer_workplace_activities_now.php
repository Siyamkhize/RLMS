<?php
/**
 * Populate Bricklayer Workplace Activities (Appendix E)
 * Adds the 13 key bricklaying activities to arplappxe_bricklaying_activities table
 */

require_once 'connection.php';

$ofo_number = '641201';  // Bricklayer OFO
$trade = 'bricklaying';

// 13 Bricklayer workplace activities (Appendix E)
$activities = [
    ['activity_number' => 1, 'activity_name' => 'Reading and interpreting architectural drawings and specifications'],
    ['activity_number' => 2, 'activity_name' => 'Setting out brickwork with appropriate measuring and marking tools'],
    ['activity_number' => 3, 'activity_name' => 'Preparing and mixing mortar to required consistency'],
    ['activity_number' => 4, 'activity_name' => 'Building cavity walls and demonstrating knowledge of cavity tie placement'],
    ['activity_number' => 5, 'activity_name' => 'Building solid walls with proper bonding patterns'],
    ['activity_number' => 6, 'activity_name' => 'Constructing arches and openings'],
    ['activity_number' => 7, 'activity_name' => 'Pointing and jointing brickwork to specifications'],
    ['activity_number' => 8, 'activity_name' => 'Building in lintels, wall plates, and other components'],
    ['activity_number' => 9, 'activity_name' => 'Constructing brick piers and chimney stacks'],
    ['activity_number' => 10, 'activity_name' => 'Building curved brickwork and special features'],
    ['activity_number' => 11, 'activity_name' => 'Applying protective treatments and finishes'],
    ['activity_number' => 12, 'activity_name' => 'Health, safety, and environmental compliance in brickwork'],
    ['activity_number' => 13, 'activity_name' => 'Quality control and defect rectification in brickwork'],
];

try {
    // Check if activities already exist
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM arplappxe_bricklaying_activities WHERE ofo_number = ?");
    $stmt->bind_param('s', $ofo_number);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    $existing_count = $row['count'];
    $stmt->close();

    if ($existing_count > 0) {
        echo json_encode([
            'status' => 'info',
            'message' => 'Bricklayer activities already exist',
            'count' => $existing_count
        ]);
        exit;
    }

    // Prepare insert statement
    $stmt = $conn->prepare("
        INSERT INTO arplappxe_bricklaying_activities 
        (activity_number, activity_name, ofo_number, trade, created_at, updated_at) 
        VALUES (?, ?, ?, ?, NOW(), NOW())
    ");

    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }

    $inserted = 0;
    foreach ($activities as $activity) {
        $activity_number = $activity['activity_number'];
        $activity_name = $activity['activity_name'];

        $stmt->bind_param('isss', $activity_number, $activity_name, $ofo_number, $trade);
        
        if (!$stmt->execute()) {
            throw new Exception('Execute failed for activity ' . $activity_number . ': ' . $stmt->error);
        }
        $inserted++;
    }

    $stmt->close();

    echo json_encode([
        'status' => 'success',
        'message' => 'Successfully populated bricklayer workplace activities',
        'activities_inserted' => $inserted,
        'ofo_number' => $ofo_number
    ]);

} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
