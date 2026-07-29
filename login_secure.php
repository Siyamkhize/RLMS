<?php
/**
 * Secure Login System
 * - Bcrypt password hashing only
 * - Rate limiting
 * - Session security
 * - CSRF protection
 * - Audit logging
 */

require_once 'includes/security.php';
require_once 'includes/db_secure.php';

// Enforce HTTPS
Security::enforceHTTPS();

// Set security headers
Security::setSecurityHeaders();

// CORS headers (restrict in production)
header("Access-Control-Allow-Origin: " . (getenv('ALLOWED_ORIGIN') ?: '*'));
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

// Handle preflight
if ($_SERVER["REQUEST_METHOD"] == "OPTIONS") {
    http_response_code(200);
    exit;
}

// Only allow POST
if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    // Rate limiting
    $clientIP = $_SERVER['REMOTE_ADDR'];
    if (!Security::checkRateLimit($clientIP, 10, 300)) { // 10 attempts per 5 minutes
        Security::logSecurityEvent('Rate limit exceeded', ['ip' => $clientIP]);
        http_response_code(429);
        echo json_encode(['success' => false, 'message' => 'Too many login attempts. Please try again later.']);
        exit;
    }
    
    // Get input
    $email = $_POST['email'] ?? '';
    $password = $_POST['password'] ?? '';
    
    // Validate input
    if (empty($email) || empty($password)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Email and password are required']);
        exit;
    }
    
    // Don't strictly validate email format - allow usernames as well
    
    $db = Database::getInstance();
    
    // Try SDP login
    $result = attemptSDPLogin($db, $email, $password);
    if ($result) {
        echo json_encode($result);
        exit;
    }
    
    // Try Facilitator/Assessor login
    $result = attemptFacilitatorLogin($db, $email, $password);
    if ($result) {
        echo json_encode($result);
        exit;
    }
    
    // Try Account User login
    $result = attemptAccountUserLogin($db, $email, $password);
    if ($result) {
        echo json_encode($result);
        exit;
    }
    
    // No valid credentials found
    Security::logSecurityEvent('Failed login attempt', [
        'email' => $email,
        'ip' => $clientIP
    ]);
    
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Invalid credentials']);
    
} catch (Exception $e) {
    error_log('Login error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Server error']);
}

/**
 * Attempt SDP login
 */
function attemptSDPLogin($db, $email, $password) {
    $query = "SELECT sdp_id, client_name, password FROM sdp WHERE email = ? OR client_name = ?";
    $results = $db->select($query, 'ss', [$email, $email]);
    
    if (empty($results)) {
        return null;
    }
    
    $row = $results[0];
    
    // ONLY accept bcrypt passwords
    if (!Security::verifyPassword($password, $row['password'])) {
        return null;
    }
    
    // Initialize secure session
    Security::initSession();
    
    $_SESSION['role'] = 'sdp';
    $_SESSION['sdp_id'] = $row['sdp_id'];
    $_SESSION['client_name'] = $row['client_name'];
    $_SESSION["logged_in"] = true;
    
    Security::logSecurityEvent('Successful SDP login', [
        'sdp_id' => $row['sdp_id'],
        'email' => $email
    ]);
    
    // Get sites
    $sitesQuery = "SELECT 
        siteID, siteName, beneficiaries,
        (SELECT COUNT(classId) FROM class WHERE class.siteId = sites.siteId) AS classes,
        Project_pathway AS learningPathway,
        IF(latitude IS NOT NULL AND longitude IS NOT NULL, 
            CONCAT(FORMAT(latitude, 3), ',', FORMAT(longitude, 3)), 
            'No Coordinates Available') AS coordinates,
        Category AS category, province
    FROM sites 
    WHERE sdp_id = ?";
    
    $sites = $db->select($sitesQuery, 's', [$row['sdp_id']]);
    
    return [
        'success' => true,
        'role' => 'sdp',
        'sdp_id' => $row['sdp_id'],
        'data' => $sites,
        'csrf_token' => Security::generateCSRFToken()
    ];
}

/**
 * Attempt Facilitator/Assessor login
 */
function attemptFacilitatorLogin($db, $email, $password) {
    $query = "SELECT facilitator_id, role, classID, password FROM facilitator WHERE email = ? OR firstName = ? OR lastName = ?";
    $results = $db->select($query, 'sss', [$email, $email, $email]);
    
    if (empty($results)) {
        return null;
    }
    
    $row = $results[0];
    
    // ONLY accept bcrypt passwords
    if (!Security::verifyPassword($password, $row['password'])) {
        return null;
    }
    
    // Initialize secure session
    Security::initSession();
    
    $role = ($row['role'] === 'Assessor') ? 'assessor' : 
            (($row['role'] === 'Moderator') ? 'Moderator' : 'facilitator');
    
    $_SESSION['role'] = $role;
    $_SESSION['classID'] = $row['classID'];
    $_SESSION['facilitator_id'] = $row['facilitator_id'];
    $_SESSION["logged_in"] = true;
    
    Security::logSecurityEvent('Successful facilitator login', [
        'facilitator_id' => $row['facilitator_id'],
        'role' => $role,
        'email' => $email
    ]);
    
    if ($role === 'assessor' || $role === 'Moderator') {
        // Get classes
        $classesQuery = "
            SELECT s.project_id, c.* 
            FROM class c
            JOIN sites s ON s.siteID = c.siteID
            JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
            WHERE f.facilitator_id = ?
        ";
        $classes = $db->select($classesQuery, 's', [$row['facilitator_id']]);
        
        return [
            'success' => true,
            'role' => $role,
            'facilitator_id' => $row['facilitator_id'],
            'classes' => $classes,
            'csrf_token' => Security::generateCSRFToken()
        ];
    } else {
        // Get learners
        $learnersQuery = "
            SELECT 
                ld.LearnerID, ld.Title, ld.Name, ld.Surname, ld.Email,
                lc.clock_in_time, lc.clock_out_time, lc.contact_time
            FROM learnerdetails ld
            LEFT JOIN learner_clocking lc 
                ON ld.LearnerID = lc.LearnerID AND lc.clock_date = CURDATE()
            WHERE ld.classID = ?
        ";
        $learners = $db->select($learnersQuery, 's', [$row['classID']]);
        
        return [
            'success' => true,
            'role' => $role,
            'classID' => $row['classID'],
            'learners' => $learners,
            'csrf_token' => Security::generateCSRFToken()
        ];
    }
}

/**
 * Attempt Account User login
 */
function attemptAccountUserLogin($db, $email, $password) {
    $query = "SELECT account_id, username, email, role, account_name, password 
              FROM account_user 
              WHERE username = ? OR email = ?";
    $results = $db->select($query, 'ss', [$email, $email]);
    
    if (empty($results)) {
        return null;
    }
    
    $row = $results[0];
    
    // ONLY accept bcrypt passwords
    if (!Security::verifyPassword($password, $row['password'])) {
        return null;
    }
    
    // Initialize secure session
    Security::initSession();
    
    $account_name = trim($row['account_name'] ?? '');
    $role = strtolower(trim($row['role'] ?? 'Account'));
    
    // Check if finance user
    if (strtolower($account_name) === 'finance') {
        $role = 'finance';
    }
    
    $_SESSION['role'] = $role;
    $_SESSION['account_id'] = $row['account_id'];
    $_SESSION['account_name'] = $row['account_name'];
    $_SESSION["logged_in"] = true;
    
    Security::logSecurityEvent('Successful account user login', [
        'account_id' => $row['account_id'],
        'role' => $role,
        'email' => $email
    ]);
    
    return [
        'success' => true,
        'role' => $role,
        'account_id' => $row['account_id'],
        'account_name' => $row['account_name'],
        'classID' => '',
        'email' => $row['email'] ?? $row['username'],
        'csrf_token' => Security::generateCSRFToken()
    ];
}
?>
