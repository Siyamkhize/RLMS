<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

// Suppress ALL output except our JSON
error_reporting(0);
ini_set('display_errors', 0);
ini_set('log_errors', 0);

// Start output buffering to catch any unwanted output
ob_start();

session_start();

try {
    // Use the original connection.php which works
    include('connection.php');
    
    // Get account_id from request (can be from GET parameter, POST data, or session)
    $account_id = null;
    
    if (isset($_GET['account_id'])) {
        $account_id = (int)$_GET['account_id'];
    } elseif (isset($_POST['account_id'])) {
        $account_id = (int)$_POST['account_id'];
    } elseif (isset($_SESSION['account_id'])) {
        $account_id = (int)$_SESSION['account_id'];
    }
    
    if (!$account_id) {
        throw new Exception("Account ID is required for authentication");
    }

    // Optional filters
    $siteID = $_GET['siteID'] ?? null;
    $classID = $_GET['classID'] ?? null;

    // Get facilitators for sites accessible by this logistics user
    $sql = "SELECT DISTINCT
                f.facilitator_id,
                f.firstName,
                f.lastName,
                CONCAT(f.firstName, ' ', f.lastName) as full_name,
                f.role,
                f.email,
                f.phoneNumber,
                f.assessorNo,
                f.assessorExpiryDate,
                f.f_IDNumber as idNumber,
                f.workNumber,
                f.f_signature as signature_path,
                f.f_profile as profile_path,
                c.classID,
                c.className,
                s.siteID,
                s.siteName,
                s.province,
                COUNT(DISTINCT ld.LearnerID) as total_learners_assigned,
                CASE 
                    WHEN f.assessorExpiryDate IS NOT NULL AND f.assessorExpiryDate != '' THEN
                        CASE 
                            WHEN STR_TO_DATE(f.assessorExpiryDate, '%Y-%m-%d') < CURDATE() THEN 'Expired'
                            WHEN STR_TO_DATE(f.assessorExpiryDate, '%Y-%m-%d') < DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 'Expiring Soon'
                            ELSE 'Valid'
                        END
                    ELSE 'No Expiry Date'
                END as assessor_status
            FROM facilitator f
            LEFT JOIN class c ON f.facilitator_id = c.facilitatorID
            LEFT JOIN sites s ON c.siteID = s.siteID
            LEFT JOIN learnerdetails ld ON c.classID = ld.classID
            JOIN account_user ac ON ac.sdp_id = s.sdp_id
            WHERE ac.account_id = ?";

    $params = [$account_id];
    $param_types = "i";

    // Add optional filters
    if ($siteID) {
        $sql .= " AND s.siteID = ?";
        $params[] = $siteID;
        $param_types .= "s";
    }

    if ($classID) {
        $sql .= " AND c.classID = ?";
        $params[] = $classID;
        $param_types .= "s";
    }

    $sql .= " GROUP BY f.facilitator_id, f.firstName, f.lastName, f.role, f.email, f.phoneNumber, 
                     f.assessorNo, f.assessorExpiryDate, f.f_IDNumber, f.workNumber, f.f_signature, 
                     f.f_profile, c.classID, c.className, s.siteID, s.siteName, s.province
              ORDER BY f.lastName, f.firstName, s.siteName, c.className";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param($param_types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();

    $facilitators = [];
    $facilitator_summary = [];
    
    while ($row = $result->fetch_assoc()) {
        $facilitator_data = [
            'facilitator_id' => (string)$row['facilitator_id'],
            'firstName' => $row['firstName'] ?? '',
            'lastName' => $row['lastName'] ?? '',
            'full_name' => $row['full_name'] ?? '',
            'role' => $row['role'] ?? '',
            'email' => $row['email'] ?? '',
            'phoneNumber' => $row['phoneNumber'] ?? '',
            'assessorNo' => $row['assessorNo'] ?? '',
            'assessorExpiryDate' => $row['assessorExpiryDate'] ?? '',
            'assessor_status' => $row['assessor_status'] ?? 'No Expiry Date',
            'idNumber' => $row['idNumber'] ?? '',
            'workNumber' => $row['workNumber'] ?? '',
            'signature_path' => $row['signature_path'] ?? '',
            'profile_path' => $row['profile_path'] ?? '',
            'classID' => $row['classID'] ?? null,
            'className' => $row['className'] ?? 'No Class Assigned',
            'siteID' => $row['siteID'] ?? null,
            'siteName' => $row['siteName'] ?? 'No Site Assigned',
            'province' => $row['province'] ?? '',
            'total_learners_assigned' => (int)($row['total_learners_assigned'] ?? 0)
        ];
        
        $facilitators[] = $facilitator_data;
        
        // Build facilitator summary
        $facilitator_id = $row['facilitator_id'];
        if (!isset($facilitator_summary[$facilitator_id])) {
            $facilitator_summary[$facilitator_id] = [
                'facilitator_id' => (string)$facilitator_id,
                'full_name' => $row['full_name'] ?? '',
                'role' => $row['role'] ?? '',
                'email' => $row['email'] ?? '',
                'assessor_status' => $row['assessor_status'] ?? 'No Expiry Date',
                'total_classes' => 0,
                'total_learners' => 0,
                'sites' => [],
                'classes' => []
            ];
        }
        
        if ($row['classID']) {
            $facilitator_summary[$facilitator_id]['total_classes']++;
            $facilitator_summary[$facilitator_id]['total_learners'] += (int)($row['total_learners_assigned'] ?? 0);
            
            if (!in_array($row['siteName'], $facilitator_summary[$facilitator_id]['sites'])) {
                $facilitator_summary[$facilitator_id]['sites'][] = $row['siteName'];
            }
            
            if (!in_array($row['className'], $facilitator_summary[$facilitator_id]['classes'])) {
                $facilitator_summary[$facilitator_id]['classes'][] = $row['className'];
            }
        }
    }

    $stmt->close();
    $conn->close();

    // Clear any unwanted output
    ob_clean();
    
    // Output only clean JSON
    echo json_encode([
        'success' => true,
        'facilitators' => $facilitators,
        'facilitator_summary' => array_values($facilitator_summary),
        'total_facilitators' => count($facilitator_summary),
        'total_assignments' => count($facilitators),
        'account_id' => $account_id,
        'filters' => [
            'siteID' => $siteID,
            'classID' => $classID
        ]
    ]);

} catch (Exception $e) {
    // Clear any unwanted output
    ob_clean();
    
    // Output only clean JSON error
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'debug_info' => [
            'session_account_id' => $_SESSION['account_id'] ?? 'not set',
            'get_account_id' => $_GET['account_id'] ?? 'not set',
            'post_account_id' => $_POST['account_id'] ?? 'not set'
        ]
    ]);
}

// End output buffering
ob_end_flush();
?>