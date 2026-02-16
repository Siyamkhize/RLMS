<?php
// Database connection using PDO (since mysqli is not available)
// This wraps PDO to work similarly to mysqli for compatibility
$servername = "localhost";
$username = "rlmsrlmsco_ezxcmacd_rlms"; // Online database username
$password = "aV~4RP=_G{Uxm-Mp"; // Online database password  
$dbname = "rlmsrlmsco_ezxcmacd_rlms"; // Online database name

try {
    // Create PDO connection
    $dsn = "mysql:host=$servername;dbname=$dbname;charset=utf8";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false
    ]);
    
    // Create a mysqli-like wrapper object
    $conn = new stdClass();
    $conn->pdo = $pdo;
    $conn->connect_error = null;
    $conn->error = null;
    $conn->insert_id = 0;
    
    // Add mysqli-like methods
    $conn->prepare = function($sql) use ($pdo) {
        try {
            $stmt = $pdo->prepare($sql);
            
            // Create mysqli-like statement wrapper
            $wrapper = new stdClass();
            $wrapper->stmt = $stmt;
            $wrapper->error = null;
            
            $wrapper->bind_param = function($types, ...$params) use ($stmt) {
                for ($i = 0; $i < count($params); $i++) {
                    $stmt->bindValue($i + 1, $params[$i]);
                }
                return true;
            };
            
            $wrapper->execute = function() use ($stmt, $pdo, &$conn) {
                try {
                    $result = $stmt->execute();
                    $conn->insert_id = $pdo->lastInsertId();
                    return $result;
                } catch (PDOException $e) {
                    $this->error = $e->getMessage();
                    return false;
                }
            };
            
            $wrapper->get_result = function() use ($stmt) {
                $result = new stdClass();
                $result->fetch_assoc = function() use ($stmt) {
                    return $stmt->fetch(PDO::FETCH_ASSOC);
                };
                $result->num_rows = $stmt->rowCount();
                return $result;
            };
            
            return $wrapper;
        } catch (PDOException $e) {
            $conn->error = $e->getMessage();
            return false;
        }
    };
    
    $conn->query = function($sql) use ($pdo) {
        try {
            return $pdo->query($sql);
        } catch (PDOException $e) {
            $this->error = $e->getMessage();
            return false;
        }
    };
    
    $conn->real_escape_string = function($string) use ($pdo) {
        return substr($pdo->quote($string), 1, -1);
    };
    
    $conn->set_charset = function($charset) {
        // PDO charset is set in DSN, so this is a no-op
        return true;
    };
    
    $conn->close = function() use ($pdo) {
        $pdo = null;
        return true;
    };
    
    // For compatibility with mysqli_real_escape_string function calls
    function mysqli_real_escape_string($conn, $string) {
        return $conn->real_escape_string($string);
    }
    
    function mysqli_query($conn, $sql) {
        return $conn->query($sql);
    }
    
    function mysqli_num_rows($result) {
        return $result->num_rows ?? 0;
    }
    
    function mysqli_fetch_assoc($result) {
        return $result->fetch_assoc();
    }
    
    function mysqli_insert_id($conn) {
        return $conn->insert_id;
    }
    
    function mysqli_error($conn) {
        return $conn->error;
    }
    
} catch (PDOException $e) {
    error_log("Database connection error: " . $e->getMessage());
    file_put_contents('debug_connection.log', date('Y-m-d H:i:s') . " - Database connection failed: " . $e->getMessage() . PHP_EOL, FILE_APPEND);
    throw new Exception("Connection failed: " . $e->getMessage());
}
?>