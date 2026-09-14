<?php
/**
 * ARPL ASSESSOR - LOCAL vs ONLINE COMPARISON SCRIPT
 * 
 * This script compares what works locally with what's on the online server
 * to identify exactly what's missing or different
 * 
 * Run this on BOTH servers to get a detailed comparison
 */

header('Content-Type: application/json; charset=utf-8');

$facilitator_id = 6;
$environment = strpos($_SERVER['HTTP_HOST'], 'localhost') !== false || strpos($_SERVER['HTTP_HOST'], '192.168') !== false ? 'LOCAL' : 'ONLINE';

$comparison = [
    'environment' => $environment,
    'server_info' => [
        'host' => $_SERVER['HTTP_HOST'],
        'php_version' => phpversion(),
        'mysql_version' => null,
        'server_software' => $_SERVER['SERVER_SOFTWARE'],
        'timestamp' => date('Y-m-d H:i:s'),
    ],
    'database_check' => [],
    'facilitator_check' => [],
    'role_detection' => [],
    'get_classes_check' => [],
    'pathway_detection' => [],
    'connection_info' => [],
];

// ============================================================
// 1. DATABASE CONNECTION CHECK
// ============================================================
try {
    include_once 'connection.php';
    
    $comparison['connection_info'] = [
        'status' => 'Connected',
        'host' => $servername,
        'database' => $dbname,
        'charset' => $conn->character_set_name(),
    ];
    
    // Get MySQL version
    $result = $conn->query("SELECT VERSION() as version");
    if ($result) {
        $row = $result->fetch_assoc();
        $comparison['server_info']['mysql_version'] = $row['version'];
    }
    
} catch (Exception $e) {
    $comparison['connection_info'] = [
        'status' => 'ERROR',
        'error' => $e->getMessage(),
    ];
    echo json_encode($comparison);
    exit;
}

// ============================================================
// 2. FACILITATOR CHECK
// ============================================================
$stmt = $conn->prepare("
    SELECT 
        facilitator_id,
        firstName,
        lastName,
        role,
        classID,
        email
    FROM facilitator 
    WHERE facilitator_id = ?
");
$stmt->bind_param("i", $facilitator_id);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    $comparison['facilitator_check'] = [
        'found' => true,
        'facilitator_id' => $row['facilitator_id'],
        'name' => $row['firstName'] . ' ' . $row['lastName'],
        'role_in_database' => $row['role'],
        'role_trimmed' => trim($row['role']),
        'role_lowercase' => strtolower(trim($row['role'])),
        'classID' => $row['classID'],
        'email' => $row['email'],
    ];
} else {
    $comparison['facilitator_check'] = ['found' => false];
}
$stmt->close();

// ============================================================
// 3. ROLE DETECTION - TEST DIFFERENT METHODS
// ============================================================
if ($comparison['facilitator_check']['found']) {
    $dbRole = $comparison['facilitator_check']['role_in_database'];
    $dbRoleTrimmed = strtolower(trim($dbRole));
    
    $comparison['role_detection'] = [
        'raw_role' => $dbRole,
        'trimmed' => trim($dbRole),
        'lowercase' => $dbRoleTrimmed,
        'tests' => [
            'exact_match_lowercase_assessor' => ($dbRoleTrimmed === 'assessor'),
            'exact_match_lowercase_arpl_assessor' => ($dbRoleTrimmed === 'arpl_assessor'),
            'exact_match_lowercase_moderator' => ($dbRoleTrimmed === 'moderator'),
            'contains_arpl' => strpos($dbRoleTrimmed, 'arpl') !== false,
            'contains_assessor' => strpos($dbRoleTrimmed, 'assessor') !== false,
            'contains_arpl_and_assessor' => (strpos($dbRoleTrimmed, 'arpl') !== false && strpos($dbRoleTrimmed, 'assessor') !== false),
        ],
        'detected_role' => (
            (strpos($dbRoleTrimmed, 'arpl') !== false && strpos($dbRoleTrimmed, 'assessor') !== false) ? 'arpl_assessor' :
            ($dbRoleTrimmed === 'assessor' ? 'assessor' :
            ($dbRoleTrimmed === 'moderator' ? 'Moderator' : 'facilitator'))
        ),
    ];
}

// ============================================================
// 4. GET_CLASSES CHECK - RESPONSE STRUCTURE
// ============================================================
$stmt = $conn->prepare("
    SELECT 
        c.classID,
        c.className,
        c.siteID,
        c.numberOfLearners,
        c.startDate,
        c.endDate,
        s.project_id, 
        s.Project_pathway
    FROM class c
    JOIN sites s ON s.siteID = c.siteID
    JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
    WHERE f.facilitator_id = ?
    ORDER BY c.className
");
$stmt->bind_param("i", $facilitator_id);
$stmt->execute();
$result = $stmt->get_result();

$classes = [];
while ($row = $result->fetch_assoc()) {
    $classes[] = $row;
}
$stmt->close();

if (!empty($classes)) {
    $firstClass = $classes[0];
    
    $comparison['get_classes_check'] = [
        'total_classes' => count($classes),
        'query_status' => 'SUCCESS',
        'first_class_structure' => [
            'classID' => $firstClass['classID'],
            'className' => $firstClass['className'],
            'siteID' => $firstClass['siteID'],
            'numberOfLearners' => $firstClass['numberOfLearners'],
            'project_id' => $firstClass['project_id'],
            'Project_pathway_exists' => isset($firstClass['Project_pathway']),
            'Project_pathway_value' => $firstClass['Project_pathway'],
            'Project_pathway_length' => strlen($firstClass['Project_pathway'] ?? ''),
        ],
        'all_columns_present' => [
            'classID' => isset($firstClass['classID']),
            'className' => isset($firstClass['className']),
            'siteID' => isset($firstClass['siteID']),
            'numberOfLearners' => isset($firstClass['numberOfLearners']),
            'project_id' => isset($firstClass['project_id']),
            'Project_pathway' => isset($firstClass['Project_pathway']),
            'instructorID' => isset($firstClass['instructorID']),
            'startDate' => isset($firstClass['startDate']),
            'endDate' => isset($firstClass['endDate']),
            'contact_hours' => isset($firstClass['contact_hours']),
        ],
    ];
} else {
    $comparison['get_classes_check'] = [
        'total_classes' => 0,
        'query_status' => 'NO_CLASSES_FOUND',
    ];
}

// ============================================================
// 5. PATHWAY DETECTION
// ============================================================
if (!empty($classes) && isset($classes[0]['Project_pathway'])) {
    $pathway = $classes[0]['Project_pathway'];
    $pathwayUpper = strtoupper($pathway);
    
    $comparison['pathway_detection'] = [
        'raw_pathway' => $pathway,
        'length' => strlen($pathway),
        'is_json' => (json_decode($pathway) !== null),
        'json_decode_result' => json_decode($pathway, true),
        'uppercase_version' => substr($pathwayUpper, 0, 100) . '...',
        'detection_tests' => [
            'contains_ARPL' => strpos($pathway, 'ARPL') !== false,
            'contains_arpl' => strpos($pathway, 'arpl') !== false,
            'contains_ARPL_uppercase' => strpos($pathwayUpper, 'ARPL') !== false,
            'contains_BRICKLAYER' => strpos($pathway, 'BRICKLAYER') !== false,
            'contains_Bricklayer' => strpos($pathway, 'Bricklayer') !== false,
            'contains_TYPE' => strpos($pathway, '"type"') !== false,
            'contains_type' => strpos($pathway, '"type"') !== false,
        ],
        'will_detect_as_arpl' => (strpos($pathwayUpper, 'ARPL') !== false || strpos($pathwayUpper, 'BRICKLAYER') !== false),
    ];
} else {
    $comparison['pathway_detection'] = ['status' => 'NO_PATHWAY_DATA'];
}

// ============================================================
// 6. TABLE STRUCTURE CHECK
// ============================================================
$tables_to_check = ['facilitator', 'class', 'sites', 'project'];
$comparison['table_structure'] = [];

foreach ($tables_to_check as $table) {
    $result = $conn->query("DESCRIBE $table");
    $columns = [];
    while ($row = $result->fetch_assoc()) {
        $columns[] = [
            'name' => $row['Field'],
            'type' => $row['Type'],
            'null' => $row['Null'],
            'key' => $row['Key'],
        ];
    }
    $comparison['table_structure'][$table] = $columns;
}

// ============================================================
// 7. CRITICAL COMPARISON POINTS
// ============================================================
$comparison['critical_issues'] = [];

// Check 1: Role detection
if ($comparison['role_detection']['detected_role'] !== 'arpl_assessor') {
    $comparison['critical_issues'][] = [
        'issue' => 'ROLE_NOT_DETECTED_AS_ARPL',
        'expected' => 'arpl_assessor',
        'actual' => $comparison['role_detection']['detected_role'],
        'severity' => 'CRITICAL',
        'solution' => 'Role in database might be different format. Check: ' . json_encode($comparison['role_detection']['tests']),
    ];
}

// Check 2: Project_pathway column exists
if (!$comparison['get_classes_check']['all_columns_present']['Project_pathway'] ?? false) {
    $comparison['critical_issues'][] = [
        'issue' => 'PROJECT_PATHWAY_COLUMN_MISSING',
        'expected' => 'Project_pathway column in response',
        'actual' => 'Column not found',
        'severity' => 'CRITICAL',
        'solution' => 'Update get_classes.php query to include Project_pathway from sites table',
    ];
}

// Check 3: Pathway detection
if ($comparison['pathway_detection']['will_detect_as_arpl'] ?? false === false) {
    $comparison['critical_issues'][] = [
        'issue' => 'PATHWAY_NOT_DETECTING_ARPL',
        'expected' => 'Pathway should contain ARPL or trade name',
        'actual' => 'Pathway: ' . ($comparison['pathway_detection']['raw_pathway'] ?? 'NONE'),
        'severity' => 'CRITICAL',
        'solution' => 'Check sites.Project_pathway data in database',
    ];
}

$conn->close();

// ============================================================
// OUTPUT COMPARISON
// ============================================================
echo json_encode($comparison, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
?>
