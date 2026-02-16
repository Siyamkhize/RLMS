<?php
/**
 * Secure Database Connection
 * Uses environment variables and prepared statements
 */

require_once __DIR__ . '/security.php';

class Database {
    private static $instance = null;
    private $conn;
    
    private function __construct() {
        try {
            $host = getenv('DB_HOST') ?: 'localhost';
            $username = getenv('DB_USERNAME');
            $password = getenv('DB_PASSWORD');
            $dbname = getenv('DB_NAME');
            
            if (!$username || !$dbname) {
                throw new Exception('Database credentials not configured');
            }
            
            // Create connection with SSL if available
            $this->conn = new mysqli($host, $username, $password, $dbname);
            
            if ($this->conn->connect_error) {
                Security::logSecurityEvent('Database connection failed', [
                    'error' => $this->conn->connect_error
                ]);
                throw new Exception('Database connection failed');
            }
            
            // Set charset to UTF-8
            $this->conn->set_charset("utf8mb4");
            
            // Set SQL mode for security
            $this->conn->query("SET SESSION sql_mode = 'STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE'");
            
        } catch (Exception $e) {
            error_log('Database error: ' . $e->getMessage());
            throw $e;
        }
    }
    
    /**
     * Get database instance (Singleton)
     * @return Database
     */
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /**
     * Get mysqli connection
     * @return mysqli
     */
    public function getConnection() {
        return $this->conn;
    }
    
    /**
     * Prepare statement safely
     * @param string $query SQL query with placeholders
     * @return mysqli_stmt
     */
    public function prepare($query) {
        $stmt = $this->conn->prepare($query);
        if (!$stmt) {
            Security::logSecurityEvent('SQL prepare failed', [
                'error' => $this->conn->error,
                'query' => $query
            ]);
            throw new Exception('Database query error');
        }
        return $stmt;
    }
    
    /**
     * Execute prepared statement with parameters
     * @param string $query SQL query
     * @param string $types Parameter types (s=string, i=int, d=double, b=blob)
     * @param array $params Parameters
     * @return mysqli_result|bool
     */
    public function execute($query, $types, $params) {
        $stmt = $this->prepare($query);
        
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        
        if (!$stmt->execute()) {
            Security::logSecurityEvent('SQL execution failed', [
                'error' => $stmt->error
            ]);
            throw new Exception('Database execution error');
        }
        
        $result = $stmt->get_result();
        $stmt->close();
        
        return $result;
    }
    
    /**
     * Execute SELECT query safely
     * @param string $query SQL query
     * @param string $types Parameter types
     * @param array $params Parameters
     * @return array Results
     */
    public function select($query, $types = '', $params = []) {
        $result = $this->execute($query, $types, $params);
        
        if ($result === false) {
            return [];
        }
        
        $rows = [];
        while ($row = $result->fetch_assoc()) {
            $rows[] = $row;
        }
        
        return $rows;
    }
    
    /**
     * Execute INSERT query safely
     * @param string $query SQL query
     * @param string $types Parameter types
     * @param array $params Parameters
     * @return int Insert ID
     */
    public function insert($query, $types, $params) {
        $this->execute($query, $types, $params);
        return $this->conn->insert_id;
    }
    
    /**
     * Execute UPDATE query safely
     * @param string $query SQL query
     * @param string $types Parameter types
     * @param array $params Parameters
     * @return int Affected rows
     */
    public function update($query, $types, $params) {
        $this->execute($query, $types, $params);
        return $this->conn->affected_rows;
    }
    
    /**
     * Execute DELETE query safely
     * @param string $query SQL query
     * @param string $types Parameter types
     * @param array $params Parameters
     * @return int Affected rows
     */
    public function delete($query, $types, $params) {
        $this->execute($query, $types, $params);
        return $this->conn->affected_rows;
    }
    
    /**
     * Begin transaction
     */
    public function beginTransaction() {
        $this->conn->begin_transaction();
    }
    
    /**
     * Commit transaction
     */
    public function commit() {
        $this->conn->commit();
    }
    
    /**
     * Rollback transaction
     */
    public function rollback() {
        $this->conn->rollback();
    }
    
    /**
     * Close connection
     */
    public function close() {
        if ($this->conn) {
            $this->conn->close();
        }
    }
    
    /**
     * Prevent cloning
     */
    private function __clone() {}
    
    /**
     * Prevent unserialization
     */
    public function __wakeup() {
        throw new Exception("Cannot unserialize singleton");
    }
}

// Helper function for backward compatibility
function getSecureConnection() {
    return Database::getInstance()->getConnection();
}
?>
