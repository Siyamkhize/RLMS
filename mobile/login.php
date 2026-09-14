<?php

require_once __DIR__ . '/../security_functions.php';
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');
// Suppress imagick warnings
error_reporting(E_ALL & ~E_WARNING);
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
session_start();
include('connection.php');

// Function to generate a secure random token
function generateSecureToken($length = 64) {
    return bin2hex(random_bytes($length / 2));
}

// Function to create or update an auth token for a user
function createAuthToken($conn, $user_id, $user_role, $expires_hours = 168) { // 1 week expiry
    $token = generateSecureToken();
    $token_hash = hash('sha256', $token); // Hash the token for storage
    $expires_at = date('Y-m-d H:i:s', time() + ($expires_hours * 3600));
    
    // Delete existing tokens for this user
    $stmt_delete = $conn->prepare("DELETE FROM auth_tokens WHERE user_id = ? AND user_role = ?");
    if ($stmt_delete) {
        $stmt_delete->bind_param("ss", $user_id, $user_role);
        $stmt_delete->execute();
        $stmt_delete->close();
    }
    
    // Insert new token
    $stmt = $conn->prepare("INSERT INTO auth_tokens (user_id, user_role, token_hash, expires_at) VALUES (?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("ssss", $user_id, $user_role, $token_hash, $expires_at);
        $stmt->execute();
        $stmt->close();
    }
    
    return $token; // Return the raw token to the client
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // SECURITY: Apply aggressive rate limiting for login attempts
    // 10 attempts per minute from same IP to prevent brute force attacks
    if (!function_exists('get_client_ip')) {
        require_once __DIR__ . '/security_middleware.php';
    }
    
    $ip = get_client_ip();
    $rate_check = check_rate_limit($conn, $ip, 'login', 10, 60);
    
    if (!$rate_check['allowed']) {
        http_response_code(429);
        echo json_encode([
            'success' => false,
            'message' => $rate_check['message'],
            'retry_after' => $rate_check['retry_after'] ?? null,
            'error_code' => 'RATE_LIMIT_EXCEEDED'
        ]);
        
        log_security_event('login_rate_limit_exceeded', 'Too many login attempts', [
            'ip' => $ip,
            'email' => $_POST['email'] ?? 'unknown'
        ]);
        
        exit;
    }
    
    $email = $_POST['email'];
    $password = $_POST['password'];

    // Check for SDP credentials (email or client_name)
    $stmt = $conn->prepare("SELECT sdp_id, client_name, password FROM sdp WHERE email = ? OR client_name = ?");
    $stmt->bind_param("ss", $email, $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        // Verify hashed password
        if (password_verify($password, $row['password'])) {
            $_SESSION['role'] = 'sdp';
            $_SESSION['sdp_id'] = $row['sdp_id'];
            $_SESSION['client_name'] = $row['client_name'];
            $_SESSION["logged_in"] = true;

            $sdp_id = $row['sdp_id'];
            $sdp_name = $row['client_name'];
            
            // Generate auth token
            $auth_token = createAuthToken($conn, $sdp_id, 'sdp');
            
            // Step 1: Get all projects for this SDP
            $projects_query = "
                SELECT DISTINCT
                    p.project_id,
                    p.Project_name,
                    p.sdp_name,
                    p.client_name,
                    p.Financial_year,
                    p.Start_date,
                    p.End_date,
                    p.Province,
                    p.n_beneficiaries,
                    p.Project_pathway
                FROM project p
                WHERE p.sdp_name = ?
                OR p.project_id IN (
                    SELECT DISTINCT s.project_id 
                    FROM sites s 
                    WHERE s.sdp_id = ?
                )
                ORDER BY p.Project_name
            ";
            
            $stmt_projects = $conn->prepare($projects_query);
            $sdp_id_numeric = is_numeric($sdp_id) ? intval($sdp_id) : 0;
            $stmt_projects->bind_param('si', $sdp_name, $sdp_id_numeric);
            $stmt_projects->execute();
            $result_projects = $stmt_projects->get_result();
            
            $projects = [];
            while ($project_row = $result_projects->fetch_assoc()) {
                $project_id = $project_row['project_id'];
                
                // Step 2: Parse the Project_pathway JSON to get pathways
                $pathways = [];
                $project_pathway_json = $project_row['Project_pathway'];
                
                if (!empty($project_pathway_json)) {
                    $pathway_data = json_decode($project_pathway_json, true);
                    
                    if (is_array($pathway_data)) {
                        foreach ($pathway_data as $pathway_item) {
                            $pathway_id = $pathway_item['id'] ?? '';
                            $pathway_name = $pathway_item['name'] ?? '';
                            $qual_types = $pathway_item['qual_types'] ?? [];
                            $is_internship = $pathway_item['isInternship'] ?? false;
                            
                            if (!empty($pathway_name)) {
                                // Step 3: Get all sites for this pathway
                                $sites_query = "
                                    SELECT 
                                        s.siteID, 
                                        s.siteName, 
                                        s.beneficiaries, 
                                        (SELECT COUNT(classId) FROM class WHERE class.siteId = s.siteID) AS classes, 
                                        s.Project_pathway AS learningPathway, 
                                        IF(s.latitude IS NOT NULL AND s.longitude IS NOT NULL, 
                                            CONCAT(FORMAT(s.latitude, 3), ',', FORMAT(s.longitude, 3)), 
                                            'No Coordinates Available') AS coordinates,
                                        s.Category AS category, 
                                        s.province
                                    FROM sites s
                                    WHERE s.project_id = ? 
                                    AND s.sdp_id = ?
                                    AND TRIM(LOWER(s.Project_pathway)) = TRIM(LOWER(?))
                                    ORDER BY s.siteName
                                ";
                                
                                $stmt_sites = $conn->prepare($sites_query);
                                $stmt_sites->bind_param('sss', $project_id, $sdp_id, $pathway_name);
                                $stmt_sites->execute();
                                $result_sites = $stmt_sites->get_result();
                                
                                $sites = [];
                                while ($site_row = $result_sites->fetch_assoc()) {
                                    $sites[] = array_map('strval', $site_row);
                                }
                                $stmt_sites->close();
                                
                                $pathways[] = [
                                    'pathway_id' => $pathway_id,
                                    'pathway_name' => $pathway_name,
                                    'qual_types' => $qual_types,
                                    'is_internship' => $is_internship,
                                    'sites' => $sites,
                                    'site_count' => count($sites)
                                ];
                            }
                        }
                    }
                }
                
                // Add pathways to project
                $project_row['pathways'] = $pathways;
                $project_row['pathway_count'] = count($pathways);
                
                // Keep the original Project_pathway JSON for reference
                $project_row['Project_pathway_raw'] = $project_pathway_json;
                
                $projects[] = $project_row;
            }
            $stmt_projects->close();

            echo json_encode([
                'success' => true,
                'role' => 'sdp',
                'sdp_id' => $sdp_id,
                'sdp_name' => $sdp_name,
                'projects' => $projects,
                'project_count' => count($projects),
                'auth_token' => $auth_token
            ]);
        } else {
            echo json_encode(['success' => false, 'message' => 'Invalid password for SDP.']);
        }
    } else {
        // Check for client credentials
        $stmt = $conn->prepare("SELECT * FROM client WHERE email = ? OR client_name = ?");
        $stmt->bind_param("ss", $email, $email);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            $row = $result->fetch_assoc();
            $_SESSION['role'] = 'client';
            $_SESSION['client_name'] = $row['client_name'];
            $_SESSION["logged_in"] = true;
            
            // Generate auth token
            $auth_token = createAuthToken($conn, $row['client_name'], 'client');

            echo json_encode([
                'success' => true,
                'role' => 'client',
                'auth_token' => $auth_token
            ]);
        } else {
            // Check for facilitator, assessor, moderator, or ARPL_Assessor credentials (email or first name or last name)
            $stmt = $conn->prepare("SELECT * FROM facilitator WHERE email = ? OR firstName = ? OR lastName = ?");
            $stmt->bind_param("sss", $email, $email, $email);
            $stmt->execute();
            $result = $stmt->get_result();

            if ($result->num_rows > 0) {
                $row = $result->fetch_assoc();
                // Normalize role to lowercase with underscores
                $dbRole = trim(strtolower($row['role']));
                
                // Debug: Log the role detection
                error_log("[LOGIN] Facilitator {$row['facilitator_id']}: DB role = '{$row['role']}', normalized = '$dbRole'");
                
                if (strpos($dbRole, 'arpl') !== false && strpos($dbRole, 'assessor') !== false) {
                    // Matches: arpl_assessor, arpl_Assessor, ARPL_Assessor, etc.
                    $role = 'arpl_assessor';
                    error_log("[LOGIN] Detected ARPL Assessor role");
                } elseif ((strpos($dbRole, 'arpl') !== false && strpos($dbRole, 'moderator') !== false) ||
                          (strpos($dbRole, 'arpl') !== false && strpos($dbRole, 'modarator') !== false)) {
                    // Matches: arpl_moderator, ARPL_Moderator, ARPL_Modarator, arpl_modarator (typo)
                    $role = 'arpl_moderator';
                    error_log("[LOGIN] Detected ARPL Moderator role");
                } elseif ($dbRole === 'assessor') {
                    $role = 'assessor';
                    error_log("[LOGIN] Detected Assessor role");
                } elseif ($dbRole === 'moderator') {
                    $role = 'Moderator';
                    error_log("[LOGIN] Detected Moderator role");
                } else {
                    $role = 'facilitator';
                    error_log("[LOGIN] Defaulting to Facilitator role");
                }

                $_SESSION['role'] = $role;
                $_SESSION['classID'] = $row['classID'];
                $_SESSION['facilitator_id'] = $row['facilitator_id'];
                $_SESSION["logged_in"] = true;
                
                // Generate auth token
                $auth_token = createAuthToken($conn, $row['facilitator_id'], $role);
                
                // Log the final response role
                error_log("[LOGIN] Final response role for facilitator {$row['facilitator_id']}: '$role'");

                if ($role === 'assessor' || $role === 'Moderator' || $role === 'arpl_assessor' || $role === 'arpl_moderator') {
                    $facilitator_id = $row['facilitator_id'];
                    $sql = "
                        SELECT s.project_id, s.Project_pathway, c.* 
                        FROM class c
                        JOIN sites s ON s.siteID = c.siteID
                        JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
                        WHERE f.facilitator_id = ?
                    ";

                    $stmt_classes = $conn->prepare($sql);
                    if ($stmt_classes) {
                        $stmt_classes->bind_param("s", $facilitator_id);
                        $stmt_classes->execute();
                        $result_classes = $stmt_classes->get_result();

                        $classes = [];
                        while ($class_row = $result_classes->fetch_assoc()) {
                            $classes[] = array_map('strval', $class_row);
                        }
                        
                        // Log the response data
                        error_log("[LOGIN] Sending response - Role: '$role', Facilitator: $facilitator_id, Classes count: " . count($classes));
                        if (count($classes) > 0) {
                            error_log("[LOGIN] First class data: " . json_encode($classes[0]));
                        }

                        echo json_encode([
                            'success' => true,
                            'role' => $role,
                            'facilitator_id' => $facilitator_id,
                            'classes' => $classes,
                            'auth_token' => $auth_token
                        ]);
                    } else {
                        error_log("[LOGIN ERROR] Failed to prepare class information query");
                        echo json_encode(['success' => false, 'error' => 'Failed to prepare class information query']);
                    }
                    $stmt_classes->close();
                } else {
                    $classID = $row['classID'];
                    $sql = "
                        SELECT 
                            ld.LearnerID, 
                            ld.Title, 
                            ld.Name, 
                            ld.Surname, 
                            ld.Email, 
                            lc.clock_in_time, 
                            lc.clock_out_time, 
                            lc.contact_time
                        FROM 
                            learnerdetails ld
                        LEFT JOIN 
                            learner_clocking lc 
                            ON ld.LearnerID = lc.LearnerID AND lc.clock_date = CURDATE()
                        WHERE 
                            ld.classID = ?
                    ";

                    $stmt_learners = $conn->prepare($sql);
                    if ($stmt_learners) {
                        $stmt_learners->bind_param("s", $classID);
                        $stmt_learners->execute();
                        $result_learners = $stmt_learners->get_result();

                        $learners = [];
                        while ($learner_row = $result_learners->fetch_assoc()) {
                            $learners[] = array_map('strval', $learner_row);
                        }

                        echo json_encode([
                            'success' => true,
                            'role' => $role,
                            'classID' => $classID,
                            'learners' => $learners,
                            'auth_token' => $auth_token
                        ]);
                    } else {
                        echo json_encode(['success' => false, 'error' => 'Failed to prepare learner information query']);
                    }
                    $stmt_learners->close();
                }
            } else {
                // Check for account_user table (web application users)
                $stmt = $conn->prepare("SELECT * FROM account_user WHERE username = ? OR email = ?");
                $stmt->bind_param("ss", $email, $email);
                $stmt->execute();
                $result = $stmt->get_result();

                if ($result->num_rows > 0) {
                    $row = $result->fetch_assoc();
                    
                    // SECURITY FIX: Only use secure password_verify (bcrypt)
                    // Removed insecure methods: MD5 hash and plain text comparison
                    $password_valid = password_verify($password, $row['password']);
                    
                    if ($password_valid) {
                        // SECURITY: Log successful login
                        log_security_event('login_success', 'Successful account login', [
                            'ip' => $ip,
                            'email' => $email,
                            'account_id' => $row['account_id'] ?? 'unknown',
                            'role' => $row['role'] ?? 'unknown'
                        ]);
                        
                        // Check role based on account_name and role fields
                        $account_name = trim($row['account_name'] ?? '');
                        $role = strtolower(trim($row['role'] ?? 'Account'));
                        
                        // Role detection based on account_name or role field
                        if (strtolower($account_name) === 'finance' || strtolower($role) === 'finance') {
                            $role = 'finance';
                        } elseif (strtolower($account_name) === 'logistics' || strtolower($role) === 'logistics') {
                            $role = 'logistics';
                        } elseif (strtolower($account_name) === 'site admin' || strtolower($role) === 'site admin') {
                            $role = 'Site Admin';
                        } elseif (strtolower($account_name) === 'admin' || strtolower($role) === 'admin') {
                            $role = 'admin';
                        } elseif (strtolower($account_name) === 'tqa' || strtolower($role) === 'tqa') {
                            $role = 'tqa';
                        } elseif (strtolower($account_name) === 'executive' || strtolower($role) === 'executive') {
                            $role = 'Executive';
                        }
                        
                        $_SESSION['role'] = $role;
                        $_SESSION['account_id'] = $row['account_id'];
                        $_SESSION['account_name'] = $row['account_name'];
                        $_SESSION["logged_in"] = true;
                        
                        // Generate auth token
                        $auth_token = createAuthToken($conn, $row['account_id'], $role);

                        // Handle different roles from account_user table
                        if ($role === 'finance') {
                            // Finance role - return minimal data with empty classID to prevent facilitator flow
                            echo json_encode([
                                'success' => true,
                                'role' => 'finance',
                                'facilitator_id' => (string)$row['account_id'],
                                'classID' => '', // Empty classID to prevent facilitator flow
                                'name' => $row['account_name'] ?? '',
                                'email' => $row['email'] ?? $row['username'],
                                'auth_token' => $auth_token
                            ]);
                        } else if ($role === 'logistics') {
                            // Logistics role - return logistics-specific data
                            echo json_encode([
                                'success' => true,
                                'role' => 'logistics',
                                'logistics_id' => (string)$row['account_id'],
                                'account_id' => $row['account_id'],
                                'account_name' => $row['account_name'],
                                'classID' => '', // Empty classID to prevent facilitator flow
                                'name' => $row['account_name'] ?? '',
                                'email' => $row['email'] ?? $row['username'],
                                'auth_token' => $auth_token
                            ]);
                        } else if ($role === 'Site Admin') {
                            // Site Admin role - return site admin-specific data
                            echo json_encode([
                                'success' => true,
                                'role' => 'Site Admin',
                                'facilitator_id' => (string)$row['account_id'],
                                'account_id' => $row['account_id'],
                                'account_name' => $row['account_name'],
                                'classID' => '', // Empty classID to prevent facilitator flow
                                'name' => $row['account_name'] ?? '',
                                'email' => $row['email'] ?? $row['username'],
                                'auth_token' => $auth_token
                            ]);
                        } else if ($role === 'admin') {
                            // Admin role - return admin-specific data
                            echo json_encode([
                                'success' => true,
                                'role' => 'admin',
                                'admin_id' => (string)$row['account_id'],
                                'account_id' => $row['account_id'],
                                'account_name' => $row['account_name'],
                                'classID' => '', // Empty classID to prevent facilitator flow
                                'name' => $row['account_name'] ?? '',
                                'email' => $row['email'] ?? $row['username'],
                                'auth_token' => $auth_token
                            ]);
                        } else if ($role === 'tqa') {
                            // TQA role - return TQA-specific data
                            echo json_encode([
                                'success' => true,
                                'role' => 'tqa',
                                'tqa_id' => (string)$row['account_id'],
                                'account_id' => $row['account_id'],
                                'account_name' => $row['account_name'],
                                'classID' => '', // Empty classID to prevent facilitator flow
                                'name' => $row['account_name'] ?? '',
                                'email' => $row['email'] ?? $row['username'],
                                'auth_token' => $auth_token
                            ]);
                        } else if ($role === 'Executive') {
                            // Executive role - return executive-specific data
                            echo json_encode([
                                'success' => true,
                                'role' => 'Executive',
                                'executive_id' => (string)$row['account_id'],
                                'account_id' => $row['account_id'],
                                'account_name' => $row['account_name'],
                                'classID' => '', // Empty classID to prevent facilitator flow
                                'name' => $row['account_name'] ?? '',
                                'email' => $row['email'] ?? $row['username'],
                                'auth_token' => $auth_token
                            ]);
                        } else {
                            // Other account roles
                            echo json_encode([
                                'success' => true,
                                'role' => $role,
                                'account_id' => $row['account_id'],
                                'account_name' => $row['account_name'],
                                'classID' => '', // Empty classID for non-facilitator roles
                                'email' => $row['email'] ?? $row['username'],
                                'auth_token' => $auth_token
                            ]);
                        }
                    } else {
                        // SECURITY: Log failed login attempt
                        log_security_event('login_failed', 'Invalid password for account user', [
                            'ip' => $ip,
                            'email' => $email,
                            'account_id' => $row['account_id'] ?? 'unknown'
                        ]);
                        echo json_encode(['success' => false, 'message' => 'Invalid password for account user.']);
                    }
                } else {
                    // SECURITY: Log failed login attempt
                    log_security_event('login_failed', 'Invalid credentials - user not found', [
                        'ip' => $ip,
                        'email' => $email
                    ]);
                    echo json_encode(['success' => false, 'message' => 'Invalid credentials.']);
                }
            }
        }
    }
    $stmt->close();
    $conn->close();
}
?>