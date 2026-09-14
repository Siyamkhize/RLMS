<?php
/**
 * Authentication Middleware for Mobile API Endpoints
 * 
 * This file MUST be included at the top of every mobile API endpoint
 * to ensure only authenticated users can access the API.
 * 
 * Usage:
 * require_once 'require_auth.php';
 * $user = requireAuth($conn);
 */

if (!defined('SECURITY_FUNCTIONS_LOADED')) {
    require_once __DIR__ . '/security_middleware.php';
}

/**
 * Require authentication for API endpoint
 * 
 * @param mysqli $conn Database connection
 * @param string|null $required_role Required user role (optional)
 * @return array User data if authenticated
 * @throws Exception if authentication fails
 */
function requireAuth($conn, $required_role = null) {
    // Get all headers (case-insensitive)
    $headers = array_change_key_case(getallheaders(), CASE_LOWER);
    
    // Check for Authorization header
    $authHeader = $headers['authorization'] ?? '';
    
    if (empty($authHeader)) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Authorization required',
            'error_code' => 'MISSING_AUTH_HEADER'
        ]);
        log_security_event('unauthorized_access', 'No authorization header', [
            'ip' => get_client_ip(),
            'endpoint' => $_SERVER['PHP_SELF'] ?? 'unknown',
            'method' => $_SERVER['REQUEST_METHOD'] ?? 'unknown'
        ]);
        exit;
    }
    
    // Extract token from "Bearer <token>" format
    $token = null;
    if (preg_match('/Bearer\s+(.+)/i', $authHeader, $matches)) {
        $token = trim($matches[1]);
    } else {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Invalid authorization format. Use: Bearer <token>',
            'error_code' => 'INVALID_AUTH_FORMAT'
        ]);
        log_security_event('invalid_auth_format', 'Authorization header format invalid', [
            'ip' => get_client_ip(),
            'header' => substr($authHeader, 0, 50)  // Log only first 50 chars
        ]);
        exit;
    }
    
    // Validate token
    $user = validate_auth_token($conn, $token, $required_role);
    
    if (!$user) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Invalid or expired token',
            'error_code' => 'INVALID_TOKEN'
        ]);
        log_security_event('invalid_token', 'Token validation failed', [
            'ip' => get_client_ip(),
            'token_preview' => substr($token, 0, 10) . '...'  // Log only first 10 chars
        ]);
        exit;
    }
    
    // Check role if specified
    if ($required_role !== null && $user['user_role'] !== $required_role) {
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => 'Insufficient permissions',
            'error_code' => 'FORBIDDEN'
        ]);
        log_security_event('insufficient_permissions', 'User role mismatch', [
            'ip' => get_client_ip(),
            'required_role' => $required_role,
            'user_role' => $user['user_role'],
            'user_id' => $user['user_id']
        ]);
        exit;
    }
    
    // Log successful authentication
    log_security_event('authenticated_access', 'Successful authentication', [
        'user_id' => $user['user_id'],
        'user_role' => $user['user_role'],
        'endpoint' => $_SERVER['PHP_SELF'] ?? 'unknown'
    ]);
    
    return $user;
}

/**
 * Apply rate limiting to API endpoint
 * 
 * @param mysqli $conn Database connection
 * @param string $action Action name for rate limiting
 */
function applyRateLimit($conn, $action = 'api_request') {
    $ip = get_client_ip();
    $rate_check = check_rate_limit($conn, $ip, $action);
    
    if (!$rate_check['allowed']) {
        http_response_code(429);
        echo json_encode([
            'success' => false,
            'message' => $rate_check['message'],
            'retry_after' => $rate_check['retry_after'] ?? null,
            'error_code' => 'RATE_LIMIT_EXCEEDED'
        ]);
        
        log_security_event('rate_limit_exceeded', 'Too many requests', [
            'ip' => $ip,
            'action' => $action,
            'endpoint' => $_SERVER['PHP_SELF'] ?? 'unknown'
        ]);
        
        exit;
    }
}

/**
 * Validate required POST parameters
 * 
 * @param array $required Array of required parameter names
 * @param array $input Input data array
 * @return array Validated input or exits with error
 */
function validateRequired($required, $input) {
    $missing = [];
    
    foreach ($required as $field) {
        if (!isset($input[$field]) || (is_string($input[$field]) && trim($input[$field]) === '')) {
            $missing[] = $field;
        }
    }
    
    if (!empty($missing)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Missing required fields: ' . implode(', ', $missing),
            'missing_fields' => $missing,
            'error_code' => 'MISSING_REQUIRED_FIELDS'
        ]);
        exit;
    }
    
    return $input;
}

/**
 * Send success response
 * 
 * @param array $data Response data
 * @param string $message Success message
 */
function sendSuccess($data = [], $message = 'Success') {
    $response = [
        'success' => true,
        'message' => $message
    ];
    
    if (!empty($data)) {
        $response = array_merge($response, $data);
    }
    
    header('Content-Type: application/json');
    echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

/**
 * Send error response
 * 
 * @param string $message Error message
 * @param int $code HTTP status code
 * @param string $error_code Application error code
 */
function sendError($message, $code = 400, $error_code = 'ERROR') {
    http_response_code($code);
    echo json_encode([
        'success' => false,
        'message' => $message,
        'error_code' => $error_code
    ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

// Disable error display in production
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);

// Handle CORS preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    header('Access-Control-Max-Age: 86400');
    http_response_code(200);
    exit;
}

?>
