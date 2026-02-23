<?php
/**
 * Security Functions
 * 
 * Basic security utilities for API endpoints
 */

// Start session if not already started
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

/**
 * Sanitize input string
 */
function sanitize_input($data) {
    if (is_array($data)) {
        return array_map('sanitize_input', $data);
    }
    $data = trim($data);
    $data = stripslashes($data);
    $data = htmlspecialchars($data, ENT_QUOTES, 'UTF-8');
    return $data;
}

/**
 * Validate integer ID
 */
function validate_id($id) {
    return filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
}

/**
 * Check if user is authenticated (optional - can be customized)
 */
function is_authenticated() {
    // For now, return true - customize based on your auth system
    return true;
}

/**
 * Log security events (optional)
 */
function log_security_event($event, $details = '') {
    // Implement logging if needed
    error_log("Security Event: $event - $details");
}
