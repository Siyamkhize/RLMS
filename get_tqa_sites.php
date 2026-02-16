<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

session_start();
include('connection.php');

try {
    // Get account_id from request (can be from GET parameter, POST data, or session)
    $account_id = null;
    
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

    // TQA users can see sites filtered by their account permissions
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
                IF(s.latitude IS NOT NULL AND s.longitude IS NOT NULL, 
                    CONCAT(FORMAT(s.latitude, 3), ',', FORMAT(s.longitude, 3)), 
                    'No Coordinates Available') AS coordinates,
                GROUP_CONCAT(DISTINCT c.className ORDER BY c.className SEPARATOR ', ') as class_names,
                sdp.client_name as sdp_name
            FROM sites s
            LEFT JOIN class c ON s.siteID = c.siteID
            LEFT JOIN learnerdetails ld ON c.classID = ld.classID
            LEFT JOIN sdp ON s.sdp_id = sdp.sdp_id
            JOIN account_user ac ON ac.sdp_id = s.sdp_id
            WHERE ac.account_id = ?
            GROUP BY s.siteID, s.siteName, s.beneficiaries, s.Project_pathway, s.Category, 
                     s.province, s.sdp_id, s.latitude, s.longitude, sdp.client_name
            ORDER BY s.province, s.siteName";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param("i", $account_id);
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
            'sdp_name' => $row['sdp_name'] ?? '',
            'total_classes' => (int)($row['total_classes'] ?? 0),
            'total_learners' => (int)($row['total_learners'] ?? 0),
            'coordinates' => $row['coordinates'] ?? 'No Coordinates Available',
            'class_names' => $row['class_names'] ?? 'No Classes'
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
                'total_beneficiaries' => 0
            ];
        }
        
        $province_summary[$province]['total_sites']++;
        $province_summary[$province]['total_classes'] += (int)($row['total_classes'] ?? 0);
        $province_summary[$province]['total_learners'] += (int)($row['total_learners'] ?? 0);
        $province_summary[$province]['total_beneficiaries'] += (int)($row['beneficiaries'] ?? 0);
    }

    echo json_encode([
        'success' => true,
        'sites' => $sites,
        'province_summary' => array_values($province_summary),
        'total_sites' => count($sites),
        'total_provinces' => count($province_summary),
        'account_id' => $account_id,
        'role' => 'tqa'
    ]);

    $stmt->close();

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

$conn->close();
?>