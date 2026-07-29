<?php
ob_start(); // Start output buffering to catch any stray output
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

// Suppress all output except JSON
error_reporting(0);
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);

// Use default file-based sessions
session_start();

include('connection.php');

// Helper: detect if a stored password looks like a hash
function is_password_hash($stored) {
    if (!is_string($stored) || $stored === '') return false;
    return (
        strpos($stored, '$2y$') === 0 ||
        strpos($stored, '$2a$') === 0 ||
        strpos($stored, '$2b$') === 0 ||
        strpos($stored, '$argon2i$') === 0 ||
        strpos($stored, '$argon2id$') === 0
    );
}

// Helper: verify password against either hashed or legacy plaintext
function verify_password_either($input, $stored) {
    $input = (string)($input ?? '');
    $stored = (string)($stored ?? '');
    $input = trim($input);
    $stored = trim($stored);

    if ($stored === '') {
        return false;
    }

    // If it's a modern password_hash format
    if (is_password_hash($stored)) {
        return password_verify($input, $stored);
    }

    // Legacy MD5 (32 hex) or SHA1 (40 hex) support
    $hex32 = preg_match('/^[a-f0-9]{32}$/i', $stored) === 1;
    $hex40 = preg_match('/^[a-f0-9]{40}$/i', $stored) === 1;
    if ($hex32) {
        return hash_equals(strtolower($stored), md5($input));
    }
    if ($hex40) {
        return hash_equals(strtolower($stored), sha1($input));
    }

    // Plaintext fallback
    return hash_equals($stored, $input);
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    try {
        // Validate input
        $email = trim($_POST['email'] ?? '');
        $password = trim($_POST['password'] ?? '');
        if (empty($email) || empty($password)) {
            echo json_encode(['success' => false, 'message' => 'Email and password are required']);
            exit;
        }

        // Check account_user credentials first
        $stmt_account = $conn->prepare("SELECT account_id, account_name, sdp_id, role, password FROM account_user WHERE TRIM(LOWER(email)) = LOWER(?)");
        $stmt_account->bind_param("s", $email);
        $stmt_account->execute();
        $result_account = $stmt_account->get_result();

        if ($result_account->num_rows > 0) {
            $row = $result_account->fetch_assoc();
            error_log("LOGIN: account_user hit for $email");

            if (verify_password_either($password, $row['password'])) {
                $_SESSION['role'] = $row['role'];
                $_SESSION['account_id'] = $row['account_id'];
                $_SESSION['account_name'] = $row['account_name'];
                $_SESSION['sdp_id'] = $row['sdp_id'];
                $_SESSION['logged_in'] = true;

                // Fetch sdp_name from sdp table if sdp_id present
                $sdp_name = null;
                if (!empty($row['sdp_id'])) {
                    $stmt_sdp = $conn->prepare("SELECT sdp_name FROM sdp WHERE sdp_id = ?");
                    $stmt_sdp->bind_param("i", $row['sdp_id']);
                    $stmt_sdp->execute();
                    $result_sdp = $stmt_sdp->get_result();
                    if ($result_sdp->num_rows > 0) {
                        $sdp_row = $result_sdp->fetch_assoc();
                        $_SESSION['sdp_name'] = $sdp_row['sdp_name'];
                        $sdp_name = $sdp_row['sdp_name'];
                    } else {
                        error_log("No sdp_name found for sdp_id: " . $row['sdp_id']);
                        $_SESSION['sdp_name'] = null;
                    }
                    $stmt_sdp->close();
                } else {
                    error_log("No sdp_id found for user with email: $email");
                    $_SESSION['sdp_name'] = null;
                }

                // If we have an sdp_id, fetch all sites for that SDP
                $data = [];
                if (!empty($_SESSION['sdp_id'])) {
                    $sdp_id_q = $_SESSION['sdp_id'];
                    $sql = "SELECT 
                            s.siteID, s.siteName, s.beneficiaries, 
                            COUNT(c.classId) AS classes, 
                            s.Project_pathway AS learningPathway, 
                            IF(s.latitude IS NOT NULL AND s.longitude IS NOT NULL, 
                               CONCAT(FORMAT(s.latitude, 3), ',', FORMAT(s.longitude, 3)), 
                               'No Coordinates Available') AS coordinates,
                            s.Category AS category, s.province
                        FROM sites s
                        LEFT JOIN class c ON c.siteId = s.siteID
                        WHERE s.sdp_id = ?
                        GROUP BY s.siteID, s.siteName, s.beneficiaries, s.Project_pathway, 
                                 s.latitude, s.longitude, s.Category, s.province";
                    $stmt_sites = $conn->prepare($sql);
                    if ($stmt_sites) {
                        $stmt_sites->bind_param("s", $sdp_id_q);
                        $stmt_sites->execute();
                        $result_sites = $stmt_sites->get_result();
                        while ($site_row = $result_sites->fetch_assoc()) {
                            $data[] = array_map('strval', $site_row);
                        }
                        $stmt_sites->close();
                    }
                }

                session_write_close();
                echo json_encode([
                    'success' => true,
                    'role' => $_SESSION['role'],
                    'account_id' => $_SESSION['account_id'],
                    'account_name' => $_SESSION['account_name'],
                    'sdp_id' => $_SESSION['sdp_id'],
                    'sdp_name' => $sdp_name,
                    'data' => $data
                ]);
                $stmt_account->close();
                exit;
            }
            // If password does not verify, continue checking other roles
            $stmt_account->close();
        }

        // Check SDP credentials
        $stmt = $conn->prepare("SELECT sdp_id, client_name, password FROM sdp WHERE TRIM(LOWER(email)) = LOWER(?)");
        $stmt->bind_param("s", $email);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            $row = $result->fetch_assoc();
            error_log("LOGIN: sdp hit for $email");
            if (verify_password_either($password, $row['password'])) {
                $_SESSION['role'] = 'sdp';
                $_SESSION['sdp_id'] = $row['sdp_id'];
                $_SESSION['client_name'] = $row['client_name'];
                $_SESSION['logged_in'] = true;
                session_write_close(); // Release session lock early

                $sdp_id = $row['sdp_id'];
                // Optimized query using JOIN instead of subquery
                $sql = "SELECT 
                        s.siteID, s.siteName, s.beneficiaries, 
                        COUNT(c.classId) AS classes, 
                        s.Project_pathway AS learningPathway, 
                        IF(s.latitude IS NOT NULL AND s.longitude IS NOT NULL, 
                           CONCAT(FORMAT(s.latitude, 3), ',', FORMAT(s.longitude, 3)), 
                           'No Coordinates Available') AS coordinates,
                        s.Category AS category, s.province
                    FROM sites s
                    LEFT JOIN class c ON c.siteId = s.siteID
                    WHERE s.sdp_id = ?
                    GROUP BY s.siteID, s.siteName, s.beneficiaries, s.Project_pathway, 
                             s.latitude, s.longitude, s.Category, s.province";

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
                        'data' => $data
                    ]);
                    $stmt_sites->close();
                } else {
                    echo json_encode(['success' => false, 'error' => 'Failed to prepare site query']);
                }
            } else {
                // Invalid SDP password: continue checking other roles (client/facilitator)
                $stmt->close();
                // Do not close $conn or exit here
            }
        } else {
            // Check client credentials
            $stmt = $conn->prepare("SELECT client_name, password FROM client WHERE TRIM(LOWER(email)) = LOWER(?) OR client_name = ?");
            $stmt->bind_param("ss", $email, $email);
            $stmt->execute();
            $result = $stmt->get_result();

            if ($result->num_rows > 0) {
                $row = $result->fetch_assoc();
                error_log("LOGIN: client hit for $email");
                if (!empty($row['password']) && verify_password_either($password, $row['password'])) {
                    $_SESSION['role'] = 'client';
                    $_SESSION['client_name'] = $row['client_name'];
                    $_SESSION['logged_in'] = true;
                    session_write_close();

                    echo json_encode([
                        'success' => true,
                        'role' => 'client'
                    ]);
                } else {
                    // Invalid client password: continue checking facilitator
                    $stmt->close();
                    // Do not close $conn or exit here
                }
            } else {
                // Check facilitator/assessor/moderator credentials
                $stmt = $conn->prepare("SELECT facilitator_id, classID, role, password FROM facilitator WHERE TRIM(LOWER(email)) = LOWER(?)");
                $stmt->bind_param("s", $email);
                $stmt->execute();
                $result = $stmt->get_result();

                if ($result->num_rows > 0) {
                    $row = $result->fetch_assoc();
                    error_log("LOGIN: facilitator hit for $email with role=" . ($row['role'] ?? '')); 
                    if (empty($row['password']) || !verify_password_either($password, $row['password'])) {
                        error_log("LOGIN: facilitator password mismatch for $email");
                        echo json_encode(['success' => false, 'message' => 'Invalid password']);
                        $stmt->close();
                        $conn->close();
                        exit;
                    }
                    // Normalize role including Logistics typo handling (case-insensitive)
                    $dbRole = strtolower(trim((string)$row['role']));
                    if ($dbRole === 'assessor') {
                        $role = 'assessor';
                    } elseif (strpos($dbRole, 'arpl') !== false) {
                        $role = 'arpl_assessor';
                    } elseif ($dbRole === 'moderator') {
                        $role = 'Moderator';
                    } elseif ($dbRole === 'logistics' || $dbRole === 'logistis') {
                        $role = 'Logistics';
                    } else {
                        $role = 'facilitator';
                    }

                    $_SESSION['role'] = $role;
                    $_SESSION['classID'] = $row['classID'];
                    $_SESSION['facilitator_id'] = $row['facilitator_id'];
                    $_SESSION['logged_in'] = true;
                    session_write_close();

                    if ($role === 'assessor' || $role === 'Moderator' || $role === 'arpl_assessor') {
                        $facilitator_id = $row['facilitator_id'];
                        // Optimized query (assumes facilitator_classes table)
                        $sql = "SELECT s.project_id, c.*
                                FROM class c
                                JOIN sites s ON s.siteID = c.siteID
                                JOIN facilitator_classes fc ON fc.classID = c.classID
                                WHERE fc.facilitator_id = ?";

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
                            $stmt_classes->close();
                        } else {
                            echo json_encode(['success' => false, 'error' => 'Failed to prepare class query']);
                        }
                    } elseif ($role === 'Logistics') {
                        // Determine project_id and list all sites for that project
                        $facilitator_id = $row['facilitator_id'];
                        $project_id = null;
                        $sdp_id = null;

                        // Attempt via classID on facilitator record
                        if (!empty($row['classID'])) {
                            $stmt_proj = $conn->prepare("SELECT s.project_id, s.sdp_id FROM class c JOIN sites s ON s.siteID = c.siteID WHERE c.classID = ? LIMIT 1");
                            $stmt_proj->bind_param("s", $row['classID']);
                            $stmt_proj->execute();
                            $res_proj = $stmt_proj->get_result();
                            if ($res_proj->num_rows > 0) {
                                $pr = $res_proj->fetch_assoc();
                                $project_id = $pr['project_id'];
                                $sdp_id = $pr['sdp_id'];
                            }
                            $stmt_proj->close();
                        }

                        // Fallback via facilitator_classes mapping
                        if ($project_id === null) {
                            $stmt_proj2 = $conn->prepare("SELECT s.project_id, s.sdp_id FROM facilitator_classes fc JOIN class c ON c.classID = fc.classID JOIN sites s ON s.siteID = c.siteID WHERE fc.facilitator_id = ? LIMIT 1");
                            $stmt_proj2->bind_param("s", $facilitator_id);
                            $stmt_proj2->execute();
                            $res_proj2 = $stmt_proj2->get_result();
                            if ($res_proj2->num_rows > 0) {
                                $pr = $res_proj2->fetch_assoc();
                                $project_id = $pr['project_id'];
                                $sdp_id = $pr['sdp_id'];
                            }
                            $stmt_proj2->close();
                        }

                        if ($project_id === null) {
                            echo json_encode(['success' => false, 'message' => 'No project linked to this Logistics account']);
                            exit;
                        }

                        // Fetch all sites in the project
                        $stmt_sites = $conn->prepare("SELECT 
                                s.siteID, s.siteName, s.beneficiaries,
                                s.Project_pathway AS learningPathway,
                                IF(s.latitude IS NOT NULL AND s.longitude IS NOT NULL,
                                   CONCAT(FORMAT(s.latitude, 3), ',', FORMAT(s.longitude, 3)),
                                   'No Coordinates Available') AS coordinates,
                                s.Category AS category, s.province, s.district, s.municipality
                            FROM sites s
                            WHERE s.project_id = ?");
                        $stmt_sites->bind_param("s", $project_id);
                        $stmt_sites->execute();
                        $result_sites = $stmt_sites->get_result();

                        $data = [];
                        while ($site_row = $result_sites->fetch_assoc()) {
                            $data[] = array_map('strval', $site_row);
                        }
                        $stmt_sites->close();

                        // Resolve sdp_name for UI
                        $sdp_name = '';
                        if (!empty($sdp_id)) {
                            $stmt_sdp = $conn->prepare("SELECT sdp_name FROM sdp WHERE sdp_id = ?");
                            $stmt_sdp->bind_param("i", $sdp_id);
                            $stmt_sdp->execute();
                            $res_sdp = $stmt_sdp->get_result();
                            if ($res_sdp->num_rows > 0) {
                                $sdp_row = $res_sdp->fetch_assoc();
                                $sdp_name = $sdp_row['sdp_name'];
                            }
                            $stmt_sdp->close();
                        }

                        echo json_encode([
                            'success' => true,
                            'role' => 'Logistics',
                            'sdp_name' => $sdp_name,
                            'data' => $data
                        ]);
                    } else {
                        $classID = $row['classID'];
                        $sql = "SELECT 
                                ld.LearnerID, ld.Title, ld.Name, ld.Surname, ld.Email, 
                                lc.clock_in_time, lc.clock_out_time, lc.contact_time
                            FROM learnerdetails ld
                            LEFT JOIN learner_clocking lc 
                                ON ld.LearnerID = lc.LearnerID AND lc.clock_date = CURDATE()
                            WHERE ld.classID = ?";

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
                            $stmt_learners->close();
                        } else {
                            echo json_encode(['success' => false, 'error' => 'Failed to prepare learner query']);
                        }
                    }
                } else {
                    echo json_encode(['success' => false, 'message' => 'Invalid credentials']);
                }
            }
        }
        $stmt->close();
        $conn->close();
    } catch (Exception $e) {
        error_log("Login error: " . $e->getMessage(), 3, '/var/log/php_login_errors.log');
        echo json_encode(['success' => false, 'error' => 'Server error']);
    }
}
?> -->


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
            $sdp_name = $row['client_name'];
            
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

            ob_end_clean(); // Clear any buffered output
            echo json_encode([
                'success' => true,
                'role' => 'sdp',
                'sdp_id' => $sdp_id,
                'sdp_name' => $sdp_name,
                'projects' => $projects,
                'project_count' => count($projects)
            ]);
            exit;
        } else {
            ob_end_clean();
            echo json_encode(['success' => false, 'message' => 'Invalid password for SDP.']);
            exit;
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
                $role = ($row['role'] === 'Assessor') ? 'assessor' : ((strcasecmp($row['role'], 'arpl_Assessor') === 0 || strcasecmp($row['role'], 'arpl_assessor') === 0) ? 'arpl_assessor' : (($row['role'] === 'Moderator') ? 'Moderator' : 'facilitator'));

                $_SESSION['role'] = $role;
                $_SESSION['classID'] = $row['classID'];
                $_SESSION['facilitator_id'] = $row['facilitator_id'];
                $_SESSION["logged_in"] = true;

                if ($role === 'assessor' || $role === 'Moderator' || $role === 'arpl_assessor') {
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
                            'facilitator_id' => $row['facilitator_id'],
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