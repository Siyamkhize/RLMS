<?php
require 'connection.php';
$result = $conn->query("SHOW TABLES LIKE 'arplappxe%'");
echo "Available Appendix E tables:\n";
while($row = $result->fetch_row()) {
    echo "  - " . $row[0] . "\n";
}
?>
