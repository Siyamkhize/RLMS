<?php
// PDO Database connection file (compatible with current PHP setup)
$servername = "localhost";
$username = "root"; // Replace with your actual database username
$password = ""; // Replace with your actual database password  
$dbname = "rlmss"; // Replace with your actual database name

try {
    // Create PDO connection
    $dsn = "mysql:host=$servername;dbname=$dbname;charset=utf8mb4";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    
    // For backward compatibility, create a mysqli-like wrapper
    $conn = new class($pdo) {
        private $pdo;
        public $connect_error = null;
        
        public function __construct($pdo) {
            $this->pdo = $pdo;
        }
        
        public function query($sql) {
            try {
                $stmt = $this->pdo->query($sql);
                return new class($stmt) {
                    private $stmt;
                    public $num_rows;
                    
                    public function __construct($stmt) {
                        $this->stmt = $stmt;
                        $this->num_rows = $stmt->rowCount();
                    }
                    
                    public function fetch_assoc() {
                        return $this->stmt->fetch(PDO::FETCH_ASSOC);
                    }
                };
            } catch (PDOException $e) {
                throw new Exception($e->getMessage());
            }
        }
        
        public function prepare($sql) {
            try {
                $stmt = $this->pdo->prepare($sql);
                return new class($stmt, $this->pdo) {
                    private $stmt;
                    private $pdo;
                    public $error = null;
                    
                    public function __construct($stmt, $pdo) {
                        $this->stmt = $stmt;
                        $this->pdo = $pdo;
                    }
                    
                    public function bind_param($types, ...$params) {
                        try {
                            for ($i = 0; $i < count($params); $i++) {
                                $this->stmt->bindValue($i + 1, $params[$i]);
                            }
                            return true;
                        } catch (PDOException $e) {
                            $this->error = $e->getMessage();
                            return false;
                        }
                    }
                    
                    public function execute() {
                        try {
                            return $this->stmt->execute();
                        } catch (PDOException $e) {
                            $this->error = $e->getMessage();
                            return false;
                        }
                    }
                    
                    public function get_result() {
                        return new class($this->stmt) {
                            private $stmt;
                            
                            public function __construct($stmt) {
                                $this->stmt = $stmt;
                            }
                            
                            public function fetch_assoc() {
                                return $this->stmt->fetch(PDO::FETCH_ASSOC);
                            }
                        };
                    }
                };
            } catch (PDOException $e) {
                throw new Exception($e->getMessage());
            }
        }
        
        public function real_escape_string($string) {
            // PDO handles escaping automatically with prepared statements
            // This is just for compatibility
            return addslashes($string);
        }
        
        public function set_charset($charset) {
            // Already set in DSN
            return true;
        }
        
        public function close() {
            $this->pdo = null;
        }
        
        public function __get($name) {
            if ($name === 'error') {
                return $this->pdo->errorInfo()[2] ?? null;
            }
            if ($name === 'insert_id') {
                return $this->pdo->lastInsertId();
            }
            return null;
        }
    };
    
} catch (PDOException $e) {
    error_log("Database connection error: " . $e->getMessage());
    // Log to debug file as well
    file_put_contents('debug_work_experience.log', "Database connection failed: " . $e->getMessage() . PHP_EOL, FILE_APPEND);
    throw new Exception("Connection failed: " . $e->getMessage());
}
?>