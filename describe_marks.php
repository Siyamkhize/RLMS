<?php
include('php/connection.php');
$res = $conn->query('DESCRIBE marks');
while($row = $res->fetch_assoc()) {
    print_r($row);
}
?>
