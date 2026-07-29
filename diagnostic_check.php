<?php
include('php/connection.php');

$learnerID = 11559;

// 1. Get Learner's Project ID
$q1 = "SELECT pr.project_id, pr.projectName 
       FROM learnerdetails ld
       LEFT JOIN class c ON ld.classID = c.classID
       LEFT JOIN sites s ON c.siteID = s.siteID
       LEFT JOIN project pr ON s.project_id = pr.project_id
       WHERE ld.LearnerID = $learnerID";
$res1 = $conn->query($q1);
$learnerProject = $res1->fetch_assoc();
$lpID = $learnerProject['project_id'];
echo "Learner Project ID: " . ($lpID ?? 'NULL') . " (" . ($learnerProject['projectName'] ?? 'N/A') . ")\n";

// 2. Check Assessments for US 9964 and their project IDs
echo "\nAssessments for US 9964:\n";
$q2 = "SELECT id, project_id, assessment_type, question_number, exercise 
       FROM assessments 
       WHERE unit_standard_id = 9964";
$res2 = $conn->query($q2);
while($row = $res2->fetch_assoc()) {
    echo "ID: " . $row['id'] . " | Project: " . ($row['project_id'] ?? 'NULL') . " | Type: " . $row['assessment_type'] . " | Q: " . $row['question_number'] . " | Ex: " . $row['exercise'] . "\n";
}

// 3. Check Marks for Learner 11559 for US 9964
echo "\nMarks for Learner 11559 (related to 9964):\n";
$q3 = "SELECT id, exercise, type, marks_scored, so 
       FROM marks 
       WHERE learnerID = $learnerID AND (exercise LIKE '%9964%' OR so LIKE '%9964%')";
$res3 = $conn->query($q3);
while($row = $res3->fetch_assoc()) {
    echo "ID: " . $row['id'] . " | Ex: " . $row['exercise'] . " | Type: " . $row['type'] . " | Marks: " . $row['marks_scored'] . "\n";
}
?>
