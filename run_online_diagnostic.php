<?php
/**
 * CRITICAL DIAGNOSTIC FOR ARPL ASSESSOR ONLINE ISSUE
 * 
 * This script will be executed to check what's causing the ARPL menu
 * to not appear when facilitator 6 logs in on the ONLINE server
 * 
 * Key Questions to Answer:
 * 1. Is facilitator 6 in the database?
 * 2. What role does facilitator 6 have?
 * 3. What classID(s) is facilitator 6 assigned to?
 * 4. Does that classID's site have ARPL pathway data?
 * 5. Is the Project_pathway column being returned by get_classes.php?
 */

header('Content-Type: application/json; charset=utf-8');

$result = [
    'timestamp' => date('Y-m-d H:i:s'),
    'server' => $_SERVER['HTTP_HOST'],
    'environment' => strpos($_SERVER['HTTP_HOST'], 'localhost') !== false || strpos($_SERVER['HTTP_HOST'], '192.168') !== false ? 'LOCAL' : 'ONLINE',
];

try {
    // Load database connection
    include_once 'mobile/connection.php';
    
    $facilitator_id = 6;
    
    // ============================================================
    // STEP 1: CHECK IF FACILITATOR 6 EXISTS AND GET THEIR ROLE
    // ============================================================
    $result['step_1_facilitator_exists'] = [];
    
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
    $res = $stmt->get_result();
    
    if ($row = $res->fetch_assoc()) {
        $result['step_1_facilitator_exists'] = [
            'found' => true,
            'facilitator_id' => $row['facilitator_id'],
            'name' => $row['firstName'] . ' ' . $row['lastName'],
            'role_raw' => $row['role'],
            'role_trimmed' => trim($row['role']),
            'role_lowercase' => strtolower(trim($row['role'])),
            'classID_raw' => $row['classID'],
            'email' => $row['email'],
        ];
        
        // Parse classID if it's comma-separated
        $classIds = array_map('trim', explode(',', $row['classID']));
        $result['step_1_facilitator_exists']['classIDs_array'] = $classIds;
        $result['step_1_facilitator_exists']['number_of_classes'] = count($classIds);
    } else {
        $result['step_1_facilitator_exists']['found'] = false;
        $result['error'] = 'FACILITATOR_6_NOT_FOUND';
    }
    $stmt->close();
    
    if (!$result['step_1_facilitator_exists']['found']) {
        echo json_encode($result, JSON_PRETTY_PRINT);
        exit;
    }
    
    // ============================================================
    // STEP 2: TEST ROLE DETECTION LOGIC
    // ============================================================
    $result['step_2_role_detection'] = [];
    $dbRole = $result['step_1_facilitator_exists']['role_raw'];
    $dbRoleTrimmed = strtolower(trim($dbRole));
    
    // This is the EXACT logic from mobile/login.php line 225
    $detected_role = 'facilitator'; // default
    
    if (strpos($dbRoleTrimmed, 'arpl') !== false && strpos($dbRoleTrimmed, 'assessor') !== false) {
        $detected_role = 'arpl_assessor';
    } elseif ($dbRoleTrimmed === 'assessor') {
        $detected_role = 'assessor';
    } elseif ($dbRoleTrimmed === 'moderator') {
        $detected_role = 'Moderator';
    }
    
    $result['step_2_role_detection'] = [
        'role_from_db' => $dbRole,
        'login_php_logic_result' => $detected_role,
        'will_show_arpl_menu' => ($detected_role === 'arpl_assessor'),
        'tests' => [
            'contains_both_arpl_and_assessor' => (strpos($dbRoleTrimmed, 'arpl') !== false && strpos($dbRoleTrimmed, 'assessor') !== false),
            'exact_match_assessor' => ($dbRoleTrimmed === 'assessor'),
            'exact_match_moderator' => ($dbRoleTrimmed === 'moderator'),
        ],
    ];
    
    // ============================================================
    // STEP 3: GET CLASSES FOR THIS FACILITATOR
    // ============================================================
    $result['step_3_classes'] = [];
    
    $classIds = $result['step_1_facilitator_exists']['classIDs_array'];
    
    if (!empty($classIds)) {
        $placeholders = implode(',', array_fill(0, count($classIds), '?'));
        
        $stmt = $conn->prepare("
            SELECT 
                c.classID,
                c.className,
                c.siteID,
                c.numberOfLearners,
                c.startDate,
                c.endDate,
                s.siteName,
                s.Project_pathway,
                s.project_id
            FROM class c
            LEFT JOIN sites s ON c.siteID = s.siteID
            WHERE c.classID IN ($placeholders)
            ORDER BY c.classID
        ");
        
        // Bind parameters
        $types = str_repeat('i', count($classIds));
        $stmt->bind_param($types, ...$classIds);
        $stmt->execute();
        $res = $stmt->get_result();
        
        $classes = [];
        while ($row = $res->fetch_assoc()) {
            $classes[] = $row;
        }
        $stmt->close();
        
        $result['step_3_classes'] = [
            'count' => count($classes),
            'classes' => $classes,
        ];
    } else {
        $result['step_3_classes'] = ['count' => 0, 'classes' => []];
    }
    
    // ============================================================
    // STEP 4: PATHWAY DETECTION FOR EACH CLASS
    // ============================================================
    $result['step_4_pathway_detection'] = [];
    
    foreach ($result['step_3_classes']['classes'] as $class) {
        $pathway = $class['Project_pathway'] ?? '';
        $pathwayUpper = strtoupper($pathway);
        
        $will_detect_as_arpl = (
            strpos($pathwayUpper, 'ARPL') !== false ||
            strpos($pathwayUpper, 'ELECTRICIAN') !== false ||
            strpos($pathwayUpper, 'BRICKLAYING') !== false ||
            strpos($pathwayUpper, 'BRICKLAYER') !== false ||
            strpos($pathwayUpper, 'PLUMBING') !== false ||
            strpos($pathwayUpper, 'PLUMBER') !== false
        );
        
        $result['step_4_pathway_detection'][] = [
            'classID' => $class['classID'],
            'className' => $class['className'],
            'siteID' => $class['siteID'],
            'siteName' => $class['siteName'],
            'pathway_raw' => substr($pathway, 0, 100),
            'pathway_length' => strlen($pathway),
            'pathway_null_or_empty' => empty($pathway),
            'will_detect_as_arpl' => $will_detect_as_arpl,
        ];
    }
    
    // ============================================================
    // STEP 5: COMPARISON WITH LOCAL KNOWN WORKING STATE
    // ============================================================
    $result['step_5_comparison_with_local'] = [
        'local_working_state' => [
            'facilitator_id' => 118,
            'role' => 'arpl_Assessor',
            'classID' => 797,
            'site_id' => 828,
            'site_name' => 'NDENGEZI',
            'pathway_contains' => 'ARPL Electrician',
        ],
        'online_actual_state' => [
            'facilitator_id' => $result['step_1_facilitator_exists']['facilitator_id'],
            'name' => $result['step_1_facilitator_exists']['name'],
            'role' => $result['step_1_facilitator_exists']['role_raw'],
            'detected_role_will_be' => $result['step_2_role_detection']['login_php_logic_result'],
            'classIDs' => implode(', ', $result['step_1_facilitator_exists']['classIDs_array']),
            'number_of_classes' => $result['step_1_facilitator_exists']['number_of_classes'],
            'has_arpl_class' => count(array_filter($result['step_4_pathway_detection'], fn($c) => $c['will_detect_as_arpl'])) > 0,
        ],
    ];
    
    // ============================================================
    // STEP 6: DIAGNOSIS AND RECOMMENDATIONS
    // ============================================================
    $result['step_6_diagnosis'] = [];
    
    $issues = [];
    
    // Issue 1: Role detection
    if ($result['step_2_role_detection']['login_php_logic_result'] !== 'arpl_assessor') {
        $issues[] = [
            'type' => 'ROLE_MISMATCH',
            'severity' => 'CRITICAL',
            'message' => 'Facilitator role is "' . $result['step_1_facilitator_exists']['role_raw'] . '" but login.php expects "arpl_Assessor" or similar',
            'expected' => 'Role containing both "arpl" and "assessor"',
            'actual' => $result['step_1_facilitator_exists']['role_raw'],
        ];
    }
    
    // Issue 2: No classes assigned
    if ($result['step_3_classes']['count'] === 0) {
        $issues[] = [
            'type' => 'NO_CLASSES',
            'severity' => 'CRITICAL',
            'message' => 'Facilitator 6 has no classes assigned',
            'expected' => 'At least one class with ARPL pathway',
            'actual' => 'No classes found',
        ];
    }
    
    // Issue 3: No ARPL classes
    $arpl_classes = array_filter($result['step_4_pathway_detection'], fn($c) => $c['will_detect_as_arpl']);
    if (empty($arpl_classes)) {
        $issues[] = [
            'type' => 'NO_ARPL_PATHWAY',
            'severity' => 'CRITICAL',
            'message' => 'Facilitator has classes but none are ARPL',
            'expected' => 'At least one class with ARPL pathway data',
            'actual' => count($result['step_4_pathway_detection']) . ' classes, none with ARPL pathway',
        ];
    }
    
    // Issue 4: Project_pathway column missing
    $has_pathway_column = !empty($result['step_3_classes']['classes']) && isset($result['step_3_classes']['classes'][0]['Project_pathway']);
    if (!$has_pathway_column && !empty($result['step_3_classes']['classes'])) {
        $issues[] = [
            'type' => 'PROJECT_PATHWAY_COLUMN_MISSING',
            'severity' => 'HIGH',
            'message' => 'Project_pathway column not in query response',
            'expected' => 'Project_pathway should be returned from sites table',
            'actual' => 'Column missing from response',
        ];
    }
    
    $result['step_6_diagnosis']['issues'] = $issues;
    $result['step_6_diagnosis']['summary'] = empty($issues) ? 'NO ISSUES - SHOULD WORK' : (count($issues) . ' issues found');
    
    // ============================================================
    // FINAL VERDICT
    // ============================================================
    $result['final_verdict'] = [
        'will_arpl_menu_appear' => (
            $result['step_2_role_detection']['will_show_arpl_menu'] &&
            !empty($arpl_classes)
        ),
        'root_cause' => empty($issues) ? 'Unknown - data looks correct' : $issues[0]['type'],
        'next_action' => empty($issues) 
            ? 'Clear app cache and reinstall APK - database appears correct'
            : ('Fix: ' . $issues[0]['type']),
    ];
    
    $conn->close();
    
} catch (Exception $e) {
    $result['error'] = $e->getMessage();
    $result['trace'] = $e->getTraceAsString();
}

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
?>
