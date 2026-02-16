<?php
/**
 * Security Helper Functions
 * Provides AES encryption, secure session management, and security utilities
 */

class Security {
    private static $aesKey = null;
    private static $sessionKey = null;
    
    /**
     * Initialize security with encryption keys from environment
     */
    public static function init() {
        self::loadEnv();
        self::$aesKey = getenv('AES_ENCRYPTION_KEY');
        self::$sessionKey = getenv('SESSION_ENCRYPTION_KEY');
        
        if (!self::$aesKey || !self::$sessionKey) {
            error_log('CRITICAL: Encryption keys not configured');
            throw new Exception('Security configuration error');
        }
    }
    
    /**
     * Load environment variables from .env file
     */
    private static function loadEnv() {
        $envFile = __DIR__ . '/../.env';
        if (!file_exists($envFile)) {
            error_log('CRITICAL: .env file not found');
            return;
        }
        
        $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            if (strpos(trim($line), '#') === 0) continue;
            
            list($name, $value) = explode('=', $line, 2);
            $name = trim($name);
            $value = trim($value);
            
            if (!array_key_exists($name, $_SERVER) && !array_key_exists($name, $_ENV)) {
                putenv("$name=$value");
                $_ENV[$name] = $value;
                $_SERVER[$name] = $value;
            }
        }
    }
    
    /**
     * AES-256-CBC Encryption
     * @param string $data Data to encrypt
     * @return string Base64 encoded encrypted data with IV
     */
    public static function encrypt($data) {
        if (empty($data)) return '';
        
        $iv = openssl_random_pseudo_bytes(openssl_cipher_iv_length('aes-256-cbc'));
        $encrypted = openssl_encrypt($data, 'aes-256-cbc', self::$aesKey, 0, $iv);
        
        // Combine IV and encrypted data
        return base64_encode($iv . $encrypted);
    }
    
    /**
     * AES-256-CBC Decryption
     * @param string $data Base64 encoded encrypted data with IV
     * @return string Decrypted data
     */
    public static function decrypt($data) {
        if (empty($data)) return '';
        
        $data = base64_decode($data);
        $ivLength = openssl_cipher_iv_length('aes-256-cbc');
        $iv = substr($data, 0, $ivLength);
        $encrypted = substr($data, $ivLength);
        
        return openssl_decrypt($encrypted, 'aes-256-cbc', self::$aesKey, 0, $iv);
    }
    
    /**
     * Hash password using bcrypt with cost factor 12
     * @param string $password Plain text password
     * @return string Hashed password
     */
    public static function hashPassword($password) {
        return password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
    }
    
    /**
     * Verify password against hash
     * @param string $password Plain text password
     * @param string $hash Stored hash
     * @return bool True if password matches
     */
    public static function verifyPassword($password, $hash) {
        return password_verify($password, $hash);
    }
    
    /**
     * Secure session initialization
     */
    public static function initSession() {
        // Secure session configuration
        ini_set('session.cookie_httponly', 1);
        ini_set('session.cookie_secure', 1); // HTTPS only
        ini_set('session.cookie_samesite', 'Strict');
        ini_set('session.use_strict_mode', 1);
        ini_set('session.gc_maxlifetime', getenv('SESSION_TIMEOUT') ?: 1800);
        
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
        
        // Regenerate session ID on login
        if (!isset($_SESSION['initiated'])) {
            session_regenerate_id(true);
            $_SESSION['initiated'] = true;
            $_SESSION['created_at'] = time();
        }
        
        // Check session timeout
        if (isset($_SESSION['last_activity']) && 
            (time() - $_SESSION['last_activity'] > (getenv('SESSION_TIMEOUT') ?: 1800))) {
            self::destroySession();
            return false;
        }
        
        $_SESSION['last_activity'] = time();
        return true;
    }
    
    /**
     * Destroy session securely
     */
    public static function destroySession() {
        $_SESSION = array();
        
        if (ini_get("session.use_cookies")) {
            $params = session_get_cookie_params();
            setcookie(session_name(), '', time() - 42000,
                $params["path"], $params["domain"],
                $params["secure"], $params["httponly"]
            );
        }
        
        session_destroy();
    }
    
    /**
     * Generate CSRF token
     * @return string CSRF token
     */
    public static function generateCSRFToken() {
        if (!isset($_SESSION['csrf_token'])) {
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        }
        return $_SESSION['csrf_token'];
    }
    
    /**
     * Verify CSRF token
     * @param string $token Token to verify
     * @return bool True if valid
     */
    public static function verifyCSRFToken($token) {
        return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
    }
    
    /**
     * Sanitize input for output (XSS prevention)
     * @param string $data Data to sanitize
     * @return string Sanitized data
     */
    public static function sanitizeOutput($data) {
        return htmlspecialchars($data, ENT_QUOTES, 'UTF-8');
    }
    
    /**
     * Validate and sanitize filename
     * @param string $filename Original filename
     * @return string Safe filename
     */
    public static function sanitizeFilename($filename) {
        $filename = basename($filename);
        $filename = preg_replace('/[^a-zA-Z0-9_\-\.]/', '_', $filename);
        return $filename;
    }
    
    /**
     * Check if request is over HTTPS
     * @return bool True if HTTPS
     */
    public static function isHTTPS() {
        return (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
            || $_SERVER['SERVER_PORT'] == 443
            || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https');
    }
    
    /**
     * Enforce HTTPS
     */
    public static function enforceHTTPS() {
        if (getenv('FORCE_HTTPS') === 'true' && !self::isHTTPS()) {
            header('Location: https://' . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'], true, 301);
            exit;
        }
    }
    
    /**
     * Set security headers
     */
    public static function setSecurityHeaders() {
        // HSTS
        if (self::isHTTPS()) {
            header('Strict-Transport-Security: max-age=' . (getenv('HSTS_MAX_AGE') ?: 31536000) . '; includeSubDomains; preload');
        }
        
        // XSS Protection
        header('X-XSS-Protection: 1; mode=block');
        
        // Prevent MIME sniffing
        header('X-Content-Type-Options: nosniff');
        
        // Clickjacking protection
        header('X-Frame-Options: DENY');
        
        // Content Security Policy
        header("Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:;");
        
        // Referrer Policy
        header('Referrer-Policy: strict-origin-when-cross-origin');
        
        // Permissions Policy
        header('Permissions-Policy: geolocation=(self), microphone=(), camera=()');
    }
    
    /**
     * Rate limiting check
     * @param string $identifier User identifier (IP, user ID, etc.)
     * @param int $limit Maximum requests
     * @param int $window Time window in seconds
     * @return bool True if within limit
     */
    public static function checkRateLimit($identifier, $limit = null, $window = null) {
        $limit = $limit ?: (int)getenv('API_RATE_LIMIT') ?: 100;
        $window = $window ?: (int)getenv('API_RATE_WINDOW') ?: 60;
        
        $key = 'rate_limit_' . md5($identifier);
        $file = sys_get_temp_dir() . '/' . $key;
        
        $data = file_exists($file) ? json_decode(file_get_contents($file), true) : ['count' => 0, 'start' => time()];
        
        // Reset if window expired
        if (time() - $data['start'] > $window) {
            $data = ['count' => 0, 'start' => time()];
        }
        
        $data['count']++;
        file_put_contents($file, json_encode($data));
        
        return $data['count'] <= $limit;
    }
    
    /**
     * Log security event
     * @param string $event Event description
     * @param array $context Additional context
     */
    public static function logSecurityEvent($event, $context = []) {
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'event' => $event,
            'ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown',
            'context' => $context
        ];
        
        error_log('SECURITY: ' . json_encode($logEntry));
    }
}

// Initialize security on include
try {
    Security::init();
} catch (Exception $e) {
    error_log('Security initialization failed: ' . $e->getMessage());
    if (getenv('ENVIRONMENT') === 'production') {
        http_response_code(500);
        die('System configuration error');
    }
}
?>
