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
    
    $siteID = $_GET['siteID'] ?? '';
    
    if (empty($siteID)) {
        throw new Exception("Site ID is required");
    }

    // Get account_id from request (can be from GET parameter, POST data, or session)
    $account_id = null;
    $search_query = $_GET['search'] ?? '';
    
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

    // Build search condition
    $search_condition = "";
    $search_params = [$siteID, $account_id];
    $param_types = "si";
    
    if (!empty($search_query)) {
        $search_condition = " AND (
            c.className LIKE ? OR 
            f.firstName LIKE ? OR 
            f.lastName LIKE ? OR 
            CONCAT(f.firstName, ' ', f.lastName) LIKE ?
        )";
        $search_term = "%{$search_query}%";
        $search_params = array_merge($search_params, [$search_term, $search_term, $search_term, $search_term]);
        $param_types .= "ssss";
    }

    // Get classes for the specified site with facilitator information, filtered by user's account
    $sql = "SELECT 
                c.classID,
                c.className,
                c.siteID,
                c.facilitatorID,
                s.siteName,
                s.province,
                s.Project_pathway as learningPathway,
                s.Category as category,
                f.facilitator_id,
                f.firstName as facilitator_firstName,
                f.lastName as facilitator_lastName,
                CONCAT(f.firstName, ' ', f.lastName) as facilitator_name,
                f.role as facilitator_role,
                f.email as facilitator_email,
                f.phoneNumber as facilitator_phone,
                f.assessorNo as facilitator_assessorNo,
                f.assessorExpiryDate as facilitator_assessorExpiry,
                f.f_IDNumber as facilitator_idNumber,
                f.workNumber as facilitator_workNumber,
                CASE 
                    WHEN f.facilitator_id IS NOT NULL THEN 'Assigned'
                    ELSE 'No Facilitator Assigned'
                END as facilitator_status,
                COUNT(DISTINCT ld.LearnerID) as total_learners,
                GROUP_CONCAT(DISTINCT CONCAT(ld.Title, ' ', ld.Name, ' ', ld.Surname) 
                    ORDER BY ld.Surname, ld.Name SEPARATOR ', ') as learner_names
            FROM class c
            LEFT JOIN sites s ON c.siteID = s.siteID
            LEFT JOIN facilitator f ON c.classID = f.classID
            LEFT JOIN learnerdetails ld ON c.classID = ld.classID
            JOIN account_user ac ON ac.sdp_id = s.sdp_id
            WHERE c.siteID = ? AND ac.account_id = ? {$search_condition}
            GROUP BY c.classID, c.className, c.siteID, c.facilitatorID, s.siteName, s.province, 
                     s.Project_pathway, s.Category, f.facilitator_id, f.firstName, f.lastName, 
                     f.role, f.email, f.phoneNumber, f.assessorNo, f.assessorExpiryDate, 
                     f.f_IDNumber, f.workNumber
            ORDER BY c.className";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param($param_types, ...$search_params);
    $stmt->execute();
    $result = $stmt->get_result();

    $classes = [];
    $site_info = null;
    
    while ($row = $result->fetch_assoc()) {
        // Capture site info from first row
        if (!$site_info) {
            $site_info = [
                'siteID' => (string)$row['siteID'],
                'siteName' => $row['siteName'] ?? '',
                'province' => $row['province'] ?? '',
                'learningPathway' => $row['learningPathway'] ?? '',
                'category' => $row['category'] ?? ''
            ];
        }
        
        $classes[] = [
            'classID' => (string)$row['classID'],
            'className' => $row['className'] ?? '',
            'siteID' => (string)$row['siteID'],
            'siteName' => $row['siteName'] ?? '',
            'province' => $row['province'] ?? '',
            'learningPathway' => $row['learningPathway'] ?? '',
            'category' => $row['category'] ?? '',
            'facilitatorID' => $row['facilitatorID'] ?? null,
            'facilitator_id' => $row['facilitator_id'] ?? null,
            'facilitator_name' => $row['facilitator_name'] ?? 'No Facilitator Assigned',
            'facilitator_firstName' => $row['facilitator_firstName'] ?? null,
            'facilitator_lastName' => $row['facilitator_lastName'] ?? null,
            'facilitator_role' => $row['facilitator_role'] ?? null,
            'facilitator_email' => $row['facilitator_email'] ?? null,
            'facilitator_phone' => $row['facilitator_phone'] ?? null,
            'facilitator_assessorNo' => $row['facilitator_assessorNo'] ?? null,
            'facilitator_assessorExpiry' => $row['facilitator_assessorExpiry'] ?? null,
            'facilitator_idNumber' => $row['facilitator_idNumber'] ?? null,
            'facilitator_workNumber' => $row['facilitator_workNumber'] ?? null,
            'facilitator_status' => $row['facilitator_status'] ?? 'No Facilitator Assigned',
            'status' => 'Active', // Default status for classes
            'total_learners' => (int)($row['total_learners'] ?? 0),
            'learner_names' => $row['learner_names'] ?? 'No Learners'
        ];
    }

    $stmt->close();
    $conn->close();

    // Clear any unwanted output
    ob_clean();
    
    // Output only clean JSON
    echo json_encode([
        'success' => true,
        'classes' => $classes,
        'site_info' => $site_info,
        'total_classes' => count($classes),
        'siteID' => $siteID,
        'account_id' => $account_id
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