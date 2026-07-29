<?php
require_once 'connection.php';

// Check if we can find a class for electrician learner 20286
$result = $conn->query("SELECT classID FROM learnerdetails WHERE LearnerID = 20286 LIMIT 1");
if ($row = $result->fetch_assoc()) {
    echo 'Learner 20286 classID: ' . $row['classID'] . PHP_EOL;
} else {
    echo 'Learner 20286 not found in learnerdetails' . PHP_EOL;
}
