<?php
include('mobile/connection.php');
$res = $conn->query("SELECT DISTINCT unit_standard_id FROM assessments");
while($row = $res->fetch_assoc()) {
    echo "[" . $row['unit_standard_id'] . "]\n";
}
?>