<?php
// Online server database connection file
// This connects to the actual online database server instead of localhost

$servername = "localhost";
$username = "rlmsrlmsco_ezxcmacd_rlms"; // Actual online database username
$password = "aV~4RP=_G{Uxm-Mp"; // Actual online database password  
$dbname = "rlmsrlmsco_ezxcmacd_rlms"; // Actual online database name

try {
    // Create connection
    $conn = new mysqli($servername, $username, $password, $dbname);

    // Check connection
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }

    // Set charset to UTF-8
    $conn->set_charset("utf8");
    
    // Log successful connection for debugging
    error_log("Online database connection successful to: $dbname");
    
} catch (Exception $e) {
    error_log("Online database connection error: " . $e->getMessage());
    // Log to debug file as well
    file_put_contents('online_connection_debug.log', date('Y-m-d H:i:s') . " - Database connection failed: " . $e->getMessage() . PHP_EOL, FILE_APPEND);
    throw $e;
}
?>