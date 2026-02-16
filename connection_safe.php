<?php
// Safe database connection with better error handling
$servername = "localhost";
$username = "root"; // Update with your actual username
$password = ""; // Update with your actual password
$dbname = "rlmss";

// Log file for connection errors
$logFile = __DIR__ . '/connection_error.log';

try {
    // Check if mysqli extension is loaded
    if (!extension_loaded('mysqli')) {
        $error = 'mysqli extension is not loaded';
        file_put_contents($logFile, date('Y-m-d H:i:s') . " ERROR: $error\n", FILE_APPEND);
        throw new Exception($error);
    }
    
    // Create connection
    $conn = @new mysqli($servername, $username, $password, $dbname);

    // Check connection
    if ($conn->connect_error) {
        $error = "Connection failed: " . $conn->connect_error;
        file_put_contents($logFile, date('Y-m-d H:i:s') . " ERROR: $error\n", FILE_APPEND);
        throw new Exception($error);
    }

    // Set charset
    if (!$conn->set_charset("utf8")) {
        $error = "Error setting charset: " . $conn->error;
        file_put_contents($logFile, date('Y-m-d H:i:s') . " WARNING: $error\n", FILE_APPEND);
    }
    
    file_put_contents($logFile, date('Y-m-d H:i:s') . " SUCCESS: Connected to database\n", FILE_APPEND);
    
} catch (Exception $e) {
    // Log the error
    file_put_contents($logFile, date('Y-m-d H:i:s') . " EXCEPTION: " . $e->getMessage() . "\n", FILE_APPEND);
    
    // Don't throw - just set conn to null so scripts can handle it
    $conn = null;
    
    // If this is being called directly (for testing), output error
    if (basename($_SERVER['PHP_SELF']) === 'connection_safe.php') {
        header('Content-Type: application/json');
        echo json_encode([
            'success' => false,
            'error' => $e->getMessage(),
            'check_log' => 'connection_error.log'
        ]);
        exit;
    }
}
?>
