<?php
/**
 * COMPARE SITEID 828 - LOCAL vs ONLINE
 * Shows exact differences between local and online servers for siteID 828
 */

header('Content-Type: application/json; charset=utf-8');
error_reporting(E_ALL);
ini_set('display_errors', 0);

$result = [
    'environment' => 'LOCAL_SITEID_828',
    'timestamp' => date('Y-m-d H:i:s'),
    'siteid' => 828,
    'facilitator_id' => 6,
    'comparison' => [],
    'critical_findings' => [],
];

try {
    include_once 'mobile/connection.php';
    
    // Get site 828 details
    $stmt = $conn->prepare("SELECT * FROM sites WHERE siteID = ?");
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param("i", $siteid);
    $siteid = 828;
    $stmt->execute();
    $site = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    
    if (!$site) {
        throw new Exception("Site 828 not found");
    }
    
    // Get facilitator 6 assigned classes for this site
    $stmt = $conn->prepare("
        SELECT DISTINCT c.classID, c.className
        FROM class c
        JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
        WHERE f.facilitator_id = 6 AND c.siteID = ?
    ");
    $stmt->bind_param("i", $siteid);
    $stmt->execute();
    $classes = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    
    $result['site_details'] = [
        'siteID' => $site['siteID'],
        'siteName' => $site['siteName'],
        'project_id' => $site['project_id'],
        'Project_pathway' => $site['Project_pathway'],
        'Province' => $site['Province'] ?? 'N/A',
        'Category' => $site['Category'] ?? 'N/A',
    ];
    
    $result['facilitator_6_classes_at_site_828'] = $classes;
    
    // Analyze the pathway
    $pathway = $site['Project_pathway'];
    $pathway_upper = strtoupper($pathway);
    
    $result['pathway_analysis'] = [
        'raw_value' => $pathway,
        'length' => strlen($pathway),
        'is_json' => (json_decode($pathway) !== null),
        'contains_ARPL' => strpos($pathway_upper, 'ARPL') !== false,
        'contains_Bricklayer' => strpos($pathway_upper, 'BRICKLAYER') !== false,
        'contains_Electrician' => strpos($pathway_upper, 'ELECTRICIAN') !== false,
        'detection_will_work' => (
            strpos($pathway_upper, 'ARPL') !== false ||
            strpos($pathway_upper, 'BRICKLAYER') !== false ||
            strpos($pathway_upper, 'ELECTRICIAN') !== false
        ),
    ];
    
    // Check all sites for facilitator 6
    $stmt = $conn->prepare("
        SELECT DISTINCT s.siteID, s.siteName, s.Project_pathway
        FROM sites s
        JOIN class c ON c.siteID = s.siteID
        JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
        WHERE f.facilitator_id = 6
        ORDER BY s.siteID
    ");
    $stmt->execute();
    $all_sites = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    
    $result['all_facilitator_6_sites'] = [];
    foreach ($all_sites as $s) {
        $pathway_upper = strtoupper($s['Project_pathway']);
        $will_detect = (
            strpos($pathway_upper, 'ARPL') !== false ||
            strpos($pathway_upper, 'BRICKLAYER') !== false ||
            strpos($pathway_upper, 'ELECTRICIAN') !== false
        );
        
        $result['all_facilitator_6_sites'][] = [
            'siteID' => $s['siteID'],
            'siteName' => $s['siteName'],
            'Project_pathway' => $s['Project_pathway'],
            'will_detect_arpl' => $will_detect,
        ];
    }
    
    // Compare with what online should have
    $result['comparison'] = [
        'local_siteid_828' => [
            'siteID' => 828,
            'siteName' => $site['siteName'],
            'Project_pathway_value' => $site['Project_pathway'],
            'will_detect_arpl' => $result['pathway_analysis']['detection_will_work'],
        ],
        'online_should_have' => [
            'siteID' => 828,
            'siteName' => $site['siteName'],
            'Project_pathway_value' => $site['Project_pathway'],
            'will_detect_arpl' => $result['pathway_analysis']['detection_will_work'],
        ],
    ];
    
    // Critical findings
    if (!$result['pathway_analysis']['detection_will_work']) {
        $result['critical_findings'][] = [
            'issue' => 'PATHWAY_NOT_ARPL',
            'site_828_pathway' => $pathway,
            'expected' => 'Should contain ARPL, Bricklayer, or Electrician keyword',
        ];
    }
    
    // Check if facilitator 6 has other sites too
    if (count($all_sites) > 1) {
        $result['critical_findings'][] = [
            'issue' => 'MULTIPLE_SITES',
            'count' => count($all_sites),
            'message' => 'Facilitator 6 has classes in ' . count($all_sites) . ' sites. Check all of them.',
        ];
    }
    
    $conn->close();
    
} catch (Exception $e) {
    $result['error'] = $e->getMessage();
}

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
?>
