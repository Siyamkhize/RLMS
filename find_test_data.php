<?php
require_once 'web/connection.php';

echo "=== CHECKING FOR ACTUAL ARPL DATA ===\n\n";

// Check theory ratings
echo "Theory Activity Ratings - First 10:\n";
$ratings = $conn->query("SELECT learnerID, COUNT(*) as cnt FROM arplappxb_activity_ratings GROUP BY learnerID LIMIT 10");
if ($ratings && $ratings->num_rows > 0) {
    while ($row = $ratings->fetch_assoc()) {
        echo "  Learner " . $row['learnerID'] . ": " . $row['cnt'] . " ratings\n";
    }
}

// Check workplace activities
echo "\nWorkplace Activity Ratings - First 10 Learners:\n";
$wp = $conn->query("SELECT learnerID, COUNT(*) as cnt FROM arplappxe_electrician_activity_ratings GROUP BY learnerID LIMIT 10");
if ($wp && $wp->num_rows > 0) {
    while ($row = $wp->fetch_assoc()) {
        echo "  Learner " . $row['learnerID'] . ": " . $row['cnt'] . " ratings\n";
    }
}

// Check ACR
echo "\nAccess Recommendations - All:\n";
$acr = $conn->query("SELECT * FROM arplelectrician_access_recommendation");
if ($acr && $acr->num_rows > 0) {
    while ($row = $acr->fetch_assoc()) {
        echo "  Learner " . $row['LearnerID'] . ", ACRID " . $row['ACRID'] . ", Status: " . $row['Status'] . "\n";
    }
} else {
    echo "  No ACR records found\n";
}

// Get a sample learner with ratings
echo "\nSample Learner with Theory Ratings:\n";
$sample = $conn->query("SELECT DISTINCT learnerID FROM arplappxb_activity_ratings LIMIT 1");
if ($sample && $sample->num_rows > 0) {
    $row = $sample->fetch_assoc();
    $sampleLearnerID = $row['learnerID'];
    echo "Using Learner: $sampleLearnerID\n\n";
    
    echo "Theory Ratings for Learner $sampleLearnerID:\n";
    $details = $conn->query("SELECT * FROM arplappxb_activity_ratings WHERE learnerID = $sampleLearnerID LIMIT 3");
    if ($details) {
        while ($r = $details->fetch_assoc()) {
            echo "  Activity: " . $r['activity_name'] . ", Rating ID: " . $r['competency_scale_id'] . "\n";
        }
    }
}

$conn->close();
?>
