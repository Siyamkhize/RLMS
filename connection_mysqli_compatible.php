<?php
// Database connection file - mysqli compatible using PDO
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "rlmss";

try {
    // Create PDO connection but wrap it to work like mysqli
    $pdo = new PDO("mysql:host=$servername;dbname=$dbname;charset=utf8", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create a mysqli-compatible wrapper
    class MySQLiCompatible {
        private $pdo;
        public $connect_error = null;
        public $error = null;
        
        public function __construct($pdo) {
            $this->pdo = $pdo;
        }
        
        public function prepare($sql) {
            try {
                $stmt = $this->pdo->prepare($sql);
                return new MySQLiStmtCompatible($stmt, $this);
            } catch (PDOException $e) {
                $this->error = $e->getMessage();
                return false;
            }
        }
        
        public function query($sql) {
            try {
                return $this->pdo->query($sql);
            } catch (PDOException $e) {
                $this->error = $e->getMessage();
                return false;
            }
        }
        
        public function set_charset($charset) {
            // Already set in PDO constructor
            return true;
        }
        
        public function close() {
            $this->pdo = null;
        }
    }
    
    class MySQLiStmtCompatible {
        private $stmt;
        private $mysqli;
        public $error = null;
        
        public function __construct($stmt, $mysqli) {
            $this->stmt = $stmt;
            $this->mysqli = $mysqli;
        }
        
        public function bind_param($types, ...$params) {
            try {
                for ($i = 0; $i < count($params); $i++) {
                    $this->stmt->bindParam($i + 1, $params[$i]);
                }
                return true;
            } catch (PDOException $e) {
                $this->error = $e->getMessage();
                $this->mysqli->error = $e->getMessage();
                return false;
            }
        }
        
        public function execute() {
            try {
                return $this->stmt->execute();
            } catch (PDOException $e) {
                $this->error = $e->getMessage();
                $this->mysqli->error = $e->getMessage();
                return false;
            }
        }
        
        public function get_result() {
            return new MySQLiResultCompatible($this->stmt);
        }
        
        public function close() {
            $this->stmt = null;
        }
    }
    
    class MySQLiResultCompatible {
        private $stmt;
        
        public function __construct($stmt) {
            $this->stmt = $stmt;
        }
        
        public function fetch_assoc() {
            return $this->stmt->fetch(PDO::FETCH_ASSOC);
        }
        
        public function num_rows() {
            return $this->stmt->rowCount();
        }
    }
    
    // Create the mysqli-compatible connection
    $conn = new MySQLiCompatible($pdo);
    
} catch (PDOException $e) {
    error_log("Database connection error: " . $e->getMessage());
    throw new Exception("Connection failed: " . $e->getMessage());
}
?>