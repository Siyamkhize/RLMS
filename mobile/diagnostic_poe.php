<?php
/**
 * Comprehensive Diagnostic Script for POE Data Chain
 * Save as mobile/diagnostic_poe.php
 * Usage: diagnostic_poe.php?learnerID=11560
 */

header("Content-Type: text/html; charset=UTF-8");
include('connection.php');

$learnerID = isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0;

echo "<html><head><title>POE Diagnostic - Learner $learnerID</title>";
echo "<style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; padding: 20px; background: #f0f2f5; color: #333; }
    .container { max-width: 1000px; margin: auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
    h1 { color: #1a73e8; border-bottom: 3px solid #1a73e8; padding-bottom: 10px; margin-top: 0; }
    .step { margin-bottom: 20px; padding: 15px; border-radius: 8px; border-left: 5px solid #ccc; background: #fafafa; }
    .step-header { font-weight: bold; font-size: 1.1em; margin-bottom: 10px; display: flex; align-items: center; }
    .status-ok { border-left-color: #28a745; background: #f8fff9; }
    .status-fail { border-left-color: #dc3545; background: #fff8f8; }
    .status-warn { border-left-color: #ffc107; background: #fffdf5; }
    .badge { padding: 4px 8px; border-radius: 4px; font-size: 0.8em; margin-right: 10px; color: white; text-transform: uppercase; }
    .badge-ok { background: #28a745; }
    .badge-fail { background: #dc3545; }
    .badge-warn { background: #ffc107; color: #333; }
    pre { background: #2d2d2d; color: #ccc; padding: 15px; border-radius: 6px; overflow-x: auto; font-family: 'Consolas', monospace; font-size: 0.9em; }
    .label { font-weight: bold; color: #555; width: 150px; display: inline-block; }
    .value { color: #000; }
    .error-msg { color: #dc3545; font-weight: bold; margin-top: 10px; }
    .fix-hint { background: #e8f0fe; padding: 10px; border-radius: 4px; margin-top: 10px; font-size: 0.9em; color: #1967d2; border: 1px solid #d2e3fc; }
</style></head><body>";

echo "<div class='container'>";
echo "<h1>POE Chain Diagnostic</h1>";

if ($learnerID <= 0) {
    echo "<div class='step status-fail'><span class='badge badge-fail'>Error</span> Please provide a valid learnerID in the URL. Example: ?learnerID=11560</div>";
    echo "</div></body></html>";
    exit;
}

echo "<p>Checking database links for <strong>Learner ID: $learnerID</strong></p>";

// --- STEP 1: Learner Details ---
echo "<div class='step " . ($learnerID ? "status-ok" : "") . "'>";
echo "<div class='step-header'><span class='badge badge-ok'>Step 1</span> Learner Details</div>";
$ldQuery = "SELECT * FROM learnerdetails WHERE LearnerID = ?";
$ldStmt = $conn->prepare($ldQuery);
$ldStmt->bind_param('i', $learnerID);
$ldStmt->execute();
$learner = $ldStmt->get_result()->fetch_assoc();

if ($learner) {
    echo "<div><span class='label'>Name:</span> <span class='value'>{$learner['Firstname']} {$learner['Surname']}</span></div>";
    echo "<div><span class='label'>ID Number:</span> <span class='value'>{$learner['IDNumber']}</span></div>";
    echo "<div><span class='label'>Class ID:</span> <span class='value'>" . ($learner['classID'] ? $learner['classID'] : "<span class='error-msg'>MISSING</span>") . "</span></div>";
    
    if (!$learner['classID']) {
        echo "<div class='fix-hint'><strong>Fix:</strong> This learner is not assigned to any class. Update 'classID' in the 'learnerdetails' table.</div>";
    }
} else {
    echo "<div class='error-msg'>Learner ID $learnerID not found in 'learnerdetails' table.</div>";
}
echo "</div>";

if (!$learner || !$learner['classID']) goto end;

// --- STEP 2: Class ---
echo "<div class='step " . ($learner['classID'] ? "status-ok" : "") . "'>";
echo "<div class='step-header'><span class='badge badge-ok'>Step 2</span> Class Details</div>";
$cQuery = "SELECT * FROM class WHERE classID = ?";
$cStmt = $conn->prepare($cQuery);
$cStmt->bind_param('i', $learner['classID']);
$cStmt->execute();
$class = $cStmt->get_result()->fetch_assoc();

if ($class) {
    echo "<div><span class='label'>Class Name:</span> <span class='value'>{$class['className']}</span></div>";
    echo "<div><span class='label'>Site ID:</span> <span class='value'>" . ($class['siteID'] ? $class['siteID'] : "<span class='error-msg'>MISSING</span>") . "</span></div>";
    
    if (!$class['siteID']) {
        echo "<div class='fix-hint'><strong>Fix:</strong> This class is not linked to a site. Update 'siteID' in the 'class' table.</div>";
    }
} else {
    echo "<div class='error-msg'>Class ID {$learner['classID']} not found in 'class' table.</div>";
}
echo "</div>";

if (!$class || !$class['siteID']) goto end;

// --- STEP 3: Site ---
echo "<div class='step " . ($class['siteID'] ? "status-ok" : "") . "'>";
echo "<div class='step-header'><span class='badge badge-ok'>Step 3</span> Site Details</div>";
$sQuery = "SELECT * FROM sites WHERE siteID = ?";
$sStmt = $conn->prepare($sQuery);
$sStmt->bind_param('i', $class['siteID']);
$sStmt->execute();
$site = $sStmt->get_result()->fetch_assoc();

if ($site) {
    echo "<div><span class='label'>Site Name:</span> <span class='value'>{$site['siteName']}</span></div>";
    echo "<div><span class='label'>Project ID:</span> <span class='value'>" . ($site['project_id'] ? $site['project_id'] : "<span class='error-msg'>MISSING</span>") . "</span></div>";
    
    if (!$site['project_id']) {
        echo "<div class='fix-hint'><strong>Fix:</strong> This site is not linked to a project. Update 'project_id' in the 'sites' table.</div>";
    }
} else {
    echo "<div class='error-msg'>Site ID {$class['siteID']} not found in 'sites' table.</div>";
}
echo "</div>";

if (!$site || !$site['project_id']) goto end;

// --- STEP 4: Project ---
echo "<div class='step " . ($site['project_id'] ? "status-ok" : "") . "'>";
echo "<div class='step-header'><span class='badge badge-ok'>Step 4</span> Project Details</div>";
$pQuery = "SELECT project_id, Project_name, Project_pathway FROM project WHERE project_id = ?";
$pStmt = $conn->prepare($pQuery);
$pStmt->bind_param('i', $site['project_id']);
$pStmt->execute();
$project = $pStmt->get_result()->fetch_assoc();

if ($project) {
    echo "<div><span class='label'>Project Name:</span> <span class='value'>{$project['Project_name']}</span></div>";
    
    $pathway = json_decode($project['Project_pathway'], true);
    if ($pathway) {
        $usCount = 0;
        if (isset($pathway[0]['qual_types'][0]['qualification']['unitStandards'])) {
            $usCount = count($pathway[0]['qual_types'][0]['qualification']['unitStandards']);
        }
        echo "<div><span class='label'>Pathway US Count:</span> <span class='value'>$usCount Unit Standards defined in JSON</span></div>";
        
        if ($usCount == 0) {
            echo "<div class='error-msg'>The Project Pathway JSON exists but contains NO Unit Standards.</div>";
        }
    } else {
        echo "<div class='error-msg'>Project Pathway JSON is INVALID or EMPTY.</div>";
        echo "<pre>" . htmlspecialchars($project['Project_pathway']) . "</pre>";
    }
} else {
    echo "<div class='error-msg'>Project ID {$site['project_id']} not found in 'project' table.</div>";
}
echo "</div>";

if (!$project) goto end;

// --- STEP 5: Assessments ---
echo "<div class='step " . ($project ? "status-ok" : "") . "'>";
echo "<div class='step-header'><span class='badge badge-ok'>Step 5</span> Assessment Records</div>";
$aQuery = "SELECT COUNT(*) as count, GROUP_CONCAT(DISTINCT unit_standard_id) as ids FROM assessments WHERE project_id = ?";
$aStmt = $conn->prepare($aQuery);
$aStmt->bind_param('i', $site['project_id']);
$aStmt->execute();
$assessments = $aStmt->get_result()->fetch_assoc();

if ($assessments['count'] > 0) {
    echo "<div><span class='label'>Total Questions:</span> <span class='value'>{$assessments['count']} questions found for this project.</span></div>";
    echo "<div><span class='label'>US IDs in Table:</span> <span class='value'>{$assessments['ids']}</span></div>";
} else {
    echo "<div class='error-msg'>No records found in 'assessments' table for Project ID {$site['project_id']}.</div>";
    echo "<div class='fix-hint'><strong>Fix:</strong> The POE tab will be empty if there are no questions linked to this project in the 'assessments' table.</div>";
}
echo "</div>";

// --- STEP 6: POE Files ---
echo "<div class='step " . ($learnerID ? "status-ok" : "") . "'>";
echo "<div class='step-header'><span class='badge badge-ok'>Step 6</span> Uploaded POE Files</div>";
$poeQuery = "SELECT COUNT(*) as count FROM poe WHERE learnerID = ?";
$poeStmt = $conn->prepare($poeQuery);
$poeStmt->bind_param('i', $learnerID);
$poeStmt->execute();
$poeCount = $poeStmt->get_result()->fetch_assoc()['count'];

if ($poeCount > 0) {
    echo "<div><span class='label'>Files Uploaded:</span> <span class='value'>$poeCount records found in 'poe' table.</span></div>";
} else {
    echo "<div class='status-warn'><span class='badge badge-warn'>Warning</span> No files have been uploaded for this learner yet.</div>";
}
echo "</div>";

// --- STEP 7: LIVE QUERY TEST ---
echo "<div class='step status-warn'>";
echo "<div class='step-header'><span class='badge badge-warn'>Step 7</span> Full Logic Simulation</div>";

$startTime = microtime(true);

$mainQuery = "
    SELECT DISTINCT 
        pr.project_id,
        JSON_EXTRACT(pr.Project_pathway, '$[0].name') AS pathway_name,
        JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.name') AS qualification_name,
        JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards') AS unit_standards,
        a.unit_standard_id,
        a.assessment_type,
        a.question_number,
        a.exercise
    FROM 
        learnerdetails ld 
    LEFT JOIN 
        class c ON ld.classID = c.classID 
    LEFT JOIN 
        sites s ON c.siteID = s.siteID 
    LEFT JOIN 
        project pr ON s.project_id = pr.project_id
    LEFT JOIN 
        assessments a ON (
            a.project_id = pr.project_id
            AND (
                JSON_CONTAINS(
                    JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards'),
                    JSON_OBJECT('id', a.unit_standard_id)
                ) OR
                JSON_CONTAINS(
                    JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards'),
                    JSON_OBJECT('id', CAST(a.unit_standard_id AS CHAR))
                )
            )
        )
    WHERE 
        ld.LearnerID = ?
";

$mainStmt = $conn->prepare($mainQuery);
$mainStmt->bind_param('i', $learnerID);
$mainStmt->execute();
$result = $mainStmt->get_result();

$data = ['pathways' => []];
$rowsFound = 0;

echo "<table border='1' style='width:100%; border-collapse:collapse; font-size:0.8em;'>";
echo "<tr style='background:#eee;'><th>Row</th><th>Pathway Name</th><th>US ID (Row)</th><th>US JSON (First 50 chars)</th><th>Match Status</th></tr>";

while ($row = $result->fetch_assoc()) {
    $rowsFound++;
    $pathwayName = $row['pathway_name'] ? trim($row['pathway_name'], '"') : 'Unknown Pathway';
    $qualificationName = $row['qualification_name'] ? trim($row['qualification_name'], '"') : 'Unknown Qualification';
    
    $unitStandards = json_decode($row['unit_standards'], true) ?? [];
    $matchFound = false;
    $debugComparison = "";
    
    foreach ($unitStandards as $us) {
        $idFromRow = trim((string)$row['unit_standard_id']);
        $idFromJson = trim((string)($us['id'] ?? ''));
        
        if ($idFromRow === $idFromJson) {
            $matchFound = true;
            if (!isset($data['pathways'][$pathwayName])) {
                $data['pathways'][$pathwayName] = ['qualifications' => []];
            }
            if (!isset($data['pathways'][$pathwayName]['qualifications'][$qualificationName])) {
                $data['pathways'][$pathwayName]['qualifications'][$qualificationName] = ['unitstandards' => []];
            }
            $usName = $us['name'] ?? 'Unknown';
            if (!isset($data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$usName])) {
                $data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$usName] = [
                    'formative' => [], 'summative' => [], 'logbook' => [], 'formativeremedial' => [], 'summativeremedial' => []
                ];
            }
            $data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$usName]['formative'][] = ['exercise' => $row['exercise']];
        }
    }
    
    if ($rowsFound <= 5) { // Only show first 5 rows to save space
        echo "<tr>";
        echo "<td>$rowsFound</td>";
        echo "<td>$pathwayName</td>";
        echo "<td>{$row['unit_standard_id']}</td>";
        echo "<td>" . htmlspecialchars(substr($row['unit_standards'], 0, 50)) . "...</td>";
        echo "<td style='color:" . ($matchFound ? "green" : "red") . "'>" . ($matchFound ? "MATCHED" : "NO MATCH") . "</td>";
        echo "</tr>";
    }
}
if ($rowsFound > 5) echo "<tr><td colspan='5' style='text-align:center;'>... ($rowsFound rows total) ...</td></tr>";
echo "</table>";

$endTime = microtime(true);
$duration = round($endTime - $startTime, 2);

$jsonOutput = json_encode($data);
$jsonError = json_last_error_msg();
$jsonSize = strlen($jsonOutput);

echo "<div style='margin-top:20px; padding:15px; background:#e8f5e9; border-radius:8px; border:1px solid #c8e6c9;'>";
echo "<h3>Performance & Validation</h3>";
echo "<div><span class='label'>Execution Time:</span> <span class='value " . ($duration > 5 ? "error-msg" : "") . "'>$duration seconds</span>" . ($duration > 8 ? " ⚠️ <strong>Warning:</strong> Close to Flutter 10s timeout!" : "") . "</div>";
echo "<div><span class='label'>JSON Status:</span> <span class='value'>" . ($jsonError == 'No error' ? "<span style='color:green;'>VALID</span>" : "<span style='color:red;'>INVALID: $jsonError</span>") . "</span></div>";
echo "<div><span class='label'>JSON Size:</span> <span class='value'>" . round($jsonSize / 1024, 2) . " KB</span></div>";

if ($jsonSize < 100 && $rowsFound > 0) {
    echo "<div class='error-msg'>Warning: SQL found data but JSON output is nearly empty. Check array structure.</div>";
}
echo "</div>";

// Check MySQL Version
$verResult = $conn->query("SELECT VERSION() as ver");
$version = $verResult->fetch_assoc()['ver'];
echo "<div style='margin-top:20px; font-size:0.8em; color:#999;'>MySQL Version: $version</div>";
echo "</div>";

end:
echo "</div>"; // end container
echo "<p style='text-align:center; color:#666; font-size:0.8em;'>Diagnostic Tool &bull; " . date('Y-m-d H:i:s') . "</p>";
echo "</body></html>";
?>