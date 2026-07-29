<?php
require_once 'connection.php';

// Revert back to 641201
$result = $conn->query("UPDATE arplappxe_bricklaying_activities SET ofo_number = '641201' WHERE ofo_number = '671103'");
echo "Reverted " . $conn->affected_rows . " rows back to ofo_number 641201\n";

// Verify
$check = $conn->query("SELECT COUNT(*) as cnt FROM arplappxe_bricklaying_activities WHERE ofo_number = '641201'");
$row = $check->fetch_assoc();
echo "Rows with ofo_number 641201: " . $row['cnt'] . "\n";

$conn->close();
?>
