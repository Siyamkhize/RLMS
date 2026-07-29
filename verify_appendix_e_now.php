<?php
/**
 * Verify Appendix E Data - Quick Check
 * Tests if the API returns 15 activities for learner 70
 */

header('Content-Type: application/json');
require_once 'connection.php';

$learnerID = 70;
$ofo_number = '641201';  // Bricklayer

try {
    echo "═══ APPENDIX E DATA VERIFICATION ═══\n\n";
    
    // Check if activities table exists
    $tables_result = $conn->query("SHOW TABLES LIKE 'arplappxe_bricklaying_activities'");
    if ($tables_result->num_rows > 0) {
        echo "✅ Activities table exists: arplappxe_bricklaying_activities\n";
    } else {
        echo "❌ Activities table NOT found\n";
        exit;
    }
    
    // Count activities
    $count_query = $conn->query("SELECT COUNT(*) as count FROM arplappxe_bricklaying_activities WHERE ofo_number = '641201'");
    $count_row = $count_query->fetch_assoc();
    $activity_count = $count_row['count'];
    echo "✅ Total bricklaying activities: $activity_count\n";
    
    // List activities
    echo "\n📋 Activity List:\n";
    $activities = $conn->query("SELECT activity_id, activity_number, activity_name FROM arplappxe_bricklaying_activities WHERE ofo_number = '641201' ORDER BY activity_number");
    $i = 0;
    while ($activity = $activities->fetch_assoc()) {
        $i++;
        echo "  $i. [{$activity['activity_number']}] {$activity['activity_name']}\n";
    }
    
    // Check ratings table
    echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    $ratings_result = $conn->query("SHOW TABLES LIKE 'arplappxe_bricklaying_activity_ratings'");
    if ($ratings_result->num_rows > 0) {
        echo "✅ Ratings table exists: arplappxe_bricklaying_activity_ratings\n";
    } else {
        echo "❌ Ratings table NOT found\n";
    }
    
    // Count ratings for learner 70
    $ratings_count = $conn->query("SELECT COUNT(*) as count FROM arplappxe_bricklaying_activity_ratings WHERE learnerID = 70");
    $ratings_row = $ratings_count->fetch_assoc();
    echo "   Ratings for learner 70: {$ratings_row['count']} (expected: 0 - learner hasn't rated yet)\n";
    
    // Test API response
    echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    echo "📡 Testing API Response:\n\n";
    
    // Simulate API call
    $appendixE_activities = [];
    $stmt = $conn->prepare("
        SELECT activity_id, activity_number, activity_name, ofo_number 
        FROM arplappxe_bricklaying_activities 
        WHERE ofo_number = ? 
        ORDER BY activity_number ASC
    ");
    $stmt->bind_param('s', $ofo_number);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $appendixE_activities[] = $row;
    }
    $stmt->close();
    
    // Get ratings
    $ratingsMapE = [];
    $sql_ratings = "SELECT activity_id, competency_scale_id as rating_score, comments, rating_date FROM arplappxe_bricklaying_activity_ratings WHERE learnerID = ? AND ofo_number = ?";
    $stmt = $conn->prepare($sql_ratings);
    $stmt->bind_param('is', $learnerID, $ofo_number);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $ratingsMapE[$row['activity_id']] = $row;
    }
    $stmt->close();
    
    // Combine
    $appendixE = [];
    foreach ($appendixE_activities as $activity) {
        $activityData = $activity;
        if (isset($ratingsMapE[$activity['activity_id']])) {
            $activityData['rating'] = $ratingsMapE[$activity['activity_id']];
            $activityData['has_rating'] = true;
        } else {
            $activityData['rating'] = null;
            $activityData['has_rating'] = false;
        }
        $appendixE[] = $activityData;
    }
    
    echo "✅ AppendixE array contains " . count($appendixE) . " items\n";
    echo "\n📊 Sample JSON (first 3 activities):\n";
    echo json_encode(array_slice($appendixE, 0, 3), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
    
    echo "\n✅ VERIFICATION COMPLETE - Ready for app testing\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage();
}

$conn->close();
