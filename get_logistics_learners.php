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
    
    $classID = $_GET['classID'] ?? '';
    
    if (empty($classID)) {
        throw new Exception("Class ID is required");
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
    $search_params = [$classID, $account_id];
    $param_types = "si";
    
    if (!empty($search_query)) {
        $search_condition = " AND (
            ld.Name LIKE ? OR 
            ld.Surname LIKE ? OR 
            ld.IDNumber LIKE ? OR 
            ld.Email LIKE ? OR 
            ld.Phone LIKE ? OR 
            CONCAT(ld.Name, ' ', ld.Surname) LIKE ? OR 
            CONCAT(ld.Title, ' ', ld.Name, ' ', ld.Surname) LIKE ?
        )";
        $search_term = "%{$search_query}%";
        $search_params = array_merge($search_params, [$search_term, $search_term, $search_term, $search_term, $search_term, $search_term, $search_term]);
        $param_types .= "sssssss";
    }

    // Get learners for the specified class with simplified information, filtered by user's account
    $sql = "SELECT 
                ld.LearnerID,
                ld.Title,
                ld.Name,
                ld.Surname,
                ld.Email,
                ld.Phone,
                ld.IDNumber,
                ld.classID,
                c.className,
                c.siteID,
                s.siteName,
                s.province,
                s.Project_pathway as learningPathway,
                s.Category as category
            FROM learnerdetails ld
            LEFT JOIN class c ON ld.classID = c.classID
            LEFT JOIN sites s ON c.siteID = s.siteID
            JOIN account_user ac ON ac.sdp_id = s.sdp_id
            WHERE ld.classID = ? AND ac.account_id = ? {$search_condition}
            ORDER BY ld.Surname, ld.Name";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param($param_types, ...$search_params);
    $stmt->execute();
    $result = $stmt->get_result();

    $learners = [];
    $class_info = null;
    
    while ($row = $result->fetch_assoc()) {
        // Capture class info from first row
        if (!$class_info) {
            $class_info = [
                'classID' => (string)$row['classID'],
                'className' => $row['className'] ?? '',
                'siteID' => (string)($row['siteID'] ?? ''),
                'siteName' => $row['siteName'] ?? '',
                'province' => $row['province'] ?? '',
                'learningPathway' => $row['learningPathway'] ?? '',
                'category' => $row['category'] ?? ''
            ];
        }
        
        $learners[] = [
            'LearnerID' => (string)$row['LearnerID'],
            'Title' => $row['Title'] ?? '',
            'Name' => $row['Name'] ?? '',
            'Surname' => $row['Surname'] ?? '',
            'FullName' => trim(($row['Title'] ?? '') . ' ' . ($row['Name'] ?? '') . ' ' . ($row['Surname'] ?? '')),
            'Email' => $row['Email'] ?? '',
            'Phone' => $row['Phone'] ?? '',
            'IDNumber' => $row['IDNumber'] ?? '',
            'classID' => (string)$row['classID'],
            'className' => $row['className'] ?? '',
            'siteID' => (string)($row['siteID'] ?? ''),
            'siteName' => $row['siteName'] ?? '',
            'province' => $row['province'] ?? '',
            'learningPathway' => $row['learningPathway'] ?? '',
            'category' => $row['category'] ?? ''
        ];
    }

    // Calculate basic class statistics
    $total_learners = count($learners);

    $stmt->close();
    $conn->close();

    // Clear any unwanted output
    ob_clean();
    
    // Output only clean JSON
    echo json_encode([
        'success' => true,
        'learners' => $learners,
        'class_info' => $class_info,
        'total_learners' => $total_learners,
        'classID' => $classID,
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