<?php
// PDO-based database connection (alternative to mysqli)
$servername = "localhost";
$username = "root"; // Replace with your actual database username
$password = ""; // Replace with your actual database password  
$dbname = "rlmss"; // Replace with your actual database name

try {
    // Create PDO connection
    $dsn = "mysql:host=$servername;dbname=$dbname;charset=utf8";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    
    // For compatibility with mysqli code, create a wrapper
    $conn = new class($pdo) {
        private $pdo;
        public $connect_error = null;
        
        public function __construct($pdo) {
            $this->pdo = $pdo;
        }
        
        public function prepare($sql) {
            try {
                return new class($this->pdo->prepare($sql)) {
                    private $stmt;
                    private $pdo_stmt;
                    
                    public function __construct($pdo_stmt) {
                        $this->pdo_stmt = $pdo_stmt;
                    }
                    
                    public function bind_param($types, ...$params) {
                        // Convert mysqli bind_param to PDO bindValue
                        for ($i = 0; $i < count($params); $i++) {
                            $this->pdo_stmt->bindValue($i + 1, $params[$i]);
                        }
                        return true;
                    }
                    
                    public function execute() {
                        try {
                            return $this->pdo_stmt->execute();
                        } catch (PDOException $e) {
                            $this->error = $e->getMessage();
                            return false;
                        }
                    }
                    
                    public function get_result() {
                        return new class($this->pdo_stmt) {
                            private $pdo_stmt;
                            public $num_rows;
                            
                            public function __construct($pdo_stmt) {
                                $this->pdo_stmt = $pdo_stmt;
                                $this->num_rows = $pdo_stmt->rowCount();
                            }
                            
                            public function fetch_assoc() {
                                return $this->pdo_stmt->fetch(PDO::FETCH_ASSOC);
                            }
                        };
                    }
                    
                    public function close() {
                        $this->pdo_stmt = null;
                        return true;
                    }
                    
                    public $error = '';
                    public $affected_rows = 0;
                };
            } catch (PDOException $e) {
                $this->error = $e->getMessage();
                return false;
            }
        }
        
        public function query($sql) {
            try {
                $result = $this->pdo->query($sql);
                return new class($result) {
                    private $result;
                    
                    public function __construct($result) {
                        $this->result = $result;
                    }
                    
                    public function fetch_assoc() {
                        return $this->result->fetch(PDO::FETCH_ASSOC);
                    }
                };
            } catch (PDOException $e) {
                $this->error = $e->getMessage();
                return false;
            }
        }
        
        public function close() {
            $this->pdo = null;
            return true;
        }
        
        public function set_charset($charset) {
            // PDO handles charset in DSN
            return true;
        }
        
        public $insert_id;
        public $error = '';
        
        public function __get($name) {
            if ($name === 'insert_id') {
                return $this->pdo->lastInsertId();
            }
            return null;
        }
    };
    
} catch (PDOException $e) {
    error_log("Database connection error: " . $e->getMessage());
    file_put_contents('debug_clockin.log', "Database connection failed: " . $e->getMessage() . PHP_EOL, FILE_APPEND);
    throw new Exception("Connection failed: " . $e->getMessage());
}
?>