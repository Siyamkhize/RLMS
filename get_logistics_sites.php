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
    $search_query = $_GET['search'] ?? '';
    
    // Try to get account_id from different sources
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
    $search_params = [$account_id];
    $param_types = "i";
    
    if (!empty($search_query)) {
        $search_condition = " AND (
            s.siteName LIKE ? OR 
            s.province LIKE ? OR 
            s.Category LIKE ? OR 
            s.Project_pathway LIKE ?
        )";
        $search_term = "%{$search_query}%";
        $search_params = array_merge($search_params, [$search_term, $search_term, $search_term, $search_term]);
        $param_types .= "ssss";
    }

    // Get sites filtered by user's account_id with comprehensive information including facilitators
    $sql = "SELECT 
                s.siteID,
                s.siteName,
                s.beneficiaries,
                s.Project_pathway as learningPathway,
                s.Category as category,
                s.province,
                s.sdp_id,
                COUNT(DISTINCT c.classID) as total_classes,
                COUNT(DISTINCT ld.LearnerID) as total_learners,
                COUNT(DISTINCT f.facilitator_id) as total_facilitators,
                IF(s.latitude IS NOT NULL AND s.longitude IS NOT NULL, 
                    CONCAT(FORMAT(s.latitude, 3), ',', FORMAT(s.longitude, 3)), 
                    'No Coordinates Available') AS coordinates,
                GROUP_CONCAT(DISTINCT c.className ORDER BY c.className SEPARATOR ', ') as class_names,
                GROUP_CONCAT(DISTINCT CONCAT(f.firstName, ' ', f.lastName) 
                    ORDER BY f.lastName, f.firstName SEPARATOR ', ') as facilitator_names
            FROM sites s
            LEFT JOIN class c ON s.siteID = c.siteID
            LEFT JOIN facilitator f ON c.classID = f.classID
            LEFT JOIN learnerdetails ld ON c.classID = ld.classID
            JOIN account_user ac ON ac.sdp_id = s.sdp_id
            WHERE ac.account_id = ? {$search_condition}
            GROUP BY s.siteID, s.siteName, s.beneficiaries, s.Project_pathway, s.Category, 
                     s.province, s.sdp_id, s.latitude, s.longitude
            ORDER BY s.province, s.siteName";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param($param_types, ...$search_params);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result === false) {
        throw new Exception("Query execution failed: " . $stmt->error);
    }

    $sites = [];
    $province_summary = [];
    
    while ($row = $result->fetch_assoc()) {
        $site_data = [
            'siteID' => (string)$row['siteID'],
            'siteName' => $row['siteName'] ?? '',
            'beneficiaries' => (int)($row['beneficiaries'] ?? 0),
            'learningPathway' => $row['learningPathway'] ?? '',
            'category' => $row['category'] ?? '',
            'province' => $row['province'] ?? '',
            'sdp_id' => (string)($row['sdp_id'] ?? ''),
            'total_classes' => (int)($row['total_classes'] ?? 0),
            'total_learners' => (int)($row['total_learners'] ?? 0),
            'total_facilitators' => (int)($row['total_facilitators'] ?? 0),
            'coordinates' => $row['coordinates'] ?? 'No Coordinates Available',
            'class_names' => $row['class_names'] ?? 'No Classes',
            'facilitator_names' => $row['facilitator_names'] ?? 'No Facilitators Assigned'
        ];
        
        $sites[] = $site_data;
        
        // Build province summary
        $province = $row['province'] ?? 'Unknown';
        if (!isset($province_summary[$province])) {
            $province_summary[$province] = [
                'province' => $province,
                'total_sites' => 0,
                'total_classes' => 0,
                'total_learners' => 0,
                'total_facilitators' => 0,
                'total_beneficiaries' => 0
            ];
        }
        
        $province_summary[$province]['total_sites']++;
        $province_summary[$province]['total_classes'] += (int)($row['total_classes'] ?? 0);
        $province_summary[$province]['total_learners'] += (int)($row['total_learners'] ?? 0);
        $province_summary[$province]['total_facilitators'] += (int)($row['total_facilitators'] ?? 0);
        $province_summary[$province]['total_beneficiaries'] += (int)($row['beneficiaries'] ?? 0);
    }

    $stmt->close();
    $conn->close();

    // Clear any unwanted output
    ob_clean();
    
    // Output only clean JSON
    echo json_encode([
        'success' => true,
        'sites' => $sites,
        'province_summary' => array_values($province_summary),
        'total_sites' => count($sites),
        'total_provinces' => count($province_summary),
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