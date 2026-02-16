<?php
ob_start(); // Start output buffering to prevent header issues
session_start();

// Enable debug mode for development (set to false in production)
define('DEBUG_MODE', false);
if (DEBUG_MODE) {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
} else {
    error_reporting(E_ALL);
    ini_set('display_errors', 0);
    ini_set('log_errors', 1);
    ini_set('error_log', '/home/rlmsrlmsco/public_html/error.log');
}

// Increase memory and execution time for heavy operations
ini_set('memory_limit', '256M');
ini_set('max_execution_time', 60);

// Check session save path
if (!is_writable(session_save_path())) {
    error_log("Session save path not writable: " . session_save_path());
    $_SESSION['error'] = "Server configuration error. Please contact administrator.";
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// Include database connection
if (!file_exists('connection.php')) {
    error_log("connection.php not found");
    $_SESSION['error'] = "Database configuration file missing.";
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}
include 'connection.php';

// Check database connection
if (!isset($conn) || $conn->connect_error) {
    error_log("Connection failed: " . ($conn ? $conn->connect_error : "Connection object not defined"));
    $_SESSION['error'] = "Unable to connect to database. Please try again later.";
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// Set timezone
try {
    date_default_timezone_set('Africa/Johannesburg');
} catch (Exception $e) {
    error_log("Timezone setting failed: " . $e->getMessage());
    $_SESSION['error'] = "Invalid timezone configuration.";
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// Function to sanitize string input for HTML output
function sanitizeString($input) {
    if (is_null($input) || $input === '') {
        return '';
    }
    return htmlspecialchars(trim($input), ENT_QUOTES, 'UTF-8');
}

// Function to sanitize string input for database
function dbSanitize($input) {
    return trim($input ?? '');
}

// Handle POST for marking individual learners as received
if (isset($_POST['mark_received'])) {
    error_log("Mark received handler triggered");
    $classID = (int)$_POST['classID'];
    $receivedLearners = $_POST['received_learners'] ?? [];
    error_log("ClassID: " . $classID . ", Received learners count: " . count($receivedLearners));
    
    if (empty($receivedLearners)) {
        $_SESSION['error'] = "No learners selected.";
        header("Location: " . $_SERVER['PHP_SELF'] . "?" . http_build_query($_GET));
        exit;
    }
    
    // Fetch className
    $classNameSql = "SELECT className FROM class WHERE classID = ?";
    $classNameStmt = $conn->prepare($classNameSql);
    if (!$classNameStmt) {
        error_log("Prepare failed for className: " . $conn->error);
        $_SESSION['error'] = "Error preparing class query.";
        header("Location: " . $_SERVER['PHP_SELF'] . "?" . http_build_query($_GET));
        exit;
    }
    $classNameStmt->bind_param("i", $classID);
    if (!$classNameStmt->execute()) {
        error_log("Execute failed for className: " . $classNameStmt->error);
        $_SESSION['error'] = "Error executing class query.";
        $classNameStmt->close();
        header("Location: " . $_SERVER['PHP_SELF'] . "?" . http_build_query($_GET));
        exit;
    }
    $classNameResult = $classNameStmt->get_result();
    $classRow = $classNameResult->fetch_assoc();
    $className = $classRow ? $classRow['className'] : 'Unknown';
    $classNameStmt->close();
    error_log("Fetched className: " . $className);

    $successCount = 0;
    foreach ($receivedLearners as $encoded) {
        $parts = explode('|', $encoded, 2);
        if (count($parts) !== 2) continue;
        $idNumber = trim($parts[0]);
        $fullName = trim($parts[1]);
        if (empty($idNumber) || empty($fullName)) continue;
        error_log("Processing ID: " . $idNumber . ", Name: " . $fullName);
        
        $insertSql = "INSERT INTO material_receipt_form (student_full_name, student_id_number, class_name, date_received, received, quantity, description) VALUES (?, ?, ?, NOW(), 'Yes', 1, 'POE Submission')";
        $insertStmt = $conn->prepare($insertSql);
        if (!$insertStmt) {
            error_log("Prepare failed for insert: " . $conn->error);
            continue;
        }
        $insertStmt->bind_param("sss", $fullName, $idNumber, $className);
        if ($insertStmt->execute()) {
            $successCount++;
            error_log("Insert successful for " . $idNumber);
        } else {
            error_log("Insert failed for learner $idNumber: " . $insertStmt->error);
        }
        $insertStmt->close();
    }
    
    if ($successCount > 0) {
        $_SESSION['success'] = "$successCount learner(s) marked as POE received successfully.";
    } else {
        $_SESSION['error'] = "No learners were marked as received. Check error log for details.";
    }
    header("Location: " . $_SERVER['PHP_SELF'] . "?" . http_build_query($_GET));
    exit;
}

// Handle POST for saving/updating POE form
if (isset($_POST['save_poe'])) {
    $classID = (int)$_POST['classID'];
    $facilitator_full_name = dbSanitize($_POST['facilitator_full_name']);
    $representative_full_name = dbSanitize($_POST['representative_full_name']);
    $description = 'POE Submission';
    $quantity = (int)$_POST['quantity'];
    $facilitator_signature = dbSanitize($_POST['facilitator_signature']);
    $representative_signature = dbSanitize($_POST['representative_signature']);
    $submission_id = isset($_POST['submission_id']) && !empty($_POST['submission_id']) ? (int)$_POST['submission_id'] : 0;
    $is_synced = 0;

    // Fetch className for qualification_name
    $classNameSql = "SELECT className FROM class WHERE classID = ?";
    $classNameStmt = $conn->prepare($classNameSql);
    if (!$classNameStmt) {
        error_log("Prepare failed for className: " . $conn->error);
        $_SESSION['error'] = "Error preparing class query.";
        header("Location: " . $_SERVER['PHP_SELF'] . "?" . http_build_query($_GET));
        exit;
    }
    $classNameStmt->bind_param("i", $classID);
    if (!$classNameStmt->execute()) {
        error_log("Execute failed for className: " . $classNameStmt->error);
        $_SESSION['error'] = "Error executing class query.";
        $classNameStmt->close();
        header("Location: " . $_SERVER['PHP_SELF'] . "?" . http_build_query($_GET));
        exit;
    }
    $classNameResult = $classNameStmt->get_result();
    $classRow = $classNameResult->fetch_assoc();
    $qualification_name = $classRow ? $classRow['className'] : 'Unknown';
    $classNameStmt->close();

    if ($submission_id > 0) {
        // Update existing record
        $updateSql = "UPDATE material_forms SET facilitator_full_name = ?, representative_full_name = ?, qualification_name = ?, facilitator_signature = ?, representative_signature = ?, quantity = ? WHERE id = ?";
        $updateStmt = $conn->prepare($updateSql);
        if ($updateStmt) {
            $updateStmt->bind_param("sssssii", $facilitator_full_name, $representative_full_name, $qualification_name, $facilitator_signature, $representative_signature, $quantity, $submission_id);
            if ($updateStmt->execute()) {
                if ($updateStmt->affected_rows > 0) {
                    $_SESSION['success'] = "POE Submission updated successfully.";
                } else {
                    $_SESSION['error'] = "No changes made or record not found.";
                }
            } else {
                error_log("Update failed: " . $updateStmt->error);
                $_SESSION['error'] = "Error updating POE submission.";
            }
            $updateStmt->close();
        } else {
            error_log("Prepare failed for update: " . $conn->error);
            $_SESSION['error'] = "Error preparing update query.";
        }
    } else {
        // Insert new record
        $insertSql = "INSERT INTO material_forms (classID, facilitator_full_name, representative_full_name, qualification_name, facilitator_signature, representative_signature, description, quantity, is_synced) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
        $insertStmt = $conn->prepare($insertSql);
        if ($insertStmt) {
            $insertStmt->bind_param("issssssii", $classID, $facilitator_full_name, $representative_full_name, $qualification_name, $facilitator_signature, $representative_signature, $description, $quantity, $is_synced);
            if ($insertStmt->execute()) {
                $_SESSION['success'] = "POE Submission recorded successfully.";
            } else {
                error_log("Insert failed: " . $insertStmt->error);
                $_SESSION['error'] = "Error saving POE submission.";
            }
            $insertStmt->close();
        } else {
            error_log("Prepare failed: " . $conn->error);
            $_SESSION['error'] = "Error preparing save query.";
        }
    }
    header("Location: " . $_SERVER['PHP_SELF'] . "?" . http_build_query($_GET));
    exit;
}

// Fetch districts
$districts = [];
$districtQuery = "SELECT DISTINCT District FROM sites ORDER BY District";
$districtResult = $conn->query($districtQuery);
if ($districtResult) {
    while ($d = $districtResult->fetch_assoc()) {
        $districts[] = $d['District'];
    }
} else {
    error_log("Error fetching districts: " . $conn->error);
    $_SESSION['error'] = "Error fetching districts";
}

// Fetch sites
$sites = [];
$siteQuery = "SELECT DISTINCT siteName FROM sites";
if (isset($_GET['district']) && !empty($_GET['district'])) {
    $siteQuery .= " WHERE District = '" . $conn->real_escape_string($_GET['district']) . "'";
}
$siteQuery .= " ORDER BY siteName";
$siteResult = $conn->query($siteQuery);
if ($siteResult) {
    while ($s = $siteResult->fetch_assoc()) {
        $sites[] = $s['siteName'];
    }
} else {
    error_log("Error fetching sites: " . $conn->error);
    $_SESSION['error'] = "Error fetching sites";
}

// Get filter parameters
$selectedDistrict = isset($_GET['district']) ? sanitizeString($_GET['district']) : '';
$selectedSite = isset($_GET['site']) ? sanitizeString($_GET['site']) : '';
$selectedClass = isset($_GET['class']) ? intval($_GET['class']) : 0;

// Fetch classes under selected site
$classes = [];
$selectedClassName = '';
if (!empty($selectedSite)) {
    $classQuery = "SELECT c.classID, c.className FROM class c JOIN sites s ON s.siteID = c.siteID WHERE s.siteName = ? ORDER BY c.className";
    $classStmt = $conn->prepare($classQuery);
    if ($classStmt) {
        $classStmt->bind_param('s', $selectedSite);
        if ($classStmt->execute()) {
            $cr = $classStmt->get_result();
            while ($row = $cr->fetch_assoc()) {
                $classes[] = $row;
                if ($selectedClass && intval($row['classID']) === $selectedClass) {
                    $selectedClassName = $row['className'];
                }
            }
        }
        $classStmt->close();
    }
}
$startDate = isset($_GET['start_date']) ? sanitizeString($_GET['start_date']) : date('Y-m-d', strtotime('-7 days'));
$endDate = isset($_GET['end_date']) ? sanitizeString($_GET['end_date']) : date('Y-m-d');

// Validate dates
try {
    $startDateTime = new DateTime($startDate);
    $endDateTime = new DateTime($endDate);
    if ($startDateTime > $endDateTime) {
        $endDate = $startDate;
        $endDateTime = $startDateTime;
    }
} catch (Exception $e) {
    error_log("Invalid date range: " . $e->getMessage());
    $_SESSION['error'] = "Invalid date range";
    $startDate = date('Y-m-d', strtotime('-7 days'));
    $endDate = date('Y-m-d');
    $startDateTime = new DateTime($startDate);
    $endDateTime = new DateTime($endDate);
}

// Main query
$sql = "
    SELECT 
        s.District,
        s.siteName,
        c.classID,
        c.className,
        ld.LearnerID,
        ld.Name,
        ld.Surname,
        ld.IDNumber,
        ld.PhoneNumber,
        f.firstName AS facilitatorFirstName,
        f.lastName AS facilitatorLastName,
        f.phoneNumber AS facilitatorPhone,
        
        -- POE Submission
        (SELECT COUNT(*) 
         FROM material_receipt_form m 
         WHERE m.student_id_number = ld.IDNumber 
           AND m.class_name = c.className 
           AND m.date_received >= ? 
           AND m.date_received <= ?
           AND m.received = 'Yes' 
           AND m.quantity > 0 
           AND m.description = 'POE Submission') AS has_poe,

        -- Representative (only for POE Submission)
        (SELECT representative_full_name 
         FROM material_forms m 
         WHERE m.classID = c.classID 
           AND m.description = 'POE Submission'
           AND m.created_at >= ? 
           AND DATE(m.created_at) <= ?
         ORDER BY m.created_at DESC 
         LIMIT 1) AS representative_name

    FROM sites s
    JOIN class c 
        ON s.siteID = c.siteID
    JOIN facilitator f 
        ON c.classID = f.classID 
        AND f.role = 'facilitator'
    JOIN learnerdetails ld 
        ON c.classID = ld.classID
";

$whereClauses = [];
$bindParams = [];
// Bind parameters for subqueries: 1 pair for poe + 1 pair for representative = 2 pairs
for ($i = 0; $i < 2; $i++) {
    $bindParams[] = $startDate;
    $bindParams[] = $endDate;
}
if (!empty($selectedDistrict)) {
    $whereClauses[] = "s.District = ?";
    $bindParams[] = $selectedDistrict;
}
if (!empty($selectedSite)) {
    $whereClauses[] = "s.siteName = ?";
    $bindParams[] = $selectedSite;
}
if (!empty($selectedClass)) {
    $whereClauses[] = "c.classID = ?";
    $bindParams[] = $selectedClass;
}
if (!empty($whereClauses)) {
    $sql .= " WHERE " . implode(" AND ", $whereClauses);
}

$sql .= " ORDER BY s.District, s.siteName, c.className, ld.Surname, ld.Name";

$stmt = $conn->prepare($sql);
if (!$stmt) {
    error_log("Prepare failed for main query: " . $conn->error);
    $_SESSION['error'] = "Error preparing report query";
    $reportData = [];
} else {
// Build types: first 4 date strings for subqueries, then optional district/site/class
$types = str_repeat('s', 4);
if (!empty($selectedDistrict)) { $types .= 's'; }
if (!empty($selectedSite)) { $types .= 's'; }
if (!empty($selectedClass)) { $types .= 'i'; }
    $bind_params = array_merge([$types], $bindParams);
    $bind_refs = [];
    foreach ($bind_params as $k => $v) {
        $bind_refs[$k] = &$bind_params[$k];
    }
    if (call_user_func_array([$stmt, 'bind_param'], $bind_refs) === false) {
        error_log("Bind failed for main query: " . $stmt->error);
        $_SESSION['error'] = "Error binding report query";
        $stmt->close();
        $reportData = [];
    } elseif (!$stmt->execute()) {
        error_log("Execute failed for main query: " . $stmt->error);
        $_SESSION['error'] = "Error executing report query";
        $stmt->close();
        $reportData = [];
    } else {
        $result = $stmt->get_result();
        if (!$result) {
            error_log("Get result failed: " . $conn->error);
            $_SESSION['error'] = "Error getting report result";
            $stmt->close();
            $reportData = [];
        } else {
            $reportData = [];
            while ($row = $result->fetch_assoc()) {
                $siteKey = $row['siteName'];
                $classKey = $row['className'];
                $learnerKey = $row['LearnerID'];
                
                if (!isset($reportData[$siteKey])) {
                    $reportData[$siteKey] = [
                        'district' => $row['District'],
                        'classes' => []
                    ];
                }
                
                if (!isset($reportData[$siteKey]['classes'][$classKey])) {
                    $reportData[$siteKey]['classes'][$classKey] = [
                        'classID' => $row['classID'],
                        'facilitator' => null,
                        'representative' => null,
                        'submission' => null,
                        'learners' => []
                    ];
                }
                
                // Set facilitator info if not already set
                if ($reportData[$siteKey]['classes'][$classKey]['facilitator'] === null) {
                    $reportData[$siteKey]['classes'][$classKey]['facilitator'] = [
                        'firstName' => $row['facilitatorFirstName'],
                        'lastName' => $row['facilitatorLastName'],
                        'phoneNumber' => $row['facilitatorPhone']
                    ];
                }
                
                // Set representative if not already set
                if ($reportData[$siteKey]['classes'][$classKey]['representative'] === null) {
                    $reportData[$siteKey]['classes'][$classKey]['representative'] = $row['representative_name'] ?? 'N/A';
                }
                
                if (!isset($reportData[$siteKey]['classes'][$classKey]['learners'][$learnerKey])) {
                    $reportData[$siteKey]['classes'][$classKey]['learners'][$learnerKey] = [
                        'name' => $row['Name'],
                        'surname' => $row['Surname'],
                        'id_number' => $row['IDNumber'],
                        'phone_number' => $row['PhoneNumber'],
                        'materials' => [
                            'POE Submission' => ((int)$row['has_poe'] > 0) ? 'Yes' : 'No'
                        ]
                    ];
                }
            }
            $stmt->close();
        }
    }
}

// Fetch submissions for each class
if (!empty($reportData)) {
    foreach ($reportData as $siteName => &$siteData) {
        foreach ($siteData['classes'] as $className => &$classData) {
            $classID = $classData['classID'];
            $submissionSql = "SELECT id, facilitator_full_name, representative_full_name, facilitator_signature, representative_signature, created_at FROM material_forms WHERE classID = ? AND description = 'POE Submission' AND created_at >= ? AND DATE(created_at) <= ? ORDER BY created_at DESC LIMIT 1";
            $submissionStmt = $conn->prepare($submissionSql);
            if ($submissionStmt) {
                $submissionStmt->bind_param("iss", $classID, $startDate, $endDate);
                if ($submissionStmt->execute()) {
                    $submissionResult = $submissionStmt->get_result();
                    $classData['submission'] = $submissionResult->fetch_assoc();
                } else {
                    error_log("Execute failed for submission classID $classID: " . $submissionStmt->error);
                    $classData['submission'] = null;
                }
                $submissionStmt->close();
            } else {
                $classData['submission'] = null;
                error_log("Prepare failed for submission classID $classID: " . $conn->error);
            }
        }
    }
}

// Calculate overall stats
$overallTotalLearners = 0;
$overallPOEYes = 0;

foreach ($reportData as $siteName => $siteData) {
    foreach ($siteData['classes'] as $className => $classData) {
        $totalLearners = count($classData['learners']);
        $overallTotalLearners += $totalLearners;
        
        foreach ($classData['learners'] as $learner) {
            if ($learner['materials']['POE Submission'] === 'Yes') $overallPOEYes++;
        }
    }
}

$overallPOERate = $overallTotalLearners > 0 ? round(($overallPOEYes / $overallTotalLearners) * 100, 1) : 0;
?>

<!DOCTYPE html>
<html>
<head>
    <title>Enhanced Learner POE Submission Report</title>
    <style>
        /* CSS remains unchanged from original */
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 0;
        }
        
        .container {
            max-width: 1600px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .alert {
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 8px;
            font-weight: 500;
        }
        
        .alert-success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .alert-error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
            text-align: center;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        h1 { 
            color: #2c3e50;
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 10px;
            text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        .subtitle {
            color: #7f8c8d;
            font-size: 1.1rem;
            font-weight: 300;
        }
        
        .overall-summary {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .overall-summary h2 {
            color: #2c3e50;
            font-size: 1.8rem;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .overall-summary h2::before {
            content: "📊";
            font-size: 1.2em;
        }
        
        .overall-period {
            background: linear-gradient(135deg, #e3f2fd, #bbdefb);
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
            border-left: 4px solid #2196f3;
        }
        
        .overall-period strong {
            color: #1976d2;
        }
        
        .filters { 
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            margin-bottom: 30px; 
            padding: 25px; 
            border-radius: 15px;
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .filters h3 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 1.3rem;
            font-weight: 600;
        }
        
        .filter-group { 
            display: inline-block; 
            margin-right: 25px; 
            margin-bottom: 15px;
            vertical-align: top;
        }
        
        .filter-label { 
            display: block;
            margin-bottom: 8px; 
            font-weight: 600;
            color: #34495e;
            font-size: 0.9rem;
        }
        
        select, input[type="date"], input[type="text"] { 
            padding: 12px 15px;
            border: 2px solid #e1e8ed;
            border-radius: 8px;
            font-size: 14px;
            transition: all 0.3s ease;
            background: white;
            min-width: 150px;
        }
        
        select:focus, input[type="date"]:focus, input[type="text"]:focus {
            outline: none;
            border-color: #3498db;
            box-shadow: 0 0 0 3px rgba(52, 152, 219, 0.1);
        }
        
        button { 
            padding: 12px 25px; 
            background: linear-gradient(135deg, #3498db, #2980b9);
            color: white; 
            border: none; 
            border-radius: 8px; 
            cursor: pointer;
            font-weight: 600;
            font-size: 14px;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(52, 152, 219, 0.3);
        }
        
        button:hover { 
            background: linear-gradient(135deg, #2980b9, #1f639a);
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(52, 152, 219, 0.4);
        }
        
        .mark-btn {
            background: linear-gradient(135deg, #27ae60, #2ecc71);
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            margin-top: 10px;
            display: block;
        }
        
        .mark-btn:hover {
            background: linear-gradient(135deg, #2ecc71, #27ae60);
        }
        
        .toggle-btn {
            padding: 10px 20px;
            background: linear-gradient(135deg, #27ae60, #2ecc71);
            color: white;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            margin-bottom: 10px;
            display: block;
        }
        
        .toggle-btn:hover {
            background: linear-gradient(135deg, #2ecc71, #27ae60);
        }

        .sig-btn {
            background: linear-gradient(135deg, #e67e22, #d35400);
            color: white;
            padding: 10px 15px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 12px;
            margin-bottom: 10px;
            display: block;
            transition: all 0.3s ease;
        }

        .sig-btn:hover {
            background: linear-gradient(135deg, #d35400, #e67e22);
            transform: translateY(-1px);
        }
        
        .site-section {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            margin-bottom: 30px;
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
            overflow: hidden;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .site-title {
            background: linear-gradient(135deg, #2c3e50, #34495e);
            color: white;
            padding: 20px 30px;
            font-size: 1.4rem;
            font-weight: 700;
            margin: 0;
            display: flex;
            align-items: center;
            gap: 15px;
        }
        
        .site-title::before {
            content: "🏫";
            font-size: 1.2em;
        }
        
        .class-title {
            background: linear-gradient(135deg, #3498db, #2980b9);
            color: white;
            padding: 15px 30px;
            font-size: 1.2rem;
            font-weight: 600;
            margin: 0;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .class-title::before {
            content: "📚";
            font-size: 1em;
        }
        
        .table-container {
            overflow-x: auto;
            padding: 0;
        }
        
        table { 
            width: 100%; 
            border-collapse: collapse; 
            font-size: 12px;
            background: white;
        }
        
        th, td { 
            border: 1px solid #e1e8ed; 
            padding: 8px 4px; 
            text-align: center;
            transition: all 0.3s ease;
        }
        
        th { 
            background: linear-gradient(135deg, #f8f9fa, #e9ecef);
            font-weight: 700;
            position: sticky; 
            top: 0;
            z-index: 10;
            color: #2c3e50;
            text-transform: uppercase;
            font-size: 10px;
            letter-spacing: 0.5px;
        }
        
        .learner-row {
            transition: all 0.3s ease;
        }
        
        .learner-row:nth-child(even) { 
            background: #f8f9fa;
        }
        
        .learner-row:hover {
            background: #e3f2fd !important;
            transform: scale(1.01);
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }
        
        .learner-details { 
            text-align: left; 
            white-space: nowrap;
            font-weight: 500;
            color: #2c3e50;
            font-size: 11px;
        }
        
        .complete { 
            background: linear-gradient(135deg, #27ae60, #2ecc71) !important;
            color: white;
            font-weight: bold;
            font-size: 10px;
            position: relative;
        }
        
        .complete::before {
            content: "✓";
            display: block;
            font-size: 12px;
        }
        
        .absent { 
            background: linear-gradient(135deg, #e74c3c, #c0392b) !important;
            color: white;
            font-weight: bold;
            font-size: 10px;
        }
        
        .absent::before {
            content: "✗";
            display: block;
            font-size: 12px;
        }
        
        .checkbox-cell input[type="checkbox"] {
            transform: scale(1.2);
            margin: 0;
        }
        
        .summary { 
            margin: 20px 0 0 0; 
            padding: 20px; 
            background: linear-gradient(135deg, #e8f5e8, #d4edda);
            border-radius: 10px;
            border-left: 5px solid #27ae60;
            box-shadow: 0 4px 15px rgba(39, 174, 96, 0.1);
        }
        
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        
        .summary-item {
            background: rgba(255, 255, 255, 0.7);
            padding: 12px;
            border-radius: 8px;
            text-align: center;
            border: 1px solid rgba(39, 174, 96, 0.2);
        }
        
        .summary-number {
            font-size: 1.4rem;
            font-weight: bold;
            color: #27ae60;
            display: block;
        }
        
        .summary-label {
            color: #2c3e50;
            font-size: 0.8rem;
            font-weight: 500;
            margin-top: 4px;
        }
        
        .poe-form {
            background: rgba(255, 255, 255, 0.95);
            padding: 25px;
            border-radius: 10px;
            margin-top: 20px;
            border: 1px solid #e1e8ed;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.05);
        }
        
        .poe-form h4 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 1.2rem;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .submitted-info {
            background: linear-gradient(135deg, #d4edda, #c3e6cb);
            padding: 12px;
            border-radius: 6px;
            margin-bottom: 15px;
            border-left: 4px solid #28a745;
            font-weight: 500;
            color: #155724;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #34495e;
            font-size: 0.95rem;
        }
        
        .signature-pad {
            border: 2px solid #e1e8ed;
            border-radius: 8px;
            background: white;
            margin-bottom: 10px;
            touch-action: none;
            width: 100%;
            max-width: 400px;
        }
        
        .clear-signature {
            background: #e74c3c;
            color: white;
            border: none;
            padding: 5px 10px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
            margin-right: 10px;
        }

        .clear-signature:hover {
            background: #c0392b;
        }
        
        .no-data { 
            text-align: center; 
            padding: 60px 20px;
            color: #7f8c8d;
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
        }
        
        .no-data h3 {
            font-size: 1.5rem;
            margin-bottom: 15px;
            color: #34495e;
        }
        
        .legend {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }
        
        .legend h4 {
            color: #2c3e50;
            margin-bottom: 15px;
            font-size: 1.1rem;
        }
        
        .legend-items {
            display: flex;
            gap: 20px;
            flex-wrap: wrap;
        }
        
        .legend-item {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 14px;
            color: #2c3e50;
        }
        
        .legend-color {
            width: 20px;
            height: 20px;
            border-radius: 4px;
            display: inline-block;
        }
        
        .tooltip {
            position: relative;
            cursor: help;
        }
        
        .tooltip:hover::after {
            content: attr(data-tooltip);
            position: absolute;
            bottom: 100%;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 10px;
            white-space: nowrap;
            z-index: 1000;
        }
        
        @media (max-width: 768px) {
            .container { padding: 10px; }
            h1 { font-size: 2rem; }
            .filter-group { display: block; margin-bottom: 15px; }
            .site-title, .class-title { font-size: 1.1rem; padding: 15px 20px; }
            th, td { padding: 6px 2px; font-size: 10px; }
            .signature-pad { max-width: 100%; }
        }
        
        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .site-section {
            animation: slideIn 0.6s ease-out;
        }
    </style>
</head>
<body>

<div class="container">
    <div class="header">
        <h1>📦 Enhanced Learner POE Submission Report</h1>
        <p class="subtitle">Comprehensive POE submission tracking and analytics</p>
    </div>

    <?php if (isset($_SESSION['success'])): ?>
        <div class="alert alert-success">
            <?php echo htmlspecialchars($_SESSION['success']); ?>
            <?php unset($_SESSION['success']); ?>
        </div>
    <?php endif; ?>
    <?php if (isset($_SESSION['error'])): ?>
        <div class="alert alert-error">
            <?php echo htmlspecialchars($_SESSION['error']); ?>
            <?php unset($_SESSION['error']); ?>
        </div>
    <?php endif; ?>

    <div class="filters">
        <h3>🔍 Filter Options</h3>
        <form method="GET">
            <div class="filter-group">
                <label class="filter-label" for="district">District</label>
                <select name="district" id="district" onchange="this.form.submit()">
                    <option value="">-- All Districts --</option>
                    <?php foreach ($districts as $district): ?>
                        <option value="<?php echo htmlspecialchars($district); ?>" <?php echo $district === $selectedDistrict ? 'selected' : ''; ?>>
                            <?php echo htmlspecialchars($district); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="filter-group">
                <label class="filter-label" for="site">Site</label>
                <select name="site" id="site">
                    <option value="">-- All Sites --</option>
                    <?php foreach ($sites as $site): ?>
                        <option value="<?php echo htmlspecialchars($site); ?>" <?php echo $site === $selectedSite ? 'selected' : ''; ?>>
                            <?php echo htmlspecialchars($site); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="filter-group">
                <label class="filter-label" for="class">Class</label>
                <select name="class" id="class" <?php echo empty($selectedSite) ? 'disabled' : ''; ?>>
                    <option value="">-- All Classes --</option>
                    <?php if (!empty($selectedSite)): ?>
                        <?php foreach ($classes as $c): ?>
                            <option value="<?php echo intval($c['classID']); ?>" <?php echo (!empty($selectedClass) && intval($c['classID']) === $selectedClass) ? 'selected' : ''; ?>>
                                <?php echo htmlspecialchars($c['className']); ?>
                            </option>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </select>
            </div>
            <div class="filter-group">
                <label class="filter-label" for="start_date">Start Date</label>
                <input type="date" name="start_date" id="start_date" value="<?php echo htmlspecialchars($startDate); ?>">
            </div>
            <div class="filter-group">
                <label class="filter-label" for="end_date">End Date</label>
                <input type="date" name="end_date" id="end_date" value="<?php echo htmlspecialchars($endDate); ?>">
            </div>
            <div class="filter-group">
                <label class="filter-label">&nbsp;</label>
                <button type="submit">📈 Generate Report</button>
            </div>
        </form>
    </div>

    <?php if (!empty($reportData)): ?>
        <div class="overall-summary">
            <h2>Overall POE Submission Summary</h2>
            <div class="overall-period">
                <strong>📅 Report Period:</strong> 
                <?php echo date('M d, Y', strtotime($startDate)); ?> to <?php echo date('M d, Y', strtotime($endDate)); ?>
                <?php if (!empty($selectedDistrict) || !empty($selectedSite)): ?>
                    <br><strong>📍 Filtered by:</strong> 
                    <?php if (!empty($selectedDistrict)): ?>District: <?php echo htmlspecialchars($selectedDistrict); ?><?php endif; ?>
                    <?php if (!empty($selectedSite)): ?><?php echo !empty($selectedDistrict) ? ' | ' : ''; ?>Site: <?php echo htmlspecialchars($selectedSite); ?><?php endif; ?>
                    <?php if (!empty($selectedClass)): ?> | Class: <?php echo htmlspecialchars(!empty($selectedClassName) ? $selectedClassName : (string)$selectedClass); ?><?php endif; ?>
                <?php endif; ?>
            </div>
            <div class="summary">
                <strong>Overall Summary:</strong> 
                <?php echo $overallTotalLearners; ?> learners enrolled across all classes
                <div class="summary-grid">
                    <div class="summary-item">
                        <span class="summary-number"><?php echo $overallTotalLearners; ?></span>
                        <span class="summary-label">Total Learners</span>
                    </div>
                    <div class="summary-item">
                        <span class="summary-number"><?php echo $overallPOEYes; ?> (<?php echo $overallPOERate; ?>%)</span>
                        <span class="summary-label">With POE Submission</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="legend">
            <h4>📋 Legend</h4>
            <div class="legend-items">
                <div class="legend-item">
                    <span class="legend-color complete"></span>
                    <span>POE Submitted (Yes)</span>
                </div>
                <div class="legend-item">
                    <span class="legend-color absent"></span>
                    <span>POE Not Submitted (No)</span>
                </div>
            </div>
        </div>

        <?php foreach ($reportData as $siteName => $siteData): ?>
            <div class="site-section">
                <h2 class="site-title">Site: <?php echo htmlspecialchars($siteName); ?> (District: <?php echo htmlspecialchars($siteData['district']); ?>)</h2>
                
                <?php foreach ($siteData['classes'] as $className => $classData): ?>
                    <?php
                    $fac = $classData['facilitator'];
                    $facName = isset($fac) ? trim($fac['firstName'] . ' ' . $fac['lastName']) : '';
                    $facPhone = isset($fac) ? ($fac['phoneNumber'] ?? 'N/A') : 'N/A';
                    $classID = $classData['classID'];
                    $facSigCanvasId = 'facilitatorSignature_' . $classID;
                    $repSigCanvasId = 'representativeSignature_' . $classID;
                    $facSigHiddenId = 'facilitator_signature_' . $classID;
                    $repSigHiddenId = 'representative_signature_' . $classID;
                    $facSigContainerId = 'fac-sig-' . $classID;
                    $repSigContainerId = 'rep-sig-' . $classID;
                    $facBtnId = 'fac-btn-' . $classID;
                    $repBtnId = 'rep-btn-' . $classID;

                    $submission = $classData['submission'];
                    $hasSubmission = $submission !== null;
                    $buttonText = $hasSubmission ? '💾 Update POE Submission' : '💾 Save POE Submission';
                    $facNameValue = $hasSubmission ? $submission['facilitator_full_name'] : $facName;
                    $repNameValue = $hasSubmission ? $submission['representative_full_name'] : '';
                    $facSigValue = $hasSubmission ? $submission['facilitator_signature'] : '';
                    $repSigValue = $hasSubmission ? $submission['representative_signature'] : '';
                    $facSigDisplay = $hasSubmission ? 'block' : 'none';
                    $repSigDisplay = $hasSubmission ? 'block' : 'none';
                    $facBtnText = $hasSubmission ? '🙈 Hide Signature' : '✍️ Draw Signature';
                    $repBtnText = $hasSubmission ? '🙈 Hide Signature' : '✍️ Draw Signature';
                    ?>
                    <h3 class="class-title">Class: <?php echo htmlspecialchars($className); ?>
                        <?php if (isset($classData['facilitator']) && $classData['facilitator'] !== null): ?>
                            (Facilitator: <?php echo htmlspecialchars($facName); ?> | <?php echo htmlspecialchars($facPhone); ?>)
                        <?php endif; ?>
                        <?php if ($classData['representative'] && $classData['representative'] !== 'N/A'): ?>
                            | Representative: <?php echo htmlspecialchars($classData['representative']); ?>
                        <?php endif; ?>
                    </h3>
                    
                    <button type="button" class="toggle-btn" data-classid="<?php echo $classID; ?>">👁️ Show All Learners</button>
                    
                    <form method="POST" id="mark-form-<?php echo $classID; ?>">
                        <input type="hidden" name="classID" value="<?php echo $classID; ?>">
                        <div class="table-container" id="table-<?php echo $classID; ?>" style="display: none;">
                            <table>
                                <thead>
                                    <tr>
                                        <th>Name</th>
                                        <th>Surname</th>
                                        <th>ID Number</th>
                                        <th>Phone</th>
                                        <th>POE Submission</th>
                                        <th>Mark Received</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($classData['learners'] as $learnerID => $learner): ?>
                                        <tr class="learner-row">
                                            <td class="learner-details"><?php echo htmlspecialchars($learner['name']); ?></td>
                                            <td class="learner-details"><?php echo htmlspecialchars($learner['surname']); ?></td>
                                            <td class="learner-details"><?php echo htmlspecialchars($learner['id_number']); ?></td>
                                            <td class="learner-details"><?php echo $learner['phone_number'] ? htmlspecialchars($learner['phone_number']) : 'N/A'; ?></td>
                                            
                                            <?php $status = $learner['materials']['POE Submission']; ?>
                                            <td class="<?php echo $status === 'Yes' ? 'complete' : 'absent'; ?>">
                                                <?php echo $status; ?>
                                            </td>
                                            <td class="checkbox-cell">
                                                <?php if ($status === 'No'): ?>
                                                    <input type="checkbox" name="received_learners[]" value="<?php echo htmlspecialchars($learner['id_number'] . '|' . $learner['name'] . ' ' . $learner['surname']); ?>">
                                                <?php endif; ?>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                        <button type="submit" name="mark_received" class="mark-btn">✅ Mark Selected as Received</button>
                    </form>
                    
                    <div class="summary">
                        <?php
                        $totalLearners = count($classData['learners']);
                        $classPOEYes = 0;
                        
                        foreach ($classData['learners'] as $learner) {
                            if ($learner['materials']['POE Submission'] === 'Yes') $classPOEYes++;
                        }
                        
                        $classPOERate = $totalLearners > 0 ? round(($classPOEYes / $totalLearners) * 100, 1) : 0;
                        ?>
                        <strong>Class Summary:</strong> 
                        <?php echo $totalLearners; ?> learners enrolled
                        <?php if ($classData['representative'] && $classData['representative'] !== 'N/A'): ?>
                            | Representative: <?php echo htmlspecialchars($classData['representative']); ?>
                        <?php endif; ?>
                        <div class="summary-grid">
                            <div class="summary-item">
                                <span class="summary-number"><?php echo $totalLearners; ?></span>
                                <span class="summary-label">Total Learners</span>
                            </div>
                            <div class="summary-item">
                                <span class="summary-number"><?php echo $classPOEYes; ?> (<?php echo $classPOERate; ?>%)</span>
                                <span class="summary-label">With POE Submission</span>
                            </div>
                        </div>
                    </div>

                    <!-- POE Submission Form -->
                    <div class="poe-form">
                        <h4>📝 Record POE Submission</h4>
                        <?php if ($hasSubmission): ?>
                            <div class="submitted-info">
                                Last submitted on <?php echo date('M d, Y H:i', strtotime($submission['created_at'])); ?>
                            </div>
                        <?php endif; ?>
                        <form method="POST">
                            <input type="hidden" name="classID" value="<?php echo $classID; ?>">
                            <input type="hidden" name="description" value="POE Submission">
                            <input type="hidden" name="quantity" value="<?php echo $classPOEYes; ?>">
                            <input type="hidden" name="submission_id" value="<?php echo $hasSubmission ? $submission['id'] : ''; ?>">
                            
                            <div class="form-group">
                                <label for="facilitator_full_name_<?php echo $classID; ?>">Facilitator Full Name</label>
                                <input type="text" id="facilitator_full_name_<?php echo $classID; ?>" name="facilitator_full_name" value="<?php echo htmlspecialchars($facNameValue); ?>" required>
                            </div>
                            
                            <div class="form-group">
                                <label for="representative_full_name_<?php echo $classID; ?>">Representative Full Name</label>
                                <input type="text" id="representative_full_name_<?php echo $classID; ?>" name="representative_full_name" value="<?php echo htmlspecialchars($repNameValue); ?>" placeholder="Enter representative name" required>
                            </div>
                            
                            <div class="form-group">
                                <label>Facilitator Signature</label>
                                <button type="button" class="sig-btn" id="<?php echo $facBtnId; ?>" onclick="toggleSignature('<?php echo $facSigContainerId; ?>')"><?php echo $facBtnText; ?></button>
                                <div id="<?php echo $facSigContainerId; ?>" style="display: <?php echo $facSigDisplay; ?>;">
                                    <canvas id="<?php echo $facSigCanvasId; ?>" class="signature-pad" width="400" height="200"></canvas>
                                    <br>
                                    <button type="button" class="clear-signature" onclick="clearSignature('<?php echo $facSigCanvasId; ?>', '<?php echo $facSigHiddenId; ?>')">Clear Signature</button>
                                    <input type="hidden" id="<?php echo $facSigHiddenId; ?>" name="facilitator_signature" value="<?php echo htmlspecialchars($facSigValue); ?>" required>
                                </div>
                            </div>
                            
                            <div class="form-group">
                                <label>Representative Signature</label>
                                <button type="button" class="sig-btn" id="<?php echo $repBtnId; ?>" onclick="toggleSignature('<?php echo $repSigContainerId; ?>')"><?php echo $repBtnText; ?></button>
                                <div id="<?php echo $repSigContainerId; ?>" style="display: <?php echo $repSigDisplay; ?>;">
                                    <canvas id="<?php echo $repSigCanvasId; ?>" class="signature-pad" width="400" height="200"></canvas>
                                    <br>
                                    <button type="button" class="clear-signature" onclick="clearSignature('<?php echo $repSigCanvasId; ?>', '<?php echo $repSigHiddenId; ?>')">Clear Signature</button>
                                    <input type="hidden" id="<?php echo $repSigHiddenId; ?>" name="representative_signature" value="<?php echo htmlspecialchars($repSigValue); ?>" required>
                                </div>
                            </div>
                            
                            <button type="submit" name="save_poe"><?php echo $buttonText; ?></button>
                        </form>
                    </div>
                <?php endforeach; ?>
            </div>
        <?php endforeach; ?>
    <?php else: ?>
        <div class="no-data">
            <h3>No learner data found for the selected criteria.</h3>
            <p>Please adjust your filters and try again.</p>
            <?php if (isset($result) && $result->num_rows === 0): ?>
                <p>Debug: No records returned. Check database or filters.</p>
            <?php endif; ?>
        </div>
    <?php endif; ?>
</div>

<script>
    // Enhanced Signature Pad Implementation
    function setupSignaturePad(canvasId, hiddenId, existingSig = '') {
        const canvas = document.getElementById(canvasId);
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        let isDrawing = false;

        ctx.strokeStyle = '#000';
        ctx.lineWidth = 2;
        ctx.lineCap = 'round';

        function getMousePos(e) {
            const rect = canvas.getBoundingClientRect();
            return {
                x: e.clientX - rect.left,
                y: e.clientY - rect.top
            };
        }

        function startDrawing(e) {
            isDrawing = true;
            const pos = getMousePos(e);
            ctx.beginPath();
            ctx.moveTo(pos.x, pos.y);
        }

        function draw(e) {
            if (!isDrawing) return;
            e.preventDefault();
            const pos = getMousePos(e);
            ctx.lineTo(pos.x, pos.y);
            ctx.stroke();
        }

        function stopDrawing() {
            if (isDrawing) {
                isDrawing = false;
                document.getElementById(hiddenId).value = canvas.toDataURL();
            }
        }

        canvas.addEventListener('mousedown', startDrawing);
        canvas.addEventListener('mousemove', draw);
        canvas.addEventListener('mouseup', stopDrawing);
        canvas.addEventListener('mouseout', stopDrawing);

        // Touch support
        canvas.addEventListener('touchstart', (e) => {
            e.preventDefault();
            const touch = e.touches[0];
            const mouseEvent = new MouseEvent('mousedown', {
                clientX: touch.clientX,
                clientY: touch.clientY
            });
            canvas.dispatchEvent(mouseEvent);
        });

        canvas.addEventListener('touchmove', (e) => {
            e.preventDefault();
            const touch = e.touches[0];
            const mouseEvent = new MouseEvent('mousemove', {
                clientX: touch.clientX,
                clientY: touch.clientY
            });
            canvas.dispatchEvent(mouseEvent);
        });

        canvas.addEventListener('touchend', (e) => {
            e.preventDefault();
            const mouseEvent = new MouseEvent('mouseup', {});
            canvas.dispatchEvent(mouseEvent);
        });

        // Load existing signature if provided
        if (existingSig) {
            const img = new Image();
            img.onload = function() {
                ctx.clearRect(0, 0, canvas.width, canvas.height);
                ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            };
            img.src = existingSig;
        }
    }

    function clearSignature(canvasId, hiddenId) {
        const canvas = document.getElementById(canvasId);
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        document.getElementById(hiddenId).value = '';
    }

    function toggleSignature(containerId) {
        const container = document.getElementById(containerId);
        const btnId = containerId.replace(/-(sig|rep)-/, '-btn-');
        const btn = document.getElementById(btnId);
        if (container.style.display === 'none' || container.style.display === '') {
            container.style.display = 'block';
            btn.innerHTML = '🙈 Hide Signature';
        } else {
            container.style.display = 'none';
            btn.innerHTML = '✍️ Draw Signature';
        }
    }

    // Initialize signature pads for all classes
    <?php foreach ($reportData as $siteName => $siteData): ?>
        <?php foreach ($siteData['classes'] as $className => $classData): ?>
            <?php
            $classID = $classData['classID'];
            $facSigCanvasId = 'facilitatorSignature_' . $classID;
            $repSigCanvasId = 'representativeSignature_' . $classID;
            $facSigHiddenId = 'facilitator_signature_' . $classID;
            $repSigHiddenId = 'representative_signature_' . $classID;
            $submission = $classData['submission'];
            $facSigValueJS = isset($submission) ? ($submission['facilitator_signature'] ?? '') : '';
            $repSigValueJS = isset($submission) ? ($submission['representative_signature'] ?? '') : '';
            ?>
            setupSignaturePad('<?php echo $facSigCanvasId; ?>', '<?php echo $facSigHiddenId; ?>', <?php echo json_encode($facSigValueJS); ?>);
            setupSignaturePad('<?php echo $repSigCanvasId; ?>', '<?php echo $repSigHiddenId; ?>', <?php echo json_encode($repSigValueJS); ?>);
        <?php endforeach; ?>
    <?php endforeach; ?>

    // Toggle learner table visibility and show all
    document.querySelectorAll('.toggle-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const classId = this.dataset.classid;
            const table = document.getElementById('table-' + classId);
            const rows = table.querySelectorAll('tbody tr');

            if (table.style.display === 'none') {
                table.style.display = 'block';
                rows.forEach(row => {
                    row.style.display = 'table-row';
                });
                this.innerHTML = '🙈 Hide Learners';
            } else {
                table.style.display = 'none';
                this.innerHTML = '👁️ Show All Learners';
            }
        });
    });
</script>

<?php $conn->close(); ?>

</body>
</html>
<?php ob_end_flush(); ?>
