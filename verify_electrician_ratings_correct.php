<?php
require_once 'connection.php';

echo "=== Verifying Electrician Ratings (arplappxe_electrician_activity_ratings) ===\n\n";

$learnerID = 20286;
$ofo_code = '671101';

// Check the correct electrician ratings table
echo "Checking: arplappxe_electrician_activity_ratings\n";
$result = $conn->query("DESCRIBE arplappxe_electrician_activity_ratings");
if ($result && $result->num_rows > 0) {
    echo "✅ Table structure:\n";
    while ($col = $result->fetch_assoc()) {
        echo "   - {$col['Field']} ({$col['Type']})\n";
    }
} else {
    echo "❌ Table not found\n";
}

echo "\nSample data from arplappxe_electrician_activity_ratings:\n";
$result = $conn->query("SELECT * FROM arplappxe_electrician_activity_ratings LIMIT 3");
if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        echo json_encode($row) . "\n";
    }
} else {
    echo "No data found\n";
}

// Test the exact query that will be used in arpl_pdf.php
echo "\n=== Testing Appendix B Query ===\n";
$appendixBTable = 'arplappxb_electrician_activities';
$ratingsTable = 'arplappxe_electrician_activity_ratings';

$appendixBSQL = "SELECT 
    act.activity_id,
    act.activity_number,
    act.activity_name,
    act.ofo_number,
    COALESCE(rat.competency_scale_id, NULL) as rating,
    COALESCE(rat.comments, '') as assessor_comments,
    COALESCE(rat.rating_date, NULL) as rating_date,
    COALESCE(rat.facilitator_id, NULL) as assessor_id
FROM $appendixBTable act
LEFT JOIN $ratingsTable rat ON (
    rat.activity_id = act.activity_id 
    AND rat.learnerID = $learnerID
    AND rat.ofo_number = '$ofo_code'
)
ORDER BY act.activity_number ASC";

$st = $conn->query($appendixBSQL);
if ($st) {
    $count = 0;
    $ratedCount = 0;
    while ($row = $st->fetch_assoc()) {
        $count++;
        if (!is_null($row['rating'])) {
            $ratedCount++;
            if ($ratedCount <= 3) {
                echo "Activity $count: {$row['activity_name']} → Rating: {$row['rating']} | Comments: {$row['assessor_comments']}\n";
            }
        }
    }
    echo "\nTotal activities: $count\n";
    echo "Activities with ratings: $ratedCount\n";
    echo "Result: ✅ PASS\n";
} else {
    echo "Query failed: " . $conn->error . "\n";
}
?>
