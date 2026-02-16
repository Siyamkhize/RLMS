<?php
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

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'];
    $password = $_POST['password'];

    // Check for SDP credentials
    $stmt = $conn->prepare("SELECT sdp_id, client_name, password FROM sdp WHERE email = ?");
    $stmt->bind_param("s", $email);
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
            $sql = "SELECT 
                    siteID as 'siteID', siteName AS 'siteName', 
                    beneficiaries AS 'beneficiaries', 
                    (SELECT COUNT(classId) FROM class WHERE class.siteId = sites.siteId) AS 'classes', 
                    Project_pathway AS 'learningPathway', 
                    IF(latitude IS NOT NULL AND longitude IS NOT NULL, 
                        CONCAT(FORMAT(latitude, 3), ',', FORMAT(longitude, 3)), 
                        'No Coordinates Available') AS 'coordinates',
                    Category AS 'category', 
                    province AS 'province'
                FROM 
                    sites 
                WHERE 
                    sdp_id = ?";

            $stmt_sites = $conn->prepare($sql);
            if ($stmt_sites) {
                $stmt_sites->bind_param("s", $sdp_id);
                $stmt_sites->execute();
                $result_sites = $stmt_sites->get_result();

                $data = [];
                while ($site_row = $result_sites->fetch_assoc()) {
                    $data[] = array_map('strval', $site_row);
                }

                echo json_encode([
                    'success' => true,
                    'role' => 'sdp',
                    'sdp_id' => $sdp_id,
                    'data' => $data,
                ]);
            } else {
                echo json_encode(['success' => false, 'error' => 'Failed to prepare site information query']);
            }
            $stmt_sites->close();
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

            echo json_encode([
                'success' => true,
                'role' => 'client',
            ]);
        } else {
            // Check for facilitator, assessor, or moderator credentials
            $stmt = $conn->prepare("SELECT * FROM facilitator WHERE email = ?");
            $stmt->bind_param("s", $email);
            $stmt->execute();
            $result = $stmt->get_result();

            if ($result->num_rows > 0) {
                $row = $result->fetch_assoc();
                $role = ($row['role'] === 'Assessor') ? 'assessor' : (($row['role'] === 'Moderator') ? 'Moderator' : 'facilitator');

                $_SESSION['role'] = $role;
                $_SESSION['classID'] = $row['classID'];
                $_SESSION['facilitator_id'] = $row['facilitator_id'];
                $_SESSION["logged_in"] = true;

                if ($role === 'assessor' || $role === 'Moderator') {
                    $facilitator_id = $row['facilitator_id'];
                    $sql = "
                        SELECT s.project_id, c.* 
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

                        echo json_encode([
                            'success' => true,
                            'role' => $role,
                            'facilitator_id' => $facilitator_id,
                            'classes' => $classes
                        ]);
                    } else {
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
                            'learners' => $learners
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
                    
                    // Try multiple password verification methods
                    $password_valid = false;
                    
                    // Method 1: MD5 hash
                    $hashedPassword = md5($password);
                    if ($row['password'] === $hashedPassword) {
                        $password_valid = true;
                    }
                    
                    // Method 2: Bcrypt (password_verify)
                    if (!$password_valid && password_verify($password, $row['password'])) {
                        $password_valid = true;
                    }
                    
                    // Method 3: Plain text (not recommended but checking)
                    if (!$password_valid && $row['password'] === $password) {
                        $password_valid = true;
                    }
                    
                    if ($password_valid) {
                        // Check role based on account_name and role fields
                        $account_name = trim($row['account_name'] ?? '');
                        $role = strtolower(trim($row['role'] ?? 'Account'));
                        
                        // Role detection based on account_name or role field
                        if (strtolower($account_name) === 'finance' || strtolower($role) === 'finance') {
                            $role = 'finance';
                        } elseif (strtolower($account_name) === 'logistics' || strtolower($role) === 'logistics') {
                            $role = 'logistics';
                        } elseif (strtolower($account_name) === 'admin' || strtolower($role) === 'admin') {
                            $role = 'admin';
                        } elseif (strtolower($account_name) === 'tqa' || strtolower($role) === 'tqa') {
                            $role = 'tqa';
                        }
                        
                        $_SESSION['role'] = $role;
                        $_SESSION['account_id'] = $row['account_id'];
                        $_SESSION['account_name'] = $row['account_name'];
                        $_SESSION["logged_in"] = true;

                        // Handle different roles from account_user table
                        if ($role === 'finance') {
                            // Finance role - return minimal data with empty classID to prevent facilitator flow
                            echo json_encode([
                                'success' => true,
                                'role' => 'finance',
                                'facilitator_id' => (string)$row['account_id'],
                                'classID' => '', // Empty classID to prevent facilitator flow
                                'name' => $row['account_name'] ?? '',
                                'email' => $row['email'] ?? $row['username']
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
                                'email' => $row['email'] ?? $row['username']
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
                                'email' => $row['email'] ?? $row['username']
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
                                'email' => $row['email'] ?? $row['username']
                            ]);
                        } else {
                            // Other account roles
                            echo json_encode([
                                'success' => true,
                                'role' => $role,
                                'account_id' => $row['account_id'],
                                'account_name' => $row['account_name'],
                                'classID' => '', // Empty classID for non-facilitator roles
                                'email' => $row['email'] ?? $row['username']
                            ]);
                        }
                    } else {
                        echo json_encode(['success' => false, 'message' => 'Invalid password for account user.']);
                    }
                } else {
                    echo json_encode(['success' => false, 'message' => 'Invalid credentials.']);
                }
            }
        }
    }
    $stmt->close();
    $conn->close();
}
?>