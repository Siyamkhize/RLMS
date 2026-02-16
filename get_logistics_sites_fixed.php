<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

session_start();

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

    // Use PDO instead of mysqli to avoid configuration issues
    $servername = "localhost";
    $username = "root";
    $password = "";
    $dbname = "rlmss";
    
    $pdo = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Get sites filtered by user's account_id with comprehensive information
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
                GROUP_CONCAT(DISTINCT c.className ORDER BY c.className SEPARATOR ', ') as class_names
            FROM sites s
            LEFT JOIN class c ON s.siteID = c.siteID
            LEFT JOIN learnerdetails ld ON c.classID = ld.classID
            JOIN account_user ac ON ac.sdp_id = s.sdp_id
            WHERE ac.account_id = ?
            GROUP BY s.siteID, s.siteName, s.beneficiaries, s.Project_pathway, s.Category, 
                     s.province, s.sdp_id, s.latitude, s.longitude
            ORDER BY s.province, s.siteName";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([$account_id]);
    $result = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $sites = [];
    $province_summary = [];
    
    foreach ($result as $row) {
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
        'account_id' => $account_id
    ]);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}
?>