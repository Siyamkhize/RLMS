<?php
/**
 * ARPL PDF Generator - Trade-Specific Format
 * Location: /web/arpl_pdf.php
 * 
 * Follows arpl_toolkit_dynamic2.php pattern for proper trade tracking
 * Call with: http://localhost:8080/web/arpl_pdf.php?learnerID=16389&classID=782&ofo_code=671101
 */

session_start();

// CONNECTION WITH PROPER ERROR HANDLING
require_once __DIR__ . '/connection.php';

date_default_timezone_set('Africa/Johannesburg');

// ── AUTHENTICATION ─────────────────────────────────────────────
// Note: Web interface doesn't use session authentication
// Only check if accessed from mobile/authenticated context
if (isset($_SERVER['HTTP_X_MOBILE_AUTH'])) {
    if (!isset($_SESSION['sdp_id']) && !isset($_SESSION['facilitator_id'])) {
        header("Location: index.php");
        exit;
    }
}

// ── HELPER: RESOLVE DOCUMENT FILE PATHS ────────────────────────
/**
 * Resolve assessment document file paths from htdocs root
 * Files are stored at: C:/xampp/htdocs/assessorReport2/mobile/ARPL_POE/filename.pdf
 */
function resolveDocumentPath($relativeFilePath) {
    // List of possible htdocs roots to check (Windows XAMPP)
    $possibleRoots = [
        'C:/xampp/htdocs',
        'C:\\xampp\\htdocs',
        $_SERVER['DOCUMENT_ROOT'] ?? '',
    ];
    
    // Find the actual htdocs root
    $htdocsRoot = null;
    foreach ($possibleRoots as $root) {
        if (!empty($root) && is_dir($root . '/assessorReport2')) {
            $htdocsRoot = $root;
            break;
        }
    }
    
    // Fallback to standard location
    if (!$htdocsRoot) {
        $htdocsRoot = 'C:/xampp/htdocs';
    }
    
    // Build the full path with normalized slashes
    $fullPath = str_replace('\\', '/', $htdocsRoot) . '/' . str_replace('\\', '/', $relativeFilePath);
    
    // Return path if file exists and is readable
    if (file_exists($fullPath) && is_readable($fullPath)) {
        return $fullPath;
    }
    
    return null;  // File not found
}

// ── PARAMETER EXTRACTION ───────────────────────────────────────
$learnerID = isset($_GET['learnerID']) ? (int)$_GET['learnerID'] : 0;
$classID = isset($_GET['classID']) ? (int)$_GET['classID'] : 0;
$ofo_code = isset($_GET['ofo_code']) ? trim($_GET['ofo_code']) : '';

// ── DATABASE LOOKUP (if classID missing) ───────────────────────
if ($classID <= 0 && $learnerID > 0) {
    $st = $conn->prepare("SELECT classID FROM learnerdetails WHERE LearnerID = ? LIMIT 1");
    if ($st) {
        $st->bind_param("i", $learnerID);
        $st->execute();
        $result = $st->get_result();
        if ($row = $result->fetch_assoc()) {
            $classID = (int)$row['classID'];
        }
        $st->close();
    }
}

// ── AUTO-DETECT OFO CODE FROM CLASS IF NOT PROVIDED ─────────────
if (empty($ofo_code) && $classID > 0) {
    $st = $conn->prepare("
        SELECT s.qualification_id 
        FROM class c 
        LEFT JOIN sites s ON c.siteID = s.siteID 
        WHERE c.classID = ? LIMIT 1
    ");
    if ($st) {
        $st->bind_param("i", $classID);
        $st->execute();
        $result = $st->get_result();
        if ($row = $result->fetch_assoc()) {
            // Map qualification_id to OFO code
            $qual_id = $row['qualification_id'];
            $ofoMapping = [
                '671101' => '671101',  // Electrician
                '641201' => '641201',  // Bricklaying
                '642601' => '642601',  // Plumbing
            ];
            if (isset($ofoMapping[$qual_id])) {
                $ofo_code = $qual_id;
            }
        }
        $st->close();
    }
}

// ── FALLBACK IF OFO CODE STILL EMPTY ────────────────────────────
if (empty($ofo_code)) {
    $ofo_code = '671101';  // Default to Electrician
}

// ── VALIDATION ─────────────────────────────────────────────────
if (!$learnerID || !$classID) {
    die(json_encode([
        'status' => 'error',
        'message' => 'Invalid parameters: learnerID and classID are required',
        'debug' => ['learnerID' => $learnerID, 'classID' => $classID]
    ]));
}

// ── GET DATA FROM DATABASE ─────────────────────────────────────

// 1. FACILITATOR/ASSESSOR DATA (with fallback)
$facilitator = ['firstName' => 'Assessor', 'lastName' => '', 'assessorNo' => ''];
$facilitator_id = isset($_SESSION['facilitator_id']) ? (int)$_SESSION['facilitator_id'] : 0;

if ($facilitator_id > 0) {
    $st = $conn->prepare("SELECT * FROM facilitator WHERE facilitator_id = ? LIMIT 1");
    if ($st) {
        $st->bind_param("i", $facilitator_id);
        $st->execute();
        if ($frow = $st->get_result()->fetch_assoc()) {
            $facilitator = $frow;
        }
        $st->close();
    }
}

// 2. CLASS + SITE + PROJECT + SDP DATA (with proper JOINs)
$sql = "SELECT 
    c.classID, c.className, c.siteID,
    s.siteID, s.siteName, s.Province, s.District, s.Municipality,
    s.cell_phone, s.email, s.project_id, s.sdp_id, s.qualification_id,
    p.Project_name, p.Contract_no, p.Financial_year, p.Start_date, p.End_date,
    sdp.sdp_name, sdp.accreditation_n, sdp.p_address, sdp.email as sdp_email
FROM class c
LEFT JOIN sites s ON c.siteID = s.siteID
LEFT JOIN project p ON s.project_id = p.project_id
LEFT JOIN sdp ON s.sdp_id = sdp.sdp_id
WHERE c.classID = ? LIMIT 1";

$st = $conn->prepare($sql);
if (!$st) {
    die(json_encode(['status' => 'error', 'message' => 'Database prepare error: ' . $conn->error]));
}
$st->bind_param("i", $classID);
$st->execute();
$ctx = $st->get_result()->fetch_assoc();
$st->close();

if (!$ctx) {
    die(json_encode(['status' => 'error', 'message' => 'Class not found']));
}

// Get qualification_id from context for trade mapping
$qualification_id = isset($ctx['qualification_id']) ? (int)$ctx['qualification_id'] : 0;

// 3. LEARNER DATA (full profile)
$st = $conn->prepare("SELECT * FROM learnerdetails WHERE LearnerID = ? LIMIT 1");
if (!$st) {
    die(json_encode(['status' => 'error', 'message' => 'Database prepare error']));
}
$st->bind_param("i", $learnerID);
$st->execute();
$learner = $st->get_result()->fetch_assoc();
$st->close();

if (!$learner) {
    die(json_encode(['status' => 'error', 'message' => 'Learner not found in this class']));
}

// ── NORMALIZE LEARNER FIELD NAMES ──────────────────────────────
if (!isset($learner['FirstName']) || empty($learner['FirstName'])) {
    $learner['FirstName'] = $learner['Name'] ?? $learner['fname'] ?? 'Learner';
}
if (!isset($learner['LastName']) || empty($learner['LastName'])) {
    $learner['LastName'] = $learner['Surname'] ?? $learner['lname'] ?? $learnerID;
}

// ── LOAD UNIT STANDARDS (based on qualification_id) ─────────────
$unitStandards = [];
if (!empty($qualification_id)) {
    $st = $conn->prepare("
        SELECT unit_standard_id, unit_standard_code, unit_standard_name 
        FROM unitstandard 
        WHERE qualification_id = ? 
        ORDER BY unit_standard_code ASC
    ");
    if ($st) {
        $st->bind_param("s", $qualification_id);
        $st->execute();
        $result = $st->get_result();
        while ($row = $result->fetch_assoc()) {
            $unitStandards[] = $row;
        }
        $st->close();
    }
}

// ── LOAD ASSESSMENTS (per unit standard) ───────────────────────
$assessments = [];
if (!empty($unitStandards)) {
    foreach ($unitStandards as $us) {
        $us_id = $us['unit_standard_id'] ?? $us['unit_standard_code'];
        $st = $conn->prepare("
            SELECT assessment_id, unit_standard_id, assessment_name, assessment_date, result
            FROM assessments
            WHERE learner_id = ? AND unit_standard_id = ?
            ORDER BY assessment_date DESC
        ");
        if ($st) {
            $st->bind_param("is", $learnerID, $us_id);
            $st->execute();
            $result = $st->get_result();
            while ($row = $result->fetch_assoc()) {
                $assessments[] = $row;
            }
            $st->close();
        }
    }
}

// ── LOAD POE (Proof of Evidence) DATA ──────────────────────────
$poeData = [];
$st = $conn->prepare("
    SELECT poe_id, poe_type, poe_description, uploaded_date, evidence_file
    FROM poe 
    WHERE learner_id = ? AND class_id = ?
    ORDER BY uploaded_date DESC
");
if ($st) {
    $st->bind_param("ii", $learnerID, $classID);
    if ($st->execute()) {
        $result = $st->get_result();
        while ($row = $result->fetch_assoc()) {
            $poeData[] = $row;
        }
    }
    $st->close();
}

// ── LOAD LEARNER DOCUMENTS ────────────────────────────────────
$learnerDocuments = [];
$st = $conn->prepare("
    SELECT * FROM learner_document 
    WHERE learner_id = ? 
    ORDER BY upload_date DESC 
    LIMIT 20
");
if ($st) {
    $learnerIDStr = (string)$learnerID;  // Convert integer to string for varchar column
    $st->bind_param("s", $learnerIDStr);
    if ($st->execute()) {
        $result = $st->get_result();
        while ($row = $result->fetch_assoc()) {
            $learnerDocuments[] = $row;
        }
    }
    $st->close();
}

// ── LOAD APPENDIX B DATA (Competency Activities) ──────────────
// Determine trade and load appropriate activities with ratings
$appendixBActivities = [];
$tradeActivityTables = [
    '671101' => 'arplappxb_electrician_activities',
    '641201' => 'arplappxb_bricklaying_activities',
    '642601' => 'arplappxb_plumbing_activities',
];

// Map trades to their correct ratings tables
$tradeRatingsTables = [
    '671101' => 'arplappxe_electrician_activity_ratings',  // Electrician uses E table
    '641201' => 'arplappxe_bricklaying_activity_ratings',  // Bricklaying uses E table
    '642601' => 'arplappxb_activity_ratings',               // Plumbing uses B table
];

$appendixBTable = $tradeActivityTables[$ofo_code] ?? 'arplappxb_plumbing_activities';
$ratingsTable = $tradeRatingsTables[$ofo_code] ?? 'arplappxb_activity_ratings';

// Query activities with their assessor ratings - FIXED with proper parameterized statements
$appendixBSQL = "SELECT 
    act.activity_id,
    act.activity_number,
    act.activity_name,
    act.ofo_number,
    COALESCE(rat.competency_scale_id, NULL) as rating,
    COALESCE(rat.comments, '') as assessor_comments,
    COALESCE(rat.rating_date, NULL) as rating_date,
    COALESCE(rat.facilitator_id, NULL) as assessor_id
FROM $appendixBTable act
LEFT JOIN $ratingsTable rat ON (
    rat.activity_id = act.activity_id 
    AND rat.learnerID = ?
    AND rat.ofo_number = ?
)
ORDER BY act.activity_number ASC";

$st = $conn->prepare($appendixBSQL);
if ($st) {
    $st->bind_param("is", $learnerID, $ofo_code);
    $st->execute();
    $result = $st->get_result();
    while ($row = $result->fetch_assoc()) {
        $appendixBActivities[] = $row;
    }
    $st->close();
} else {
    error_log("Appendix B query preparation failed: " . $conn->error);
}

// ── LOAD APPENDIX C DATA ──────────────────────────────────────
$appendixC = null;
$st = $conn->prepare("SELECT * FROM arpl_appendix_c WHERE learnerID = ? AND ofo_number = ? LIMIT 1");
if ($st) {
    $st->bind_param("is", $learnerID, $ofo_code);
    $st->execute();
    $result = $st->get_result();
    if ($row = $result->fetch_assoc()) {
        $appendixC = $row;
    }
    $st->close();
}

// ── LOAD APPENDIX D DATA (Practical Skills Assessment) ────────────────────
$appendixDPapers = [];
$st = $conn->prepare("SELECT * FROM arpl_appendix_d WHERE learnerID = ? AND ofo_number = ? ORDER BY created_at DESC");
if ($st) {
    $st->bind_param("is", $learnerID, $ofo_code);
    $st->execute();
    $result = $st->get_result();
    while ($row = $result->fetch_assoc()) {
        $appendixDPapers[] = $row;
    }
    $st->close();
}

// ── LOAD GAP CLOSURE REPORT DATA ──────────────────────────────
$gapAnalysisSubmission = null;
$gapAnalysisTasks = [];
$st = $conn->prepare("
    SELECT gas.* 
    FROM gap_analysis_submissions gas
    WHERE gas.learner_id = ? 
    ORDER BY gas.created_at DESC 
    LIMIT 1
");
if ($st) {
    $st->bind_param("i", $learnerID);
    $st->execute();
    $result = $st->get_result();
    if ($row = $result->fetch_assoc()) {
        $gapAnalysisSubmission = $row;
        
        // Load associated task ratings
        $st2 = $conn->prepare("
            SELECT gasi.*, gar.TaskNo, gar.TaskName, gar.AssessmentMethod
            FROM gap_analysis_submission_items gasi
            LEFT JOIN gap_analysis_report gar ON gasi.task_id = gar.TaskID
            WHERE gasi.submission_id = ?
            ORDER BY gar.TaskNo ASC
        ");
        if ($st2) {
            $submissionId = $gapAnalysisSubmission['id'] ?? $gapAnalysisSubmission['submission_id'] ?? 0;
            $st2->bind_param("i", $submissionId);
            $st2->execute();
            $res2 = $st2->get_result();
            while ($taskRow = $res2->fetch_assoc()) {
                $gapAnalysisTasks[] = $taskRow;
            }
            $st2->close();
        }
    }
    $st->close();
}

// ── LOAD APPENDIX E DATA (Practical Assessment) with RATINGS ────
// Trade-specific activity tables
$appendixEActivityTables = [
    '671101' => 'arplappxb_electrician_activities',
    '641201' => 'arplappxb_bricklaying_activities',
    '642601' => 'arplappxb_plumbing_activities',
];

// Trade-specific ratings tables
$appendixERatingsTables = [
    '671101' => 'arplappxe_electrician_activity_ratings',
    '641201' => 'arplappxe_bricklaying_activity_ratings',
    '642601' => 'arplappxb_activity_ratings',
];

$appendixEActivityTable = $appendixEActivityTables[$ofo_code] ?? 'arplappxb_plumbing_activities';
$appendixERatingsTable = $appendixERatingsTables[$ofo_code] ?? 'arplappxb_activity_ratings';

// Query activities WITH ratings (LEFT JOIN for optional ratings)
$appendixESql = "SELECT 
    act.activity_id,
    act.activity_number,
    act.activity_name,
    COALESCE(rat.competency_scale_id, NULL) as rating,
    COALESCE(rat.comments, '') as assessor_comments,
    COALESCE(rat.rating_date, NULL) as rating_date
FROM $appendixEActivityTable act
LEFT JOIN $appendixERatingsTable rat ON (
    rat.activity_id = act.activity_id 
    AND rat.learnerID = ?
    AND rat.ofo_number = ?
)
ORDER BY act.activity_number ASC";

$appendixEActivities = [];
$st = $conn->prepare($appendixESql);
if ($st) {
    $st->bind_param("is", $learnerID, $ofo_code);
    $st->execute();
    $result = $st->get_result();
    while ($row = $result->fetch_assoc()) {
        $appendixEActivities[] = $row;
    }
    $st->close();
} else {
    error_log("Appendix E query preparation failed: " . $conn->error);
}

// ── LOAD APPENDIX G DATA (Assessment Agreement) ────────────────
$appendixG = null;
$st = $conn->prepare("SELECT * FROM arpl_appendix_g WHERE learnerID = ? AND ofo_number = ? LIMIT 1");
if ($st) {
    $st->bind_param("is", $learnerID, $ofo_code);
    $st->execute();
    $result = $st->get_result();
    if ($row = $result->fetch_assoc()) {
        $appendixG = $row;
    }
    $st->close();
}

// ── LOAD ASSESSMENT PAPERS (THEORY & PRACTICAL FROM arpl_poe TABLE) ──────────────
// Theory papers appear after self-evaluation/Interview checklist
// Practical scripts appear with attendance register
// Workplace experience data already retrieved
$theoryPapers = [];
$practicalScripts = [];
$theoryRegister = null;
$practicalAttendanceRegister = null;
$workplaceExperienceRegister = null;

// Get theory papers - FIX: Use correct column names (paper_title, combined_pdf_path)
$st = $conn->prepare("SELECT * FROM arpl_poe WHERE learnerID = ? AND ofo_number = ? AND section_type = 'theory' ORDER BY paper_number ASC");
if ($st) {
    $st->bind_param("is", $learnerID, $ofo_code);
    $st->execute();
    $result = $st->get_result();
    while ($row = $result->fetch_assoc()) {
        $theoryPapers[] = $row;
    }
    $st->close();
}

// Get practical scripts - FIX: Use correct column names
$st = $conn->prepare("SELECT * FROM arpl_poe WHERE learnerID = ? AND ofo_number = ? AND section_type = 'practical' ORDER BY paper_number ASC");
if ($st) {
    $st->bind_param("is", $learnerID, $ofo_code);
    $st->execute();
    $result = $st->get_result();
    while ($row = $result->fetch_assoc()) {
        $practicalScripts[] = $row;
    }
    $st->close();
}

// Note: Theory/Practical registers and Workplace experience register are placeholders for now
// They will show "Not Uploaded" status

// ── LOAD SIGNATURE IMAGES (from assessorReport2/signatures directory) ──────
$learnerSignatureImage = null;
$assessorSignatureImage = null;
$signaturesDir = __DIR__ . '/../assessorReport2/signatures';

// Function to find signature file by pattern
function findSignatureFile($dir, $learnerID, $type = 'candidate') {
    if (!is_dir($dir)) {
        return null;
    }
    
    // Build pattern: signature_{learnerID}_{type}*
    $pattern = $type === 'candidate' ? "candidate-sig-{$learnerID}" : "assessor-sig.*{$learnerID}";
    
    foreach (scandir($dir) as $file) {
        if ($file === '.' || $file === '..') continue;
        
        if (strpos($file, "signature_{$learnerID}") !== false) {
            if ($type === 'candidate' && strpos($file, 'candidate-sig') !== false) {
                return $file;
            } elseif ($type === 'assessor' && strpos($file, 'assessor-sig') !== false) {
                return $file;
            }
        }
    }
    return null;
}

// Try to find and load signature images
if (is_dir($signaturesDir)) {
    $learnerSigFile = findSignatureFile($signaturesDir, $learnerID, 'candidate');
    $assessorSigFile = findSignatureFile($signaturesDir, $learnerID, 'assessor');
    
    // Load learner signature if found
    if ($learnerSigFile && is_file("$signaturesDir/$learnerSigFile")) {
        $sigContent = file_get_contents("$signaturesDir/$learnerSigFile");
        if (!empty($sigContent)) {
            // Detect file type
            $finfo = finfo_open(FILEINFO_MIME_TYPE);
            $mimeType = finfo_file($finfo, "$signaturesDir/$learnerSigFile");
            finfo_close($finfo);
            
            // Convert to base64 for embedding
            $learnerSignatureImage = 'data:' . $mimeType . ';base64,' . base64_encode($sigContent);
        }
    }
    
    // Load assessor signature if found
    if ($assessorSigFile && is_file("$signaturesDir/$assessorSigFile")) {
        $sigContent = file_get_contents("$signaturesDir/$assessorSigFile");
        if (!empty($sigContent)) {
            // Detect file type
            $finfo = finfo_open(FILEINFO_MIME_TYPE);
            $mimeType = finfo_file($finfo, "$signaturesDir/$assessorSigFile");
            finfo_close($finfo);
            
            // Convert to base64 for embedding
            $assessorSignatureImage = 'data:' . $mimeType . ';base64,' . base64_encode($sigContent);
        }
    }
}

// ── LOAD APPENDIX I DATA (Access Recommendation) ───────────────
// Query trade-specific recommendation table based on OFO code
$appendixI = null;
$tableName = null;
$debugInfo = "OFO: $ofo_code, Learner: $learnerID"; // DEBUG

// Map OFO code to trade-specific recommendation table
$ofoToTable = [
    '671101' => 'arplelectrician_access_recommendation',
    '641201' => 'arplbricklayer_access_recommendation',
    '642601' => 'arplplumber_access_recommendation',
];

if (isset($ofoToTable[$ofo_code])) {
    $tableName = $ofoToTable[$ofo_code];
    $debugInfo .= ", Table: $tableName"; // DEBUG
    
    $st = $conn->prepare("SELECT * FROM $tableName WHERE LearnerID = ? LIMIT 1");
    if ($st) {
        $st->bind_param("i", $learnerID);
        $st->execute();
        $result = $st->get_result();
        if ($row = $result->fetch_assoc()) {
            $appendixI = $row;
            $debugInfo .= ", FOUND"; // DEBUG
        } else {
            $debugInfo .= ", NOT_FOUND"; // DEBUG
        }
        $st->close();
    } else {
        $debugInfo .= ", PREPARE_FAILED"; // DEBUG
    }
} else {
    // Fallback to generic table if OFO code not recognized
    $tableName = "arpl_appendix_i";
    $st = $conn->prepare("SELECT * FROM arpl_appendix_i WHERE learnerID = ? AND ofo_number = ? LIMIT 1");
    if ($st) {
        $st->bind_param("is", $learnerID, $ofo_code);
        $st->execute();
        $result = $st->get_result();
        if ($row = $result->fetch_assoc()) {
            $appendixI = $row;
            $debugInfo .= ", FALLBACK_FOUND"; // DEBUG
        } else {
            $debugInfo .= ", FALLBACK_NOT_FOUND"; // DEBUG
        }
        $st->close();
    }
}

// ── LOAD ASSESSMENT PAPERS ──────────────────────────────────────
$assessmentPapers = [];
$st = $conn->query("SELECT * FROM arpl_papers WHERE learner_id = $learnerID OR qualification_id = '642601' ORDER BY paper_date DESC LIMIT 5");
if ($st) {
    while ($row = $st->fetch_assoc()) {
        $assessmentPapers[] = $row;
    }
}

// ── LOAD COMPETENCY SCALE ──────────────────────────────────────
$competencyScale = [];
$st = $conn->query("SELECT * FROM arpl_competency_scale ORDER BY level_number ASC");
if ($st) {
    while ($row = $st->fetch_assoc()) {
        $competencyScale[] = $row;
    }
}

// ── LOAD ARPL v3 APPLICATION DATA ────────────────────────────────
// For the application form (Appendix A)
$arplApplication = null;
$arplWorkExperience = [];
$arplReferences = [];
$arplQualifications = [];

// Find application by learner's ID number
if (isset($learner['IDNumber']) && !empty($learner['IDNumber'])) {
    $st = $conn->prepare("SELECT id FROM arpl_applications_v3 WHERE id_number = ? LIMIT 1");
    if ($st) {
        $st->bind_param("s", $learner['IDNumber']);
        $st->execute();
        $result = $st->get_result();
        if ($appRow = $result->fetch_assoc()) {
            $applicationID = $appRow['id'];
            
            // Load full application data
            $appData = $conn->query("SELECT * FROM arpl_applications_v3 WHERE id = $applicationID")->fetch_assoc();
            $arplApplication = $appData;
            
            // Load work experience
            $workResult = $conn->query("SELECT * FROM arpl_work_experience_v3 WHERE application_id = $applicationID ORDER BY start_date DESC");
            while ($wrow = $workResult->fetch_assoc()) {
                $arplWorkExperience[] = $wrow;
            }
            
            // Load references
            $refResult = $conn->query("SELECT * FROM arpl_references_v3 WHERE application_id = $applicationID ORDER BY reference_order ASC");
            while ($rrow = $refResult->fetch_assoc()) {
                $arplReferences[] = $rrow;
            }
            
            // Load qualifications
            $qualResult = $conn->query("SELECT * FROM arpl_qualifications_v3 WHERE application_id = $applicationID ORDER BY is_primary DESC, year_obtained DESC");
            while ($qrow = $qualResult->fetch_assoc()) {
                $arplQualifications[] = $qrow;
            }
        }
        $st->close();
    }
}

// ── TRADE CONFIGURATION ────────────────────────────────────────
$tradeConfig = [
    '671101' => ['name' => 'Electrician',  'table_suffix' => 'electrician'],
    '641201' => ['name' => 'Bricklaying',  'table_suffix' => 'bricklaying'],
    '642601' => ['name' => 'Plumbing',     'table_suffix' => 'plumbing'],
];

if (!isset($tradeConfig[$ofo_code])) {
    $ofo_code = '642601';
}

$tradeName = $tradeConfig[$ofo_code]['name'];
$today = date('j M Y');

?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>ARPL Portfolio - <?php echo htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']); ?></title>
    <style>
        @page {
            size: A4;
            margin: 10mm;
            @bottom-center {
                content: "Page " counter(page) " of " counter(pages);
            }
        }
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
        }
        .page-break {
            page-break-after: always;
            margin: 20px 0;
        }
        .page {
            page-break-after: always;
            padding: 40px;
            min-height: 100%;
        }
        .header {
            border-bottom: 2px solid #333;
            margin-bottom: 20px;
            padding-bottom: 10px;
        }
        .title {
            text-align: center;
            font-size: 24px;
            font-weight: bold;
            margin: 20px 0;
        }
        .subtitle {
            text-align: center;
            font-size: 14px;
            color: #666;
            margin-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 10px 0;
        }
        table, th, td {
            border: 1px solid #ccc;
        }
        th, td {
            padding: 8px;
            text-align: left;
        }
        th {
            background: #f5f5f5;
            font-weight: bold;
        }
        .dht {
            border: 1px solid #333;
            padding: 10px;
            margin-bottom: 20px;
            background: #f9f9f9;
        }
        .appendix-title {
            font-size: 18px;
            font-weight: bold;
            margin: 20px 0 10px 0;
        }
        .sec-title {
            font-size: 14px;
            font-weight: bold;
            margin: 15px 0 10px 0;
            color: #333;
        }
        .sig-table {
            width: 100%;
            border-collapse: collapse;
            margin: 10px 0;
        }
        .sig-table td {
            padding: 8px;
            text-align: left;
        }
        .sig-pad-wrapper {
            margin: 10px 0;
            border: 1px solid #ccc;
            padding: 5px;
        }
        .sig-pad-canvas {
            border: 1px solid #999;
            background: white;
        }
        .sig-pad-buttons {
            margin-top: 5px;
        }
        .sig-pad-btn {
            padding: 5px 10px;
            background: #f0f0f0;
            border: 1px solid #ccc;
            cursor: pointer;
            font-size: 11px;
        }
        .ft {
            font-size: 13px;
            width: 100%;
            border-collapse: collapse;
        }
        .ft td {
            padding: 8px;
            border: 1px solid #999;
        }
        .prefilled {
            color: #006341;
            font-style: italic;
        }
        .watermark {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%) rotate(-45deg);
            font-size: 80px;
            color: rgba(0, 0, 0, 0.1);
            z-index: -1;
            pointer-events: none;
        }
    </style>
</head>
<body>
    <div class="watermark">CONFIDENTIAL</div>

    <!-- PAGE 1: COVER PAGE -->
    <div class="page">
        <!-- Logo Row with DHET Branding -->
        <div style="text-align: center; display: flex; align-items: center; justify-content: center; gap: 14px; margin-bottom: 60px;">
            <!-- DHET Logo -->
            <img src="logs/education.jpg" alt="DHET Logo" style="width: 88px; height: auto; flex-shrink: 0;">
            
            <!-- DHET Text -->
            <div style="text-align: center; font-family: Arial, Helvetica, sans-serif; line-height: 1.2;">
                <div style="font-size: 20pt; font-weight: bold; color: #000; line-height: 1.05;">Higher Education</div>
                <div style="font-size: 20pt; font-weight: bold; color: #000; margin-bottom: 5px;">&amp; Training</div>
                <hr style="border: none; border-top: 1.5px solid #000; margin: 4px 0 5px;">
                <div style="font-size: 9pt; color: #333;">Department:</div>
                <div style="font-size: 9.5pt; color: #333;">Higher Education and Training</div>
                <div style="font-size: 9.5pt; font-weight: bold; color: #000; text-transform: uppercase; letter-spacing: 0.4px;">REPUBLIC OF SOUTH AFRICA</div>
            </div>
        </div>

        <!-- Main Title -->
        <div style="text-align: center; margin-bottom: 40px;">
            <div style="font-size: 28px; font-weight: bold; margin: 20px 0;">ARPL PORTFOLIO</div>
            <div style="font-size: 16px; color: #666; margin: 20px 0;">
                Trade: <strong><?php echo htmlspecialchars($tradeName); ?></strong><br>
                OFO Code: <strong><?php echo htmlspecialchars($ofo_code); ?></strong>
            </div>
        </div>

        <!-- Learner Information -->
        <div style="text-align: center; margin: 40px 0;">
            <div style="font-size: 12px;">Learner:</div>
            <div style="font-size: 14px; font-weight: bold;"><?php echo htmlspecialchars(($learner['FirstName'] ?? $learner['Name'] ?? 'Learner') . ' ' . ($learner['LastName'] ?? $learner['Surname'] ?? $learnerID)); ?></div>
            <div style="font-size: 12px;">Learner ID: <?php echo $learnerID; ?></div>
        </div>

        <!-- Footer Information -->
        <div style="margin-top: 60px; text-align: center; font-size: 11px; color: #999;">
            Generated: <?php echo $today; ?><br>
            Portfolio Version 3.0<br>
            Exact Mobile App Format
        </div>
    </div>

    <!-- PAGE 2: CONTENTS -->
    <div class="page">
        <div class="appendix-title">Table of Contents</div>
        <table class="ft">
            <tr><td><strong>Appendix A</strong></td><td>Application Form & Supporting Documents</td><td>Page 3</td></tr>
            <tr><td><strong>Appendix B</strong></td><td>Competency Proficiency Scale</td><td>Page 4</td></tr>
            <tr><td><strong>Appendix C</strong></td><td>Trade Curriculum Content</td><td>Page 5</td></tr>
            <tr><td><strong>Appendix D</strong></td><td>Gap Closure Report</td><td>Page 6</td></tr>
            <tr><td><strong>Appendix E</strong></td><td>Practical Skills Assessment Evaluation Checklist</td><td>Page 7</td></tr>
            <tr><td><strong>Appendix F</strong></td><td>Practical Skills Assessment</td><td>Page 8</td></tr>
            <tr><td><strong>Appendix G</strong></td><td>Assessment Evaluation Agreement</td><td>Page 9</td></tr>
            <tr><td><strong>Appendix H</strong></td><td>Appeals Form</td><td>Page 10</td></tr>
            <tr><td><strong>Appendix I</strong></td><td>Access Recommendation</td><td>Page 11</td></tr>
            <tr><td><strong>Appendix J</strong></td><td>Statement of Results</td><td>Page 12</td></tr>
            <tr><td><strong>Appendix K</strong></td><td>Pre-Assessment Agreement</td><td>Page 13</td></tr>
        </table>
    </div>

    <!-- PAGE 2B: ARPL PORTFOLIO OF EVIDENCE CHECKLIST -->
    <div class="page">
        <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #000; padding-bottom: 10px; margin-bottom: 15px;">
            <div style="font-size: 16px; font-weight: bold; text-transform: uppercase;">ARPL Portfolio of Evidence Checklist</div>
            <div style="text-align: right; font-size: 11px;">
                <div style="font-size: 13px; font-weight: bold;">higher education<br>&amp; training</div>
                <small style="display: block; line-height: 1.3;">
                    Department:<br>
                    Higher Education and Training<br>
                    <strong>REPUBLIC OF SOUTH AFRICA</strong>
                </small>
            </div>
        </div>

        <div style="display: flex; flex-wrap: wrap; gap: 10px 40px; margin-bottom: 15px;">
            <div><label style="font-weight: bold; margin-right: 5px;">Candidate Name/s:</label>
                <span style="border-bottom: 1px solid #000; display: inline-block; min-width: 220px;"><?php echo htmlspecialchars($learner['FirstName'] ?? 'N/A'); ?></span></div>
            <div><label style="font-weight: bold; margin-right: 5px;">Candidates Surname:</label>
                <span style="border-bottom: 1px solid #000; display: inline-block; min-width: 220px;"><?php echo htmlspecialchars($learner['LastName'] ?? 'N/A'); ?></span></div>
        </div>

        <div style="display: flex; flex-wrap: wrap; gap: 10px 40px; margin-bottom: 15px;">
            <div><label style="font-weight: bold; margin-right: 5px;">ID Number:</label>
                <span style="border-bottom: 1px solid #000; display: inline-block; min-width: 220px;"><?php echo htmlspecialchars($learner['IDNumber'] ?? 'N/A'); ?></span></div>
            <div><label style="font-weight: bold; margin-right: 5px;">Trade:</label>
                <span style="border-bottom: 1px solid #000; display: inline-block; min-width: 220px;"><?php echo htmlspecialchars($tradeName); ?></span></div>
        </div>

        <table style="width: 100%; border-collapse: collapse; margin-bottom: 10px; font-size: 11px;">
            <thead>
                <tr>
                    <th style="border: 1px solid #000; padding: 4px 5px; background: #dfe3e8; width: 35px; text-align: center;">No</th>
                    <th style="border: 1px solid #000; padding: 4px 5px; background: #dfe3e8; text-align: left;">Description</th>
                    <th style="border: 1px solid #000; padding: 4px 5px; background: #dfe3e8; width: 60px; text-align: center;">YES</th>
                </tr>
            </thead>
            <tbody>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">1</td><td style="border: 1px solid #000; padding: 4px 5px;">Application form</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">2</td><td style="border: 1px solid #000; padding: 4px 5px;">Certified ID copy</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">3</td><td style="border: 1px solid #000; padding: 4px 5px;">Curriculum Vitae</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">4</td><td style="border: 1px solid #000; padding: 4px 5px;">Certified copies of qualifications (if any) and service letter/s from current and or previous employer/s as per the CV</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">5</td><td style="border: 1px solid #000; padding: 4px 5px;">Fees payment records</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">6</td><td style="border: 1px solid #000; padding: 4px 5px;">Self-Evaluation/Interview checklist</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">7</td><td style="border: 1px solid #000; padding: 4px 5px;">Gap closure reports</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">8</td><td style="border: 1px solid #000; padding: 4px 5px;">Theory Assessment scripts</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">9</td><td style="border: 1px solid #000; padding: 4px 5px;">Register of Theory Assessment sitting</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">10</td><td style="border: 1px solid #000; padding: 4px 5px;">Practical Assessment of trade tasks</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">11</td><td style="border: 1px solid #000; padding: 4px 5px;">Register of Practical Assessment sitting</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">12</td><td style="border: 1px solid #000; padding: 4px 5px;">Workplace Experience evaluation checklist and photograph/s</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">13</td><td style="border: 1px solid #000; padding: 4px 5px;">Register of Workplace Experience evaluation sitting</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">14</td><td style="border: 1px solid #000; padding: 4px 5px;">Details of Assessor including the copy of his/her Artisan certificate and Registration No.</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">15</td><td style="border: 1px solid #000; padding: 4px 5px;">Feedback form</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">16</td><td style="border: 1px solid #000; padding: 4px 5px;">Appeals form/s</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">17</td><td style="border: 1px solid #000; padding: 4px 5px;">Recommendation for trade testing</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">18</td><td style="border: 1px solid #000; padding: 4px 5px;">Statement of Results</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">19</td><td style="border: 1px solid #000; padding: 4px 5px;">Trade test serial number</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">20</td><td style="border: 1px solid #000; padding: 4px 5px;">Trade test results</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
                <tr><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">21</td><td style="border: 1px solid #000; padding: 4px 5px;">NAMB moderation report (only when chosen for Trade Test and PoE moderation)</td><td style="border: 1px solid #000; padding: 4px 5px; text-align: center;">☐</td></tr>
            </tbody>
        </table>

        <div style="font-weight: bold; margin: 12px 0 8px;">COMPLETE WHEN PoE CONTAINS ALL INFORMATION AS REQUIRED BEFORE MODERATION (1-19)</div>

        <div style="margin-bottom: 8px; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; font-size: 11px;">
            <label style="font-weight: bold; min-width: 190px;">ARPL Candidate Signature:</label>
            <span style="border-bottom: 1px solid #000; flex: 1; min-width: 150px;">&nbsp;</span>
            <span style="font-weight: bold; min-width: 40px;">Date:</span>
            <span style="border-bottom: 1px solid #000; min-width: 80px;">&nbsp;</span>
        </div>

        <div style="margin-bottom: 8px; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; font-size: 11px;">
            <label style="font-weight: bold; min-width: 190px;">ARPL Assessor Name:</label>
            <span style="border-bottom: 1px solid #000; flex: 1; min-width: 150px;">&nbsp;</span>
            <span style="font-weight: bold; min-width: 40px;">Signature:</span>
            <span style="border-bottom: 1px solid #000; flex: 1; min-width: 80px;">&nbsp;</span>
            <span style="font-weight: bold; min-width: 40px;">Date:</span>
            <span style="border-bottom: 1px solid #000; min-width: 80px;">&nbsp;</span>
        </div>

        <div style="margin-bottom: 8px; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; font-size: 11px;">
            <label style="font-weight: bold; min-width: 190px;">Moderator Name:</label>
            <span style="border-bottom: 1px solid #000; flex: 1; min-width: 150px;">&nbsp;</span>
            <span style="font-weight: bold; min-width: 40px;">Signature:</span>
            <span style="border-bottom: 1px solid #000; flex: 1; min-width: 80px;">&nbsp;</span>
            <span style="font-weight: bold; min-width: 40px;">Date:</span>
            <span style="border-bottom: 1px solid #000; min-width: 80px;">&nbsp;</span>
        </div>

        <div style="margin-bottom: 8px; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; font-size: 11px;">
            <label style="font-weight: bold; min-width: 190px;">Name of Administration Clerk:</label>
            <span style="border-bottom: 1px solid #000; flex: 1; min-width: 150px;">&nbsp;</span>
            <span style="font-weight: bold; min-width: 40px;">Signature:</span>
            <span style="border-bottom: 1px solid #000; flex: 1; min-width: 80px;">&nbsp;</span>
            <span style="font-weight: bold; min-width: 40px;">Date:</span>
            <span style="border-bottom: 1px solid #000; min-width: 80px;">&nbsp;</span>
        </div>

        <table style="width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 10px;">
            <caption style="text-align: center; font-weight: bold; padding-bottom: 4px;">ARPL Portfolio of Evidence checklist.</caption>
            <tr>
                <th style="border: 1px solid #000; padding: 4px 5px; background: #dfe3e8; text-align: left; width: 15%;">Version</th>
                <td style="border: 1px solid #000; padding: 4px 5px;">1 of 2017</td>
                <th style="border: 1px solid #000; padding: 4px 5px; background: #dfe3e8; text-align: left;">Doc Ref.</th>
                <td style="border: 1px solid #000; padding: 4px 5px;">ARPL PoE checklist</td>
                <th style="border: 1px solid #000; padding: 4px 5px; background: #dfe3e8; text-align: left;">Doc. No.</th>
                <td style="border: 1px solid #000; padding: 4px 5px;"></td>
            </tr>
            <tr>
                <th style="border: 1px solid #000; padding: 4px 5px; background: #dfe3e8; text-align: left;">Signature:</th>
                <td style="border: 1px solid #000; padding: 4px 5px;"></td>
                <th style="border: 1px solid #000; padding: 4px 5px; background: #dfe3e8; text-align: left;">Page</th>
                <td style="border: 1px solid #000; padding: 4px 5px;">1 of 1</td>
                <th style="border: 1px solid #000; padding: 4px 5px; background: #dfe3e8; text-align: left;">Date revised</th>
                <td style="border: 1px solid #000; padding: 4px 5px;">08 May 2017</td>
            </tr>
        </table>
    </div>

    <!-- PAGE 3: APPENDIX A -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio</td></tr>
            <tr><td colspan="2">Appendix A: Application Form</td></tr>
        </table>
        
        <div class="appendix-title">Applicant Details</div>
        <table class="ft">
            <tr><td style="width:38%;"><b>Full Name</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['first_name'] . ' ' . $arplApplication['last_name']) : htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']); ?></span></td></tr>
            <tr><td><b>ID Number</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['id_number']) : $learnerID; ?></span></td></tr>
            <tr><td><b>Date of Birth</b></td><td><span class="prefilled"><?php echo $arplApplication ? date('d M Y', strtotime($arplApplication['date_of_birth'])) : (isset($learner['DOB']) ? date('d M Y', strtotime($learner['DOB'])) : 'N/A'); ?></span></td></tr>
            <tr><td><b>Gender</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['gender']) : (isset($learner['Gender']) ? htmlspecialchars($learner['Gender']) : 'N/A'); ?></span></td></tr>
            <tr><td><b>Phone</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['phone']) : (isset($learner['cell_phone']) ? htmlspecialchars($learner['cell_phone']) : 'N/A'); ?></span></td></tr>
            <tr><td><b>Email</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['email']) : (isset($learner['EmailAddress']) ? htmlspecialchars($learner['EmailAddress']) : 'N/A'); ?></span></td></tr>
        </table>

        <div class="appendix-title" style="margin-top: 20px;">Address Information</div>
        <table class="ft">
            <tr><td style="width:38%;"><b>Street Address</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['street_address']) : 'N/A'; ?></span></td></tr>
            <tr><td><b>City</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['city']) : 'N/A'; ?></span></td></tr>
            <tr><td><b>Postal Code</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['postal_code']) : 'N/A'; ?></span></td></tr>
            <tr><td><b>Province</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['province']) : (isset($ctx['Province']) ? htmlspecialchars($ctx['Province']) : 'N/A'); ?></span></td></tr>
        </table>

        <div class="appendix-title" style="margin-top: 20px;">Employment Status</div>
        <table class="ft">
            <tr><td style="width:38%;"><b>Total Years of Experience</b></td><td><span class="prefilled"><?php echo $arplApplication ? $arplApplication['total_years_of_experience'] . ' years' : 'N/A'; ?></span></td></tr>
            <tr><td><b>Highest Qualification</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['highest_qualification']) : 'N/A'; ?></span></td></tr>
            <tr><td><b>Trade Applied For</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['trade_applied_for']) : htmlspecialchars($tradeName); ?></span></td></tr>
            <tr><td><b>Application Status</b></td><td><span class="prefilled"><?php echo $arplApplication ? htmlspecialchars($arplApplication['application_status']) : 'Submitted'; ?></span></td></tr>
        </table>
    </div>

    <!-- PAGE 4+: Additional Appendices (Simplified) -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Employment & References</td></tr>
        </table>

        <div class="appendix-title">Employment History</div>
        <?php if (!empty($arplWorkExperience)): ?>
        <table class="ft">
            <tr><th style="width:30%;">Company</th><th style="width:20%;">Position</th><th style="width:35%;">Period</th><th style="width:15%;">Type</th></tr>
            <?php foreach ($arplWorkExperience as $work): ?>
            <tr>
                <td><span class="prefilled"><?php echo htmlspecialchars($work['employer_name'] ?? ''); ?></span></td>
                <td><span class="prefilled"><?php echo htmlspecialchars($work['job_title'] ?? ''); ?></span></td>
                <td><span class="prefilled">
                    <?php 
                    $start = date('Y-m-d', strtotime($work['start_date'] ?? ''));
                    $end = $work['is_current_job'] ? 'Present' : date('Y-m-d', strtotime($work['end_date'] ?? ''));
                    echo "$start to $end";
                    ?>
                    <br><small>(<?php echo ($work['years_worked'] ?? '0') . ' yrs, ' . ($work['months_worked'] ?? '0') . ' mo'; ?>)</small>
                </span></td>
                <td><span class="prefilled"><?php echo htmlspecialchars($work['employment_type'] ?? ''); ?></span></td>
            </tr>
            <?php endforeach; ?>
        </table>
        <?php else: ?>
        <p><em>No employment history records available</em></p>
        <?php endif; ?>

        <div class="appendix-title" style="margin-top: 20px;">References</div>
        <?php if (!empty($arplReferences)): ?>
        <table class="ft">
            <tr><th style="width:25%;">Name</th><th style="width:20%;">Position</th><th style="width:25%;">Company</th><th style="width:15%;">Phone</th><th style="width:15%;">Email</th></tr>
            <?php foreach ($arplReferences as $ref): ?>
            <tr>
                <td><span class="prefilled"><?php echo htmlspecialchars(($ref['reference_name'] ?? '') . ' ' . ($ref['reference_surname'] ?? '')); ?></span></td>
                <td><span class="prefilled"><?php echo htmlspecialchars($ref['job_position'] ?? ''); ?></span></td>
                <td><span class="prefilled"><?php echo htmlspecialchars($ref['company_name'] ?? ''); ?></span></td>
                <td><span class="prefilled"><?php echo htmlspecialchars($ref['reference_phone'] ?? ''); ?></span></td>
                <td><span class="prefilled" style="font-size:12px;"><?php echo htmlspecialchars($ref['reference_email'] ?? ''); ?></span></td>
            </tr>
            <?php endforeach; ?>
        </table>
        <?php else: ?>
        <p><em>No references records available</em></p>
        <?php endif; ?>
    </div>

    <!-- PAGE 5: QUALIFICATIONS & SUPPORTING DOCUMENTS -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Qualifications & Documents</td></tr>
        </table>

        <div class="appendix-title">Educational Qualifications</div>
        <?php if (!empty($arplQualifications)): ?>
        <table class="ft">
            <tr><th style="width:35%;">Qualification</th><th style="width:20%;">Level</th><th style="width:25%;">Institution</th><th style="width:10%;">Year</th><th style="width:10%;">Status</th></tr>
            <?php foreach ($arplQualifications as $qual): ?>
            <tr>
                <td><span class="prefilled"><?php echo htmlspecialchars($qual['qualification_name'] ?? ''); ?></span></td>
                <td><span class="prefilled"><?php echo htmlspecialchars($qual['qualification_level'] ?? ''); ?></span></td>
                <td><span class="prefilled"><?php echo htmlspecialchars($qual['institution_name'] ?? ''); ?></span></td>
                <td style="text-align:center;"><span class="prefilled"><?php echo $qual['year_obtained'] ?? ''; ?></span></td>
                <td style="text-align:center;"><span class="prefilled"><?php echo $qual['is_primary'] ? '<b>Primary</b>' : 'Support'; ?></span></td>
            </tr>
            <?php endforeach; ?>
        </table>
        <?php else: ?>
        <p><em>No qualification records available</em></p>
        <?php endif; ?>

        <!-- SUPPORTING DOCUMENTS SECTION (ID, CV, QUALIFICATIONS) -->
        <div class="appendix-title" style="margin-top: 25px;">Supporting Documents</div>
        
        <?php if (!empty($learnerDocuments)): ?>
        <p style="font-size:11px;color:#666;margin:5px 0 10px;">Documents attached to this portfolio for assessment:</p>
        
        <table class="ft" style="font-size:11px;margin-bottom:15px;">
            <tr>
                <th style="width:8%;text-align:center;">No</th>
                <th style="width:35%;">Document Type</th>
                <th style="width:40%;">Document Name</th>
                <th style="width:17%;text-align:center;">Upload Date</th>
            </tr>
            <?php 
            $docCount = 0;
            foreach ($learnerDocuments as $doc): 
                $docName = htmlspecialchars($doc['documentName'] ?? $doc['learner_document'] ?? 'Document');
                
                // Skip LMIS Registration - not needed in ARPL PDF
                if (stripos($docName, 'lmis') !== false) {
                    continue;
                }
                
                $docCount++;
                $docType = htmlspecialchars($doc['document_type'] ?? 'Document');
                $uploadDate = isset($doc['upload_date']) ? date('d M Y', strtotime($doc['upload_date'])) : 'N/A';
                $status = htmlspecialchars($doc['status'] ?? 'Pending');
                
                // Determine document type for display
                $displayType = $docType;
                if (empty($docType) || $docType === 'Document') {
                    if (stripos($docName, 'id') !== false || stripos($docName, 'poe') !== false) {
                        $displayType = 'ID Document';
                    } elseif (stripos($docName, 'cv') !== false) {
                        $displayType = 'Curriculum Vitae (CV)';
                    } elseif (stripos($docName, 'cert') !== false) {
                        $displayType = 'Certificate/Qualification';
                    } elseif (stripos($docName, 'qual') !== false) {
                        $displayType = 'Qualification';
                    } else {
                        $displayType = 'Supporting Document';
                    }
                } else {
                    if (stripos($docType, 'id') !== false) {
                        $displayType = 'ID Document';
                    } elseif (stripos($docType, 'cv') !== false) {
                        $displayType = 'Curriculum Vitae (CV)';
                    } elseif (stripos($docType, 'cert') !== false || stripos($docType, 'qual') !== false) {
                        $displayType = 'Qualification';
                    }
                }
            ?>
            <tr>
                <td style="text-align:center;font-weight:bold;"><?php echo $docCount; ?></td>
                <td><strong><?php echo $displayType; ?></strong></td>
                <td><span class="prefilled"><?php echo $docName; ?></span></td>
                <td style="text-align:center;"><span class="prefilled"><?php echo $uploadDate; ?></span></td>
            </tr>
            <?php endforeach; ?>
        </table>
        
        <p style="font-size:10px;color:#666;margin:10px 0 5px;">
            <strong>Total Documents:</strong> 
            <?php 
            $totalDocs = 0;
            foreach ($learnerDocuments as $doc) {
                $docName = $doc['documentName'] ?? $doc['learner_document'] ?? 'Document';
                if (stripos($docName, 'lmis') === false) {
                    $totalDocs++;
                }
            }
            echo $totalDocs;
            ?>
        </p>
        
        <!-- DOCUMENT PREVIEWS -->
        <?php 
        $docPreviewCount = 0;
        foreach ($learnerDocuments as $doc): 
            $docName = htmlspecialchars($doc['documentName'] ?? 'Document');
            
            // Skip LMIS Registration - not needed in ARPL PDF
            if (stripos($docName, 'lmis') !== false) {
                continue;
            }
            
            $docPreviewCount++;
            
            // Get the file path
            $filePath = $doc['learner_document'] ?? '';
            
            // Construct full path to document
            // Documents can be in /xampp/htdocs/assessorReport2/learner_documents/ or same directory
            $possiblePaths = [
                'C:/xampp/htdocs/assessorReport2/learner_documents/' . $filePath,
                'C:/xampp/htdocs/assessorReport2/learner_documents/' . basename($filePath),
                dirname(__FILE__) . '/../' . $filePath,
            ];
            
            $actualFile = null;
            foreach ($possiblePaths as $path) {
                if (file_exists($path)) {
                    $actualFile = $path;
                    break;
                }
            }
            
            if ($actualFile && file_exists($actualFile)):
                $fileExt = strtolower(pathinfo($actualFile, PATHINFO_EXTENSION));
                
                // Check file size (skip if too large > 5MB for PDF embedding)
                $fileSize = filesize($actualFile);
                
                if ($fileSize < 5242880): // 5MB limit
                    // Embed file as base64
                    $fileData = file_get_contents($actualFile);
                    $base64Data = base64_encode($fileData);
                    
                    if ($fileExt === 'pdf'):
                        $mimeType = 'application/pdf';
                    elseif (in_array($fileExt, ['jpg', 'jpeg', 'png', 'gif'])):
                        $mimeType = 'image/' . ($fileExt === 'jpg' ? 'jpeg' : $fileExt);
                    else:
                        $mimeType = 'application/octet-stream';
                    endif;
        ?>
        
        <!-- Document Preview -->
        <div style="margin:15px 0;padding:10px;border:1px solid #ddd;border-radius:4px;page-break-inside:avoid;">
            <div style="font-size:11px;font-weight:bold;margin-bottom:8px;color:#333;">
                Document <?php echo $docPreviewCount; ?>: <?php echo $docName; ?>
            </div>
            
            <?php if (in_array($fileExt, ['jpg', 'jpeg', 'png', 'gif'])): ?>
                <!-- Image Preview -->
                <div style="margin:5px 0;text-align:center;">
                    <img src="data:<?php echo $mimeType; ?>;base64,<?php echo $base64Data; ?>" 
                         style="max-width:100%;height:auto;border:1px solid #ccc;padding:5px;" 
                         alt="<?php echo $docName; ?>">
                </div>
            <?php elseif ($fileExt === 'pdf'): ?>
                <!-- PDF Embed -->
                <div style="margin:5px 0;background:#f5f5f5;padding:10px;border:1px solid #e0e0e0;text-align:center;">
                    <embed src="data:application/pdf;base64,<?php echo $base64Data; ?>" 
                           type="application/pdf" 
                           style="width:100%;height:400px;border:none;" />
                </div>
            <?php endif; ?>
            
            <div style="font-size:9px;color:#999;margin-top:5px;">
                File size: <?php echo round($fileSize / 1024, 2); ?> KB | 
                Type: <?php echo strtoupper($fileExt); ?>
            </div>
        </div>
        
        <?php 
                else:
                    // File too large, show warning
                    ?>
                    <div style="margin:10px 0;padding:8px;background:#fff3cd;border:1px solid #ffc107;border-radius:3px;font-size:10px;">
                        <strong><?php echo $docName; ?></strong> - File too large to embed (<?php echo round($fileSize / 1024 / 1024, 2); ?> MB). 
                        Document available in supporting materials.
                    </div>
                    <?php
                endif;
            endif;
        endforeach;
        ?>
        
        <?php else: ?>
        <div style="padding:12px;background:#fff3cd;border:1px solid #ffc107;border-radius:3px;margin:10px 0;font-size:11px;">
            <strong>⚠ No supporting documents attached</strong><br>
            <small>ID documents, CV, and qualifications have not yet been uploaded.</small>
        </div>
        <?php endif; ?>
    </div>

    <!-- FINAL SUCCESS PAGE -->
    <div class="page" style="text-align: center; padding: 100px 40px;">
        <div style="font-size: 14px; color: #666;">
            <p>✅ ARPL Portfolio Generated Successfully</p>
            <p style="font-size: 12px; color: #999;">
                Generated: <?php echo $today; ?><br>
                Learner: <?php echo htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']); ?><br>
                Trade: <?php echo htmlspecialchars($tradeName); ?> (<?php echo $ofo_code; ?>)<br>
                <br>
                This is a complete 12+ page ARPL portfolio ready for assessor review.
            </p>
        </div>
    </div>

    <!-- PAGE 6: APPENDIX B - COMPETENCY ACTIVITIES (PROFESSIONAL GRID FORMAT) -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Appendix B</td></tr>
        </table>

        <div class="appendix-title">Appendix B: Competency Proficiency Scale & Trade Activities Assessment</div>
        
        <!-- COMPETENCY SCALE REFERENCE -->
        <p style="font-size:13pt;font-weight:bold;margin:15px 0 8px;">Competency Rating Scale Reference</p>
        <table class="ft" style="margin-bottom:20px;">
            <tr>
                <th style="width:8%;text-align:center;">Level</th>
                <th style="width:20%;text-align:center;">Proficiency</th>
                <th style="width:72%;">Description</th>
            </tr>
            <?php 
            $defaultScale = [
                ['level' => 1, 'name' => 'Fundamental', 'desc' => 'Demonstrates awareness and basic understanding of core concepts'],
                ['level' => 2, 'name' => 'Novice', 'desc' => 'Can apply knowledge with guidance and supervision required'],
                ['level' => 3, 'name' => 'Competent', 'desc' => 'Can work independently and competently without supervision'],
                ['level' => 4, 'name' => 'Proficient', 'desc' => 'Demonstrates mastery; can mentor others and troubleshoot complex issues'],
                ['level' => 5, 'name' => 'Expert', 'desc' => 'Recognized as expert; sets standards and leads developments in field']
            ];
            
            if (!empty($competencyScale)) {
                foreach ($competencyScale as $scale) {
                    $level = $scale['level_number'] ?? '?';
                    $name = $scale['level_name'] ?? 'N/A';
                    $desc = $scale['description'] ?? 'N/A';
                    echo "<tr>";
                    echo "<td style='text-align:center;'><strong>" . htmlspecialchars($level) . "</strong></td>";
                    echo "<td style='text-align:center;font-weight:bold;'>" . htmlspecialchars($name) . "</td>";
                    echo "<td>" . htmlspecialchars($desc) . "</td>";
                    echo "</tr>";
                }
            } else {
                foreach ($defaultScale as $scale) {
                    echo "<tr>";
                    echo "<td style='text-align:center;'><strong>" . $scale['level'] . "</strong></td>";
                    echo "<td style='text-align:center;font-weight:bold;'>" . $scale['name'] . "</td>";
                    echo "<td>" . $scale['desc'] . "</td>";
                    echo "</tr>";
                }
            }
            ?>
        </table>

        <!-- ACTIVITY ASSESSMENT GRID - FLUTTER CARD FORMAT -->
        <p style="font-size:13pt;font-weight:bold;margin:15px 0 3px;">Trade-Specific Activities Assessment - <?php echo htmlspecialchars($tradeName); ?></p>
        <p style="font-size:11px;color:#666;margin:3px 0 10px;">Competency ratings and assessor feedback for each activity. Ratings entered by accredited assessor during toolkit evaluation.</p>
        
        <?php if (!empty($appendixBActivities)): ?>
        <!-- Rating Scale Reference Bar -->
        <div style="background:#f5f5f5;border:1px solid #ddd;padding:8px;margin-bottom:12px;border-radius:4px;font-size:11px;">
            <strong>Rating Scale:</strong>
            <span style="margin-left:10px;"><span style="display:inline-block;width:12px;height:12px;background:#e74c3c;border-radius:2px;margin-right:3px;vertical-align:middle;"></span>1-2=Below</span>
            <span style="margin-left:10px;"><span style="display:inline-block;width:12px;height:12px;background:#f39c12;border-radius:2px;margin-right:3px;vertical-align:middle;"></span>3=Competent</span>
            <span style="margin-left:10px;"><span style="display:inline-block;width:12px;height:12px;background:#27ae60;border-radius:2px;margin-right:3px;vertical-align:middle;"></span>4-5=Advanced</span>
        </div>
        
        <!-- Activities as Cards (Row Format matching Flutter) -->
        <?php 
        $ratedCount = 0;
        $unratedCount = 0;
        foreach ($appendixBActivities as $idx => $activity): 
            $hasRating = !empty($activity['rating']);
            if ($hasRating) $ratedCount++;
            else $unratedCount++;
            
            // Determine rating styling
            $ratingColor = '#999999';
            $ratingBg = '#e8e8e8';
            $ratingText = '-';
            $ratingStars = '';
            $statusBadge = '<span style="background:#e8e8e8;color:#666;padding:3px 8px;border-radius:12px;font-size:10px;font-weight:bold;">NOT RATED</span>';
            
            if ($hasRating) {
                $rating = intval($activity['rating']);
                
                // Build star/circle indicator (Flutter style)
                for ($i = 1; $i <= 5; $i++) {
                    $circle = ($i <= $rating) ? '●' : '○';
                    $color = ($i <= $rating) ? '#006341' : '#ccc';
                    $ratingStars .= "<span style='color:$color;font-size:14px;margin-right:2px;'>$circle</span>";
                }
                
                if ($rating >= 4) {
                    $ratingColor = '#ffffff';
                    $ratingBg = '#27ae60'; // Green
                    $statusBadge = '<span style="background:#27ae60;color:#fff;padding:3px 8px;border-radius:12px;font-size:10px;font-weight:bold;">✓ RATED</span>';
                } elseif ($rating == 3) {
                    $ratingColor = '#ffffff';
                    $ratingBg = '#f39c12'; // Orange/Yellow
                    $statusBadge = '<span style="background:#f39c12;color:#fff;padding:3px 8px;border-radius:12px;font-size:10px;font-weight:bold;">✓ RATED</span>';
                } else {
                    $ratingColor = '#ffffff';
                    $ratingBg = '#e74c3c'; // Red
                    $statusBadge = '<span style="background:#e74c3c;color:#fff;padding:3px 8px;border-radius:12px;font-size:10px;font-weight:bold;">⚠ RATED</span>';
                }
                $ratingText = $rating;
            }
            
            // Map rating to proficiency level name
            $proficiencyText = 'Not Assessed';
            $proficiencyShort = '-';
            if ($hasRating) {
                $rating = intval($activity['rating']);
                switch($rating) {
                    case 1: $proficiencyText = 'Fundamental'; $proficiencyShort = 'F'; break;
                    case 2: $proficiencyText = 'Novice'; $proficiencyShort = 'N'; break;
                    case 3: $proficiencyText = 'Competent'; $proficiencyShort = 'C'; break;
                    case 4: $proficiencyText = 'Proficient'; $proficiencyShort = 'P'; break;
                    case 5: $proficiencyText = 'Expert'; $proficiencyShort = 'E'; break;
                }
            }
            
            $cardBg = $hasRating ? '#ffffff' : '#f9f9f9';
            $borderColor = $hasRating ? '#e8f5e9' : '#f5f5f5';
        ?>
        <!-- Activity Card -->
        <div style="background:<?php echo $cardBg; ?>;border:1px solid <?php echo $borderColor; ?>;border-radius:6px;padding:10px;margin-bottom:8px;page-break-inside:avoid;">
            <div style="display:flex;align-items:flex-start;gap:10px;">
                <!-- Activity Number Badge -->
                <div style="background:#f5f5f5;border-radius:4px;padding:6px 8px;min-width:30px;text-align:center;font-weight:bold;font-size:12px;">
                    <?php echo ($idx + 1); ?>
                </div>
                
                <!-- Activity Details (Middle) -->
                <div style="flex:1;">
                    <!-- Activity Name -->
                    <div style="font-weight:bold;font-size:12px;margin-bottom:4px;color:#333;">
                        <?php echo htmlspecialchars($activity['activity_name'] ?? 'Activity'); ?>
                    </div>
                    
                    <!-- Rating and Proficiency (Flutter Format) -->
                    <div style="font-size:11px;margin-bottom:3px;color:#666;">
                        <strong>Rating:</strong> 
                        <?php 
                        // Build circles like Flutter app
                        $circleStr = '';
                        if ($hasRating) {
                            $rating = intval($activity['rating']);
                            for ($i = 1; $i <= 5; $i++) {
                                $symbol = ($i <= $rating) ? '✓' : '○';
                                $color = ($i <= $rating) ? '#006341' : '#ccc';
                                $circleStr .= "<span style='color:$color;font-size:13px;margin-right:4px;font-weight:bold;'>$symbol</span>";
                            }
                            $circleStr .= " <strong style='color:#006341;margin-left:8px;'>(" . intval($activity['rating']) . "/5 - " . htmlspecialchars($proficiencyText) . ")</strong>";
                        } else {
                            $circleStr = "<span style='color:#ccc;font-size:13px;'>○ ○ ○ ○ ○</span> <em style='color:#999;margin-left:8px;'>(Not Assessed)</em>";
                        }
                        echo $circleStr;
                        ?>
                    </div>
                    
                    <!-- Assessor Comments -->
                    <?php if ($hasRating && !empty($activity['assessor_comments']) && $activity['assessor_comments'] !== '0'): ?>
                    <div style="font-size:10px;color:#555;margin-top:3px;padding:4px;background:#fafafa;border-left:2px solid #006341;padding-left:6px;">
                        <strong>Notes:</strong> <?php echo htmlspecialchars(substr($activity['assessor_comments'], 0, 80)); ?>
                    </div>
                    <?php endif; ?>
                    
                    <!-- Rating Date -->
                    <?php if ($hasRating && !empty($activity['rating_date'])): ?>
                    <div style="font-size:10px;color:#999;margin-top:3px;">
                        <strong>Assessed:</strong> <?php echo date('d M Y', strtotime($activity['rating_date'])); ?>
                    </div>
                    <?php endif; ?>
                </div>
                
                <!-- Status Badge (Right) -->
                <div style="min-width:80px;text-align:right;">
                    <?php echo $statusBadge; ?>
                </div>
            </div>
        </div>
        <?php endforeach; ?>
        <?php else: ?>
        <p><em>No activities available for this trade</em></p>
        <?php endif; ?>
        
        <!-- ASSESSMENT SUMMARY -->
        <div style="margin-top:15px;padding:10px;background:#f0f8f5;border-left:4px solid #27ae60;">
            <p style="font-size:11px;margin:0 0 5px 0;"><b>Assessment Summary:</b></p>
            <?php 
            $ratedCount = 0;
            $unratedCount = 0;
            foreach ($appendixBActivities as $activity) {
                if (!empty($activity['rating'])) {
                    $ratedCount++;
                } else {
                    $unratedCount++;
                }
            }
            $totalActivities = count($appendixBActivities);
            $percentComplete = $totalActivities > 0 ? round(($ratedCount / $totalActivities) * 100) : 0;
            ?>
            <p style="font-size:10px;margin:2px 0;color:#333;">
                ✓ Assessed: <strong><?php echo $ratedCount; ?></strong> of <?php echo $totalActivities; ?> activities 
                (<strong><?php echo $percentComplete; ?>%</strong> complete)
                <?php if ($unratedCount > 0): ?>
                    | Pending: <strong><?php echo $unratedCount; ?></strong> activities
                <?php endif; ?>
            </p>
        </div>
        
        <p style="font-size:10px;color:#666;margin-top:10px;line-height:1.4;">
            <b>Color Key:</b> 
            <span style="display:inline-block;background:#e74c3c;color:white;padding:1px 4px;margin:0 3px;font-size:9px;">1-2</span> Fundamental/Novice |
            <span style="display:inline-block;background:#f39c12;color:white;padding:1px 4px;margin:0 3px;font-size:9px;">3</span> Competent |
            <span style="display:inline-block;background:#27ae60;color:white;padding:1px 4px;margin:0 3px;font-size:9px;">4-5</span> Proficient/Expert |
            <span style="display:inline-block;background:#e8e8e8;color:#666;padding:1px 4px;margin:0 3px;font-size:9px;">-</span> Not Assessed
        </p>

        <!-- SIGNATURES - APPENDIX B -->
        <div style="margin-top:20px;padding:15px;background:#f9f9f9;border:1px solid #ddd;border-radius:4px;">
            <p style="font-size:12pt;font-weight:bold;margin:0 0 15px 0;">Competency Assessment Signatures:</p>
            <table class="sig-table">
                <tr>
                    <td style="width:45%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Learner Signature:</label>
                        <?php if ($learnerSignatureImage): ?>
                            <div style="margin-top:8px;">
                                <img src="<?php echo $learnerSignatureImage; ?>" style="max-width:100%;height:auto;max-height:80px;border:1px solid #ccc;border-radius:2px;">
                            </div>
                        <?php else: ?>
                            <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                        <?php endif; ?>
                    </td>
                    <td style="width:25%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Date:</label>
                        <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                    </td>
                    <td style="width:30%;"></td>
                </tr>
            </table>
            <table class="sig-table" style="margin-top:12px;">
                <tr>
                    <td style="width:45%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Assessor Signature:</label>
                        <?php if ($assessorSignatureImage): ?>
                            <div style="margin-top:8px;">
                                <img src="<?php echo $assessorSignatureImage; ?>" style="max-width:100%;height:auto;max-height:80px;border:1px solid #ccc;border-radius:2px;">
                            </div>
                        <?php else: ?>
                            <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                        <?php endif; ?>
                    </td>
                    <td style="width:25%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Date:</label>
                        <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                    </td>
                    <td style="width:30%;"></td>
                </tr>
            </table>
        </div>
    </div>

    <!-- PAGE 7: APPENDIX C - TRADE CURRICULUM CONTENT SUMMARY -->
    <div class="page">
        <table class="dht">
            <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?php echo htmlspecialchars($tradeName); ?></td><td><b>Trade Test Centre</b><br><?php echo htmlspecialchars($ctx['provider_name'] ?? ''); ?></td></tr>
            <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?php echo htmlspecialchars($ofo_code); ?></td><td><b>Accreditation no</b><br><?php echo htmlspecialchars($ctx['accreditation_n'] ?? ''); ?></td></tr>
            <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>9 of 30</td><td><b>Date revised</b><br><?php echo date('d/m/Y'); ?></td></tr>
        </table>

        <div class="sec-title">4. Appendix C: TRADE CURRICULUM CONTENT SUMMARY</div>

        <div style="font-size:14pt;font-weight:bold;margin-bottom:10px;">Trade Overview</div>

        <table class="ft" style="width:100%;font-size:12px;">
            <tr>
                <td style="width:200px;background-color:#f0f0f0;font-weight:bold;vertical-align:top;padding:8px;">SAFETY</td>
                <td style="vertical-align:top;padding:8px;">
                    • Standard construction industry safety principles and concepts<br>
                    • First Aid application and awareness<br>
                    • Identify different colour markings and symbolic safety signs<br>
                    • Risk assessment theories and principals and application thereof
                </td>
            </tr>
            <tr>
                <td style="width:200px;background-color:#f0f0f0;font-weight:bold;vertical-align:top;padding:8px;">HAND, POWER AND WORKSHOP TOOLS</td>
                <td style="vertical-align:top;padding:8px;">
                    • Knowledge of Trade related tools and machinery<br>
                    &nbsp;&nbsp;&nbsp;➢ Spanners<br>
                    &nbsp;&nbsp;&nbsp;➢ Screw drivers<br>
                    &nbsp;&nbsp;&nbsp;➢ Hammer and chisel<br>
                    &nbsp;&nbsp;&nbsp;➢ Saws and grinders<br>
                    &nbsp;&nbsp;&nbsp;➢ Knowledge of Trade related Tin-snips (left, right and straight)<br>
                    &nbsp;&nbsp;&nbsp;➢ Drilling machine<br>
                    &nbsp;&nbsp;&nbsp;➢ Pipe threader (manual and machine)<br>
                    &nbsp;&nbsp;&nbsp;➢ Forming/rolling machine<br>
                    &nbsp;&nbsp;&nbsp;➢ Guillotine<br>
                    • Correct use and care thereof
                </td>
            </tr>
            <tr>
                <td style="width:200px;background-color:#f0f0f0;font-weight:bold;vertical-align:top;padding:8px;">MEASURING EQUIPMENT</td>
                <td style="vertical-align:top;padding:8px;">
                    • Knowledge of Trade related measuring equipment<br>
                    &nbsp;&nbsp;&nbsp;➢ measuring tape and steel rule<br>
                    &nbsp;&nbsp;&nbsp;➢ Spirit level<br>
                    &nbsp;&nbsp;&nbsp;➢ Dumpy Level and Staff<br>
                    &nbsp;&nbsp;&nbsp;➢ Callipers (inside and outside)<br>
                    &nbsp;&nbsp;&nbsp;➢ Compass and divider<br>
                    &nbsp;&nbsp;&nbsp;➢ Pressure tester<br>
                    &nbsp;&nbsp;&nbsp;➢ Chalk line<br>
                    • Correct use and care thereof
                </td>
            </tr>
            <tr>
                <td style="width:200px;background-color:#f0f0f0;font-weight:bold;vertical-align:top;padding:8px;">PLANS AND DRAWINGS</td>
                <td style="vertical-align:top;padding:8px;">
                    • Read and interpret Trade related plans and drawings<br>
                    &nbsp;&nbsp;&nbsp;➢ Terms and definitions<br>
                    &nbsp;&nbsp;&nbsp;➢ Signs and symbols<br>
                    &nbsp;&nbsp;&nbsp;➢ Material lists<br>
                    &nbsp;&nbsp;&nbsp;➢ Orientation and levels<br>
                    &nbsp;&nbsp;&nbsp;➢ Existing services
                </td>
            </tr>
            <tr>
                <td style="width:200px;background-color:#f0f0f0;font-weight:bold;vertical-align:top;padding:8px;">IDENTIFICATION OF PIPE AND FITTINGS</td>
                <td style="vertical-align:top;padding:8px;">
                    • Understand the physical properties and characteristics of various pipe and fittings<br>
                    &nbsp;&nbsp;&nbsp;➢ Copper<br>
                    &nbsp;&nbsp;&nbsp;➢ uPvc<br>
                    &nbsp;&nbsp;&nbsp;➢ Galvanised Mild steel<br>
                    &nbsp;&nbsp;&nbsp;➢ HDPE<br>
                    &nbsp;&nbsp;&nbsp;➢ Cast Iron<br>
                    &nbsp;&nbsp;&nbsp;➢ Pex<br>
                    &nbsp;&nbsp;&nbsp;➢ Plastic<br>
                    • Correct use and application of the different types thereof<br>
                    ➢ When to use screwed, capillary and compression joints
                </td>
            </tr>
            <tr>
                <td style="width:200px;background-color:#f0f0f0;font-weight:bold;vertical-align:top;padding:8px;">SITE ASSESSMENT</td>
                <td style="vertical-align:top;padding:8px;">
                    • Knowledge of how to conduct a site assessment<br>
                    &nbsp;&nbsp;&nbsp;➢ Orientation of site<br>
                    &nbsp;&nbsp;&nbsp;➢ Position of services<br>
                    &nbsp;&nbsp;&nbsp;➢ Position of sanitary ware<br>
                    &nbsp;&nbsp;&nbsp;➢ Position of wastes and drains<br>
                    &nbsp;&nbsp;&nbsp;➢ Liaising with main contractor
                </td>
            </tr>
            <tr>
                <td style="width:200px;background-color:#f0f0f0;font-weight:bold;vertical-align:top;padding:8px;">RISK ASSESSMENT</td>
                <td style="vertical-align:top;padding:8px;">
                    • Knowledge of how to conduct a risk assessment<br>
                    &nbsp;&nbsp;&nbsp;➢ Reduce to writing<br>
                    &nbsp;&nbsp;&nbsp;➢ Use of a checklist<br>
                    &nbsp;&nbsp;&nbsp;➢ Safety file<br>
                    &nbsp;&nbsp;&nbsp;➢ Training<br>
                    &nbsp;&nbsp;&nbsp;➢ Inspections<br>
                    &nbsp;&nbsp;&nbsp;➢ Certifications
                </td>
            </tr>
            <tr>
                <td style="width:200px;background-color:#f0f0f0;font-weight:bold;vertical-align:top;padding:8px;">SEPTIC TANK</td>
                <td style="vertical-align:top;padding:8px;">
                    • Knowledge of the installation and maintenance of a septic tank<br>
                    &nbsp;&nbsp;&nbsp;➢ Excavation<br>
                    &nbsp;&nbsp;&nbsp;➢ Building / installation of pre-cast tank<br>
                    &nbsp;&nbsp;&nbsp;➢ Invert levels<br>
                    &nbsp;&nbsp;&nbsp;➢ Access points<br>
                    &nbsp;&nbsp;&nbsp;➢ Backfilling<br>
                    &nbsp;&nbsp;&nbsp;➢ Compacting<br>
                    &nbsp;&nbsp;&nbsp;➢ Site clearing<br>
                    &nbsp;&nbsp;&nbsp;➢ Commissioning<br>
                    &nbsp;&nbsp;&nbsp;➢ Maintenance
                </td>
            </tr>
            <tr>
                <td style="width:200px;background-color:#f0f0f0;font-weight:bold;vertical-align:top;padding:8px;">SHEET METAL</td>
                <td style="vertical-align:top;padding:8px;">
                    • Knowledge of sheet metal fabrication<br>
                    &nbsp;&nbsp;&nbsp;➢ Different types of joints<br>
                    &nbsp;&nbsp;&nbsp;➢ Templates<br>
                    &nbsp;&nbsp;&nbsp;➢ Developments<br>
                    &nbsp;&nbsp;&nbsp;➢ Cutting and shaping<br>
                    • Correct use of tools
                </td>
            </tr>
        </table>

        <div class="sec-title" style="margin-top:20px;">5. EVALUATION CRITERIA. (What you would be expected to know)</div>

        <div class="sec-sub" style="margin-top:10px;">5.1 KNOWLEDGE</div>
        <div style="margin:10px 0 10px 20px;font-size:11px;line-height:1.4;">
            <div style="margin-bottom:8px;"><strong>5.1.1 Safety</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Knowledge of PPE safety wear</li>
                <li>Precautions to be taken when working in confined areas</li>
                <li>Precautions to be taken when working at heights</li>
                <li>Safe working areas</li>
                <li>Housekeeping</li>
                <li>Use of machines and fitted safety guards</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.2 Hand, Power and Workshop Tools</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Identify, use and care of the different hand tools</li>
                <li>Identify, use and care of workshop equipment and machines</li>
                <li>Identify, use and care of various hand power tools</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.3 Measuring Equipment</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Identify, use and care of different measuring devices</li>
                <li>Correct application of different methods of measure</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.4 Plans and Drawings</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Recall terms and definitions relating to plumbing drawings</li>
                <li>Interpret relevant signs, symbols and abbreviations</li>
                <li>Understand scales and tolerances</li>
                <li>Identify existing services</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.5 Pipe and Fittings</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Different physical properties of various piping materials and fittings</li>
                <li>Different characteristics of various piping materials and fittings</li>
                <li>Correct use and application of different pipes and fittings</li>
                <li>Understanding the different sizes, grades and class of pipes</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.6 Transportation, Handling and Storage of Materials</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Correct transportation of materials to site</li>
                <li>Safe handling of materials on site</li>
                <li>Secure storage of materials on site</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.7 Access Equipment</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Identify, use and care of ladders</li>
                <li>Identify use and care of scaffolding</li>
                <li>Ability to set up and secure access equipment</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.8 Hot Water Systems</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Explain and allow for expansion in hot water systems</li>
                <li>Understand pressure ratings and limits</li>
                <li>Identify colour codes for pressure ratings</li>
                <li>Identify different types of hot water geysers and boilers including solar</li>
                <li>Identify and correctly position and install the required valves and safety devices</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.9 Cold Water Systems</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Explain and prevent freezing (contraction) in cold water systems</li>
                <li>Understand pressure ratings and limits</li>
                <li>Identify colour codes for pressure ratings</li>
                <li>Identify and correctly position and install the required valves and safety devices</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.10 Rain Water Systems</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Ability to install gutters and downpipes as per drawing/instruction</li>
                <li>Ability to install flashing as per drawing/instruction</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.11 Above Ground Drainage System</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Ability to correctly install waste pipes and drains</li>
                <li>Understanding the gradient (fall) of branches and drain pipes</li>
                <li>Understanding of the functions and installation of branches, vents, traps and inspection eyes</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.12 Below Ground Drainage Systems</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Ability to correctly install drains and traps</li>
                <li>Understanding gradient (fall) of drain pipes</li>
                <li>Set-out, excavate and bed the drain pipe trench</li>
                <li>Correctly lay and join drain pipes</li>
                <li>Identify acceptable backfill material and methods</li>
                <li>Understand the difference between a manhole and an access chamber</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.13 SANS Codes and National Building Regulations</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Name the SANS codes relevant to the plumbing trade</li>
                <li>Interpret the relevant SANS codes</li>
                <li>Understanding of the National Building Regulations</li>
                <li>Understanding of the municipal by-laws</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.14 Sanitary Ware</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Different trade related sanitary ware products</li>
                <li>Water saving devices</li>
                <li>Ability to plan, prepare and install according to instructions</li>
                <li>Colours, textures and finishes</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.15 Trenching and Backfill</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Understand the relevant regulations</li>
                <li>Be able to set-out and excavate as per the drawing or instruction</li>
                <li>Apply correct shoring methods</li>
                <li>Use the correct backfill medium</li>
                <li>Compact the backfill correctly per requirements</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.16 Basic Building Works</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Perform basic building works ie. Manhole and inspection chamber</li>
                <li>Identify the different mortar mixes and concrete strength requirements</li>
                <li>Mark and do wall chasings</li>
                <li>Excavations and backfill per regulations</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.17 Valves and Terminal Fittings</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Identify and name various valves and terminal fittings used in the trade</li>
                <li>Correctly install valves and terminal fittings</li>
                <li>Advise on processes of maintenance of valves and terminal fittings</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.18 Hydraulic Loading and Air Test</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Correctly calculate hydraulic loads</li>
                <li>Explain flow velocities and the dangers of overloading</li>
                <li>Setting up and use of an air pressure-tester related to drains</li>
                <li>Monitoring and recording of results</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.19 Fitting and Reading of Water Meters</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Correctly install and maintain water meters</li>
                <li>Explain the different types of water meter</li>
                <li>Understand regulations and requirements regarding water meters</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.20 Brazing and Soldering</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Explain the function of and describe the different fluxes</li>
                <li>Use a gas flame for soldering and tinning</li>
                <li>Use an oxy-acetylene flame for brazing</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.21 Jointing and Laying of Piping</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Explain the different characteristics of pipe types and fittings</li>
                <li>When and how to use screwed, capillary and compression jointing methods</li>
                <li>Securing and protection of pipe work from the elements</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.22 Site Assessment</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Ability to relate physical site with the plan or drawing</li>
                <li>Orientation and position of appliances</li>
                <li>Identifying existing services</li>
                <li>Liaising with the main contractor</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.23 Risk Assessment</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Report reduced to writing</li>
                <li>Use of a checklist</li>
                <li>Use of a safety file</li>
                <li>Ability to conduct training, inspections and toolbox talks</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.24 Septic Tank</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Understand and describe the processes involved in the installation of a septic tank from plan to commissioning</li>
                <li>Explain how it works and the importance of invert levels</li>
                <li>Ability to recall the codes of practice related to a septic tank installation</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.1.25 Sheet Metal Work</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Use of different jointing methods</li>
                <li>Use of LH, RH, Straight tin-snips for different shapes</li>
                <li>Use of tools and machinery to fabricate gutters, down-pipes and flashing</li>
                <li>Ability to draw a development of a sheet metal pattern to form a 3D object</li>
            </ul>
        </div>

        <div class="sec-sub" style="margin-top:20px;">5.2 INTEGRATED KNOWLEDGE AND PRACTICAL</div>
        <div style="margin:10px 0 10px 20px;font-size:11px;line-height:1.4;">
            <div style="margin-bottom:8px;"><strong>5.2.1 Measuring Equipment</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Find various levels per a simple drawing using a dumpy level</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.2.2 Plans and Drawings</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Determine position of various valves and appliances from a simple plan</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.2.3 Hot Water System</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Install plumbing for a standard electric hot water heater</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.2.4 Above Ground Drainage System</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Install a single stack system from a simple drawing</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.2.5 Brazing and Soldering and Pipe Jointing</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Make up a series of pipe configurations as per a drawing</li>
            </ul>

            <div style="margin-bottom:8px;"><strong>5.2.6 Below Ground Drainage System and Trenching and Backfill</strong></div>
            <ul style="margin:5px 0 15px 30px;">
                <li>Mark out and lay a drainage system as per a drawing</li>
            </ul>
        </div>

        <div class="sec-sub" style="margin-top:20px;">5.3 WORKPLACE (Done during interview/evaluation)</div>
        <div style="margin:10px 0;font-size:11px;line-height:1.4;">
            <strong>Scope of assessment:</strong>
            <ul style="margin:5px 0 5px 25px;">
                <li>Processes and procedures for installation and testing of above ground soil waste and vent systems and sanitary ware appliances</li>
                <li>Processes and procedures for installation and testing of below-ground drainage systems and performing basic building work</li>
                <li>Procedures and processes for installation and maintenance of cold water and hot water systems</li>
                <li>Procedures and processes for installation and maintenance of rain water systems</li>
            </ul>
        </div>

        <!-- SIGNATURES - APPENDIX C -->
        <div style="margin-top:20px;padding:15px;background:#f9f9f9;border:1px solid #ddd;border-radius:4px;">
            <p style="font-size:12pt;font-weight:bold;margin:0 0 15px 0;">Curriculum Content Review Signatures:</p>
            <table class="sig-table">
                <tr>
                    <td style="width:45%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Learner Signature:</label>
                        <?php if ($learnerSignatureImage): ?>
                            <div style="margin-top:8px;">
                                <img src="<?php echo $learnerSignatureImage; ?>" style="max-width:100%;height:auto;max-height:80px;border:1px solid #ccc;border-radius:2px;">
                            </div>
                        <?php else: ?>
                            <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                        <?php endif; ?>
                    </td>
                    <td style="width:25%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Date:</label>
                        <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                    </td>
                    <td style="width:30%;"></td>
                </tr>
            </table>
            <table class="sig-table" style="margin-top:12px;">
                <tr>
                    <td style="width:45%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Assessor Signature:</label>
                        <?php if ($assessorSignatureImage): ?>
                            <div style="margin-top:8px;">
                                <img src="<?php echo $assessorSignatureImage; ?>" style="max-width:100%;height:auto;max-height:80px;border:1px solid #ccc;border-radius:2px;">
                            </div>
                        <?php else: ?>
                            <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                        <?php endif; ?>
                    </td>
                    <td style="width:25%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Date:</label>
                        <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                    </td>
                    <td style="width:30%;"></td>
                </tr>
            </table>
        </div>
    </div>

    <!-- PAGE 7: APPENDIX D - GAP CLOSURE REPORT -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio</td></tr>
            <tr><td colspan="2">Appendix D: Gap Closure Report</td></tr>
        </table>

        <div class="appendix-title">Appendix D: Gap Closure Report</div>

        <?php if ($gapAnalysisSubmission): ?>
        
        <!-- Learner Information -->
        <table class="ft" style="font-size:12px;margin-bottom:15px;">
            <tr>
                <td style="width:30%;background:#f2f2f2;font-weight:bold;">Candidate Name:</td>
                <td><span class="prefilled"><?php echo htmlspecialchars(($learner['FirstName'] ?? '') . ' ' . ($learner['LastName'] ?? $learner['Surname'] ?? '')); ?></span></td>
            </tr>
            <tr>
                <td style="width:30%;background:#f2f2f2;font-weight:bold;">ID No.:</td>
                <td><span class="prefilled"><?php echo htmlspecialchars($learner['IDNumber'] ?? 'N/A'); ?></span></td>
            </tr>
            <tr>
                <td style="width:30%;background:#f2f2f2;font-weight:bold;">Trade:</td>
                <td><span class="prefilled"><?php echo htmlspecialchars($tradeName); ?></span></td>
            </tr>
            <tr>
                <td style="width:30%;background:#f2f2f2;font-weight:bold;">Assessment Date:</td>
                <td><span class="prefilled"><?php echo $gapAnalysisSubmission['assess_date'] ? htmlspecialchars(date('d M Y', strtotime($gapAnalysisSubmission['assess_date']))) : 'N/A'; ?></span></td>
            </tr>
            <tr>
                <td style="width:30%;background:#f2f2f2;font-weight:bold;">Assessor Name:</td>
                <td><span class="prefilled"><?php echo htmlspecialchars($gapAnalysisSubmission['assessor_name'] ?? 'N/A'); ?></span></td>
            </tr>
            <tr>
                <td style="width:30%;background:#f2f2f2;font-weight:bold;">Assessor No.:</td>
                <td><span class="prefilled"><?php echo htmlspecialchars($gapAnalysisSubmission['assessor_no'] ?? 'N/A'); ?></span></td>
            </tr>
        </table>

        <!-- Task Ratings Table -->
        <?php if (!empty($gapAnalysisTasks)): ?>
        <p style="font-size:12pt;font-weight:bold;margin:15px 0 10px 0;">Trade-Specific Task Assessment:</p>
        
        <table class="ft" style="font-size:11px;">
            <tr>
                <th style="width:8%;text-align:center;">No.</th>
                <th style="width:50%;text-align:left;">Task</th>
                <th style="width:22%;text-align:center;">Assessment Method</th>
                <th style="width:20%;text-align:center;">Rating</th>
            </tr>
            <?php foreach ($gapAnalysisTasks as $task): ?>
            <tr>
                <td style="text-align:center;padding:6px;border:1px solid #ccc;"><?php echo htmlspecialchars($task['TaskNo'] ?? '-'); ?></td>
                <td style="padding:6px;border:1px solid #ccc;"><?php echo htmlspecialchars($task['TaskName'] ?? 'N/A'); ?></td>
                <td style="text-align:center;padding:6px;border:1px solid #ccc;"><?php echo htmlspecialchars($task['AssessmentMethod'] ?? '-'); ?></td>
                <td style="text-align:center;padding:6px;border:1px solid #ccc;font-weight:bold;">
                    <?php 
                    $rating = $task['rating'] ?? null;
                    $ratingText = '-';
                    $ratingColor = '#999';
                    if ($rating === 'Bad') { $ratingText = 'Bad'; $ratingColor = '#e74c3c'; }
                    elseif ($rating === 'Fair') { $ratingText = 'Fair'; $ratingColor = '#f39c12'; }
                    elseif ($rating === 'Good') { $ratingText = 'Good'; $ratingColor = '#27ae60'; }
                    echo "<span style='color:$ratingColor;'>$ratingText</span>";
                    ?>
                </td>
            </tr>
            <?php endforeach; ?>
        </table>
        <?php endif; ?>

        <!-- Assessor Comments -->
        <p style="font-size:12pt;font-weight:bold;margin:15px 0 8px 0;">Assessor Comments:</p>
        <div style="border:1px solid #ccc;padding:10px;min-height:60px;background:#fafafa;font-size:11px;line-height:1.4;">
            <?php echo nl2br(htmlspecialchars($gapAnalysisSubmission['comments'] ?? 'No comments recorded')); ?>
        </div>

        <!-- Signature Block -->
        <div style="margin-top:25px;padding-top:15px;border-top:1px solid #ddd;">
            <table style="width:100%;border-collapse:collapse;">
                <tr>
                    <td style="width:45%;vertical-align:top;padding-right:10px;">
                        <label style="font-weight:bold;display:block;margin-bottom:8px;">Assessor Signature:</label>
                        <div style="height:40px;border-bottom:1px solid #000;"></div>
                        <div style="font-size:9px;margin-top:4px;">Assessor</div>
                    </td>
                    <td style="width:25%;vertical-align:top;padding:0 10px;">
                        <label style="font-weight:bold;display:block;margin-bottom:8px;">Date:</label>
                        <div style="height:40px;border-bottom:1px solid #000;"></div>
                    </td>
                    <td style="width:30%;vertical-align:top;padding-left:10px;">
                        <label style="font-weight:bold;display:block;margin-bottom:8px;">Candidate Signature:</label>
                        <div style="height:40px;border-bottom:1px solid #000;"></div>
                        <div style="font-size:9px;margin-top:4px;">Candidate</div>
                    </td>
                </tr>
            </table>
        </div>

        <!-- Footer -->
        <div style="margin-top:15px;padding-top:10px;border-top:1px solid #ddd;font-size:9px;color:#666;text-align:center;">
            <strong>Document Reference:</strong> ARPL Gap Closure Report | Version 1 of 2017 | Date: <?php echo date('d M Y'); ?>
        </div>

        <?php else: ?>
        
        <!-- No Gap Analysis Data -->
        <div style="background:#fff3cd;border:1px solid #ffc107;padding:15px;border-radius:4px;margin:20px 0;">
            <p style="font-size:12px;margin:0;">
                <strong>Note:</strong> No Gap Closure Report data is currently available for this learner. 
                A gap analysis assessment must be completed and saved to populate this section.
            </p>
        </div>

        <?php endif; ?>
    </div>

    <!-- PAGE 8: APPENDIX E - PRACTICAL SKILLS ASSESSMENT EVALUATION CHECKLIST -->
    <div class="page">
        <table class="dht">
            <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['siteName'] ?? '') ?></td></tr>
            <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= htmlspecialchars($ofo_code) ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
            <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>8 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
        </table>

        <div class="sec-title">6. Appendix E: PRACTICAL SKILLS ASSESSMENT EVALUATION CHECKLIST
            <span style="font-size:12pt;font-weight:normal;">(<?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?>)</span>
        </div>

        <?php
        $practicalCriteria = [
            'Safety','Hand, power and workshop tools','Measuring equipment','Plans and drawings',
            'Identification of pipe and fittings','Sanitary ware',
            'Transportation, handling and storage of materials','Access equipment',
            'Hot water system','Cold water system','Rain water system',
            'Above ground drainage system','Below ground drainage system',
            'SANS Codes and National Building Regulations','Sanitary ware appliances',
            'Trenching and Backfill','Basic building works','Valves and Terminal Fixtures',
            'Hydraulic loading and Air Test','Install and read of water meters',
            'Brazing and soldering','Jointing and installing of piping',
            'Site assessment','Risk assessment'
        ];
        ?>
        
        <table class="ft" style="font-size:11px;margin-top:10px;">
            <tr>
                <th class="l" style="width:60%;">Criteria (Has the candidate applied and used the following with regards to the trade)</th>
                <th style="width:20%;text-align:center;">Yes</th>
                <th style="width:20%;text-align:center;">No</th>
            </tr>
            <?php 
            // Load Appendix D data for this learner
            $appendixDData = null;
            if (isset($appendixDPapers) && !empty($appendixDPapers)) {
                $appendixDData = $appendixDPapers[0]; // Get first (most recent) record
            }
            
            foreach ($practicalCriteria as $index => $criteria): 
                $activity_num = $index + 1;
                $response = '';
                if ($appendixDData) {
                    $col = "activity_{$activity_num}";
                    if (isset($appendixDData[$col])) {
                        $response = strtoupper($appendixDData[$col]);
                    }
                }
            ?>
            <tr>
                <td><?= htmlspecialchars($criteria) ?></td>
                <td style="text-align:center;"><strong><?= ($response === 'YES' ? '✓' : '') ?></strong></td>
                <td style="text-align:center;"><strong><?= ($response === 'NO' ? '✗' : '') ?></strong></td>
            </tr>
            <?php endforeach; ?>
        </table>

        <table style="width:100%;margin-top:20px;border-collapse:collapse;">
            <tr>
                <td style="width:45%;padding:10px;border:1px solid #ccc;vertical-align:top;">
                    <div style="font-size:11pt;font-weight:bold;margin-bottom:5px;">Candidate Signature:</div>
                    <div style="height:40px;border-bottom:1px solid #000;"></div>
                </td>
                <td style="width:25%;padding:10px;border:1px solid #ccc;vertical-align:top;">
                    <div style="font-size:11pt;font-weight:bold;margin-bottom:5px;">Date:</div>
                    <div style="height:40px;border-bottom:1px solid #000;"></div>
                </td>
                <td style="width:30%;padding:10px;border:1px solid #ccc;vertical-align:top;">
                    <div style="font-size:11pt;font-weight:bold;margin-bottom:5px;">Assessor Signature:</div>
                    <div style="height:40px;border-bottom:1px solid #000;"></div>
                </td>
            </tr>
        </table>
    </div>

    <!-- PAGE 9: APPENDIX F - PRACTICAL SKILLS ASSESSMENT -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Appendix F</td></tr>
        </table>

        <div class="appendix-title">Appendix F: Practical Skills Assessment - <?php echo htmlspecialchars($tradeName); ?></div>
        
        <p style="font-size:12pt;margin:5px 0;">Competency ratings and assessor feedback for each practical activity.</p>

        <!-- Rating Scale Reference Bar -->
        <div style="background:#f5f5f5;border:1px solid #ddd;padding:8px;margin-bottom:12px;border-radius:4px;font-size:11px;">
            <strong>Rating Scale:</strong>
            <span style="margin-left:10px;"><span style="display:inline-block;width:12px;height:12px;background:#e74c3c;border-radius:2px;margin-right:3px;vertical-align:middle;"></span>1-2=Below</span>
            <span style="margin-left:10px;"><span style="display:inline-block;width:12px;height:12px;background:#f39c12;border-radius:2px;margin-right:3px;vertical-align:middle;"></span>3=Competent</span>
            <span style="margin-left:10px;"><span style="display:inline-block;width:12px;height:12px;background:#27ae60;border-radius:2px;margin-right:3px;vertical-align:middle;"></span>4-5=Advanced</span>
        </div>

        <?php if (!empty($appendixEActivities)): ?>
        <!-- Activity Cards with Flutter Circle Format -->
        <?php 
        $appendixERatedCount = 0;
        $appendixEUnratedCount = 0;
        foreach ($appendixEActivities as $idx => $activity): 
            $hasRating = !empty($activity['rating']);
            if ($hasRating) $appendixERatedCount++;
            else $appendixEUnratedCount++;
            
            // Map rating to proficiency level name
            $proficiencyText = 'Not Assessed';
            if ($hasRating) {
                $rating = intval($activity['rating']);
                switch($rating) {
                    case 1: $proficiencyText = 'Fundamental'; break;
                    case 2: $proficiencyText = 'Novice'; break;
                    case 3: $proficiencyText = 'Competent'; break;
                    case 4: $proficiencyText = 'Proficient'; break;
                    case 5: $proficiencyText = 'Expert'; break;
                }
            }
            
            // Status badge
            if ($hasRating) {
                $rating = intval($activity['rating']);
                if ($rating >= 4) {
                    $statusBadge = '<span style="background:#27ae60;color:#fff;padding:3px 8px;border-radius:12px;font-size:10px;font-weight:bold;">✓ RATED</span>';
                } elseif ($rating == 3) {
                    $statusBadge = '<span style="background:#f39c12;color:#fff;padding:3px 8px;border-radius:12px;font-size:10px;font-weight:bold;">✓ RATED</span>';
                } else {
                    $statusBadge = '<span style="background:#e74c3c;color:#fff;padding:3px 8px;border-radius:12px;font-size:10px;font-weight:bold;">⚠ RATED</span>';
                }
            } else {
                $statusBadge = '<span style="background:#e8e8e8;color:#666;padding:3px 8px;border-radius:12px;font-size:10px;font-weight:bold;">NOT RATED</span>';
            }
            
            $cardBg = $hasRating ? '#ffffff' : '#f9f9f9';
            $borderColor = $hasRating ? '#e8f5e9' : '#f5f5f5';
        ?>
        <!-- Activity Card -->
        <div style="background:<?php echo $cardBg; ?>;border:1px solid <?php echo $borderColor; ?>;border-radius:6px;padding:10px;margin-bottom:8px;page-break-inside:avoid;">
            <div style="display:flex;align-items:flex-start;gap:10px;">
                <!-- Activity Number Badge -->
                <div style="background:#f5f5f5;border-radius:4px;padding:6px 8px;min-width:30px;text-align:center;font-weight:bold;font-size:12px;">
                    <?php echo ($idx + 1); ?>
                </div>
                
                <!-- Activity Details (Middle) -->
                <div style="flex:1;">
                    <!-- Activity Name -->
                    <div style="font-weight:bold;font-size:12px;margin-bottom:4px;color:#333;">
                        <?php echo htmlspecialchars($activity['activity_name'] ?? 'Activity'); ?>
                    </div>
                    
                    <!-- Rating (Flutter Circle Format) -->
                    <div style="font-size:11px;margin-bottom:3px;color:#666;">
                        <strong>Rating:</strong> 
                        <?php 
                        $circleStr = '';
                        if ($hasRating) {
                            $rating = intval($activity['rating']);
                            for ($i = 1; $i <= 5; $i++) {
                                $symbol = ($i <= $rating) ? '✓' : '○';
                                $color = ($i <= $rating) ? '#006341' : '#ccc';
                                $circleStr .= "<span style='color:$color;font-size:13px;margin-right:4px;font-weight:bold;'>$symbol</span>";
                            }
                            $circleStr .= " <strong style='color:#006341;margin-left:8px;'>(" . intval($activity['rating']) . "/5 - " . htmlspecialchars($proficiencyText) . ")</strong>";
                        } else {
                            $circleStr = "<span style='color:#ccc;font-size:13px;'>○ ○ ○ ○ ○</span> <em style='color:#999;margin-left:8px;'>(Not Assessed)</em>";
                        }
                        echo $circleStr;
                        ?>
                    </div>
                    
                    <!-- Assessor Comments -->
                    <?php if ($hasRating && !empty($activity['assessor_comments']) && $activity['assessor_comments'] !== '0'): ?>
                    <div style="font-size:10px;color:#555;margin-top:3px;padding:4px;background:#fafafa;border-left:2px solid #006341;padding-left:6px;">
                        <strong>Notes:</strong> <?php echo htmlspecialchars(substr($activity['assessor_comments'], 0, 80)); ?>
                    </div>
                    <?php endif; ?>
                    
                    <!-- Rating Date -->
                    <?php if ($hasRating && !empty($activity['rating_date'])): ?>
                    <div style="font-size:10px;color:#999;margin-top:3px;">
                        <strong>Assessed:</strong> <?php echo date('d M Y', strtotime($activity['rating_date'])); ?>
                    </div>
                    <?php endif; ?>
                </div>
                
                <!-- Status Badge (Right) -->
                <div style="min-width:80px;text-align:right;">
                    <?php echo $statusBadge; ?>
                </div>
            </div>
        </div>
        <?php endforeach; ?>
        
        <!-- Assessment Summary -->
        <div style="margin-top:15px;padding:10px;background:#f0f8f5;border-left:4px solid #27ae60;">
            <p style="font-size:11px;margin:0 0 5px 0;"><b>Assessment Summary:</b></p>
            <?php 
            $appendixETotalActivities = count($appendixEActivities);
            $appendixEPercentComplete = $appendixETotalActivities > 0 ? round(($appendixERatedCount / $appendixETotalActivities) * 100) : 0;
            ?>
            <p style="font-size:10px;margin:2px 0;color:#333;">
                ✓ Assessed: <strong><?php echo $appendixERatedCount; ?></strong> of <?php echo $appendixETotalActivities; ?> activities 
                (<strong><?php echo $appendixEPercentComplete; ?>%</strong> complete)
                <?php if ($appendixEUnratedCount > 0): ?>
                    | Pending: <strong><?php echo $appendixEUnratedCount; ?></strong> activities
                <?php endif; ?>
            </p>
        </div>
        <?php else: ?>
        <p><em>No practical skills assessment data available</em></p>
        <?php endif; ?>

        <!-- SIGNATURES - APPENDIX E -->
        <div style="margin-top:20px;padding:15px;background:#f9f9f9;border:1px solid #ddd;border-radius:4px;">
            <p style="font-size:12pt;font-weight:bold;margin:0 0 15px 0;">Assessment Signatures:</p>
            <table class="sig-table">
                <tr>
                    <td style="width:45%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Learner Signature:</label>
                        <?php if ($learnerSignatureImage): ?>
                            <div style="margin-top:8px;">
                                <img src="<?php echo $learnerSignatureImage; ?>" style="max-width:100%;height:auto;max-height:80px;border:1px solid #ccc;border-radius:2px;">
                            </div>
                        <?php else: ?>
                            <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                        <?php endif; ?>
                    </td>
                    <td style="width:25%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Date:</label>
                        <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                    </td>
                    <td style="width:30%;"></td>
                </tr>
            </table>
            <table class="sig-table" style="margin-top:12px;">
                <tr>
                    <td style="width:45%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Assessor Signature:</label>
                        <?php if ($assessorSignatureImage): ?>
                            <div style="margin-top:8px;">
                                <img src="<?php echo $assessorSignatureImage; ?>" style="max-width:100%;height:auto;max-height:80px;border:1px solid #ccc;border-radius:2px;">
                            </div>
                        <?php else: ?>
                            <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                        <?php endif; ?>
                    </td>
                    <td style="width:25%;padding:10px;vertical-align:top;">
                        <label style="font-weight:bold;">Date:</label>
                        <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                    </td>
                    <td style="width:30%;"></td>
                </tr>
            </table>
        </div>
    </div>

    <!-- PAGE 10: APPENDIX H - ASSESSMENT AGREEMENT -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Appendix H</td></tr>
        </table>

        <div class="appendix-title">Appendix H: Assessment Evaluation Agreement</div>
        
        <p style="font-size:12pt;margin:10px 0;">
            This Agreement confirms that the above-named learner has agreed to undertake an Alternative Recognition of Prior Learning (ARPL) assessment for the <?php echo htmlspecialchars($tradeName); ?> qualification.
        </p>

        <table class="ft">
            <tr><td style="width:40%;"><b>Learner Name</b></td><td><?php echo htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']); ?></td></tr>
            <tr><td><b>Learner ID</b></td><td><?php echo $learnerID; ?></td></tr>
            <tr><td><b>ID Number</b></td><td><?php echo htmlspecialchars($learner['IDNumber'] ?? 'N/A'); ?></td></tr>
            <tr><td><b>Trade/Qualification</b></td><td><?php echo htmlspecialchars($tradeName); ?> (<?php echo $ofo_code; ?>)</td></tr>
            <tr><td><b>Assessment Date</b></td><td><?php echo $today; ?></td></tr>
            <tr><td><b>Assessor Name</b></td><td><?php echo htmlspecialchars(($facilitator['firstName'] ?? '') . ' ' . ($facilitator['lastName'] ?? '') ?: 'Assessment Coordinator'); ?></td></tr>
        </table>

        <p style="font-size:11pt;margin:20px 0;line-height:1.8;">
            By signing below, I confirm that:
            <br>1. I understand the ARPL process and requirements
            <br>2. I have provided truthful information about my experience
            <br>3. I consent to the assessment process and results
            <br>4. I have not misrepresented my qualifications or experience
        </p>

        <table class="ft">
            <tr><td style="width:50%;"><b>Learner Signature</b></td><td>________________________ Date: _________</td></tr>
            <tr><td><b>Assessor Signature</b></td><td>________________________ Date: _________</td></tr>
        </table>
    </div>
            <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>11 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
        </table>

        <div class="sec-title">8. Appendix H: ACCESS RECOMMENDATION
            <span style="font-size:12pt;font-weight:normal;">(<?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?>)</span>
        </div>

        <table class="ft">
            <tr><td style="width:38%;"><b>Name of the Candidate</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?></span></td></tr>
            <tr><td><b>Company</b></td><td><input type="text" placeholder="Employer / Company"></td></tr>
            <tr><td><b>Experience</b></td><td><input type="text" placeholder="Years and type of experience"></td></tr>
            <tr><td><b>Date of Birth</b></td>
                <td><span class="prefilled"><?= htmlspecialchars($learner['DateOfBirth'] ?? '') ?></span></td></tr>
        </table>

        <table class="ft" style="margin-top:10px;">
            <tr>
                <th style="width:36px;">No</th>
                <th>Results</th>
                <th style="width:120px;"></th>
                <th class="l">Remarks</th>
            </tr>
            <tr>
                <td class="c">1</td>
                <td><b>Knowledge assessment</b></td>
                <td class="c">
                    Ready <input type="radio" name="ka_<?=$learnerID?>" value="ready"><br>
                    Not Yet Ready <input type="radio" name="ka_<?=$learnerID?>" value="nyr">
                </td>
                <td><input type="text" placeholder="Remarks"></td>
            </tr>
            <tr>
                <td class="c">2</td>
                <td><b>Practical assessment</b></td>
                <td class="c">
                    Ready <input type="radio" name="pa_<?=$learnerID?>" value="ready"><br>
                    Not Yet Ready <input type="radio" name="pa_<?=$learnerID?>" value="nyr">
                </td>
                <td><input type="text" placeholder="Remarks"></td>
            </tr>
            <tr>
                <td class="c">3</td>
                <td><b>Workplace Observation</b></td>
                <td class="c">
                    Ready <input type="radio" name="wo_<?=$learnerID?>" value="ready"><br>
                    Not Yet Ready <input type="radio" name="wo_<?=$learnerID?>" value="nyr">
                </td>
                <td><input type="text" placeholder="Remarks"></td>
            </tr>
            <tr>
                <td class="c">4</td>
                <td colspan="3">
                    <b>Overall Result</b><br><br>
                    <label><input type="radio" name="overall_<?=$learnerID?>" value="trade_test">&nbsp; Recommended for trade test</label><br><br>
                    <label><input type="radio" name="overall_<?=$learnerID?>" value="gap_closure">&nbsp; Recommended for gap closure</label>
                </td>
            </tr>
        </table>

        <table style="width:100%;margin-top:20px;border-collapse:collapse;">
            <tr>
                <td style="width:40%;padding:10px;border:1px solid #ccc;vertical-align:top;">
                    <div style="font-size:11pt;font-weight:bold;margin-bottom:5px;">Signature of ARPL Candidate:</div>
                    <div style="height:40px;border-bottom:1px solid #000;"></div>
                </td>
                <td style="width:30%;padding:10px;border:1px solid #ccc;vertical-align:top;">
                    <div style="font-size:11pt;font-weight:bold;margin-bottom:5px;">Date:</div>
                    <div style="height:40px;border-bottom:1px solid #000;"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>
        <table style="width:100%;margin-top:10px;border-collapse:collapse;">
            <tr>
                <td style="width:40%;padding:10px;border:1px solid #ccc;vertical-align:top;">
                    <div style="font-size:11pt;font-weight:bold;margin-bottom:5px;">Signature of Assessor:</div>
                    <div style="height:40px;border-bottom:1px solid #000;"></div>
                </td>
                <td style="width:30%;padding:10px;border:1px solid #ccc;vertical-align:top;">
                    <div style="font-size:11pt;font-weight:bold;margin-bottom:5px;">Date:</div>
                    <div style="height:40px;border-bottom:1px solid #000;"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>
    </div>

    <!-- PAGE 11: APPENDIX I - ASSESSMENT EVALUATION AGREEMENT -->
    <div class="page">
        <table class="dht">
            <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
            <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= htmlspecialchars($ofo_code) ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
            <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>21 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
        </table>

        <div class="sec-title">10. Appendix I: ASSESSMENT EVALUATION AGREEMENT
            <span style="font-size:12pt;font-weight:normal;">(<?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?>)</span>
        </div>

        <p style="font-size:13pt;font-weight:bold;margin:15px 0 8px;">ASSESSMENT COMPONENTS</p>

        <p style="font-size:12pt;font-weight:bold;margin:10px 0 5px;">Knowledge Assessment (Summative)</p>
        <table class="ft">
            <tr>
                <th style="width:50px;">Q No</th>
                <th class="l">Question / Exercise</th>
                <th style="width:60px;">Max Marks</th>
                <th style="width:80px;">Score</th>
                <th style="width:50px;">%</th>
            </tr>
            <?php for ($i = 1; $i <= 5; $i++): ?>
            <tr>
                <td class="c"><b><?= $i ?></b></td>
                <td><input type="text" placeholder="Question" style="width:100%;"></td>
                <td class="c"><input type="text" placeholder="Max" style="width:100%;"></td>
                <td><input type="text" placeholder="Score" style="width:100%;"></td>
                <td class="c"><input type="text" placeholder="%" style="width:100%;"></td>
            </tr>
            <?php endfor; ?>
            <tr style="background:#e8eaf6;">
                <td colspan="2"><b>TOTAL KNOWLEDGE MARKS</b></td>
                <td class="c"><b>--</b></td>
                <td><input type="text" placeholder="Total" style="width:100%;"></td>
                <td class="c"><input type="text" placeholder="%" style="width:100%;"></td>
            </tr>
        </table>

        <p style="font-size:12pt;font-weight:bold;margin:10px 0 5px;">Practical Skills Assessment (Formative)</p>
        <table class="ft">
            <tr>
                <th style="width:50px;">Q No</th>
                <th class="l">Task / Exercise</th>
                <th style="width:60px;">Max Marks</th>
                <th style="width:80px;">Score</th>
                <th style="width:50px;">%</th>
            </tr>
            <?php for ($i = 1; $i <= 5; $i++): ?>
            <tr>
                <td class="c"><b><?= $i ?></b></td>
                <td><input type="text" placeholder="Task" style="width:100%;"></td>
                <td class="c"><input type="text" placeholder="Max" style="width:100%;"></td>
                <td><input type="text" placeholder="Score" style="width:100%;"></td>
                <td class="c"><input type="text" placeholder="%" style="width:100%;"></td>
            </tr>
            <?php endfor; ?>
            <tr style="background:#e8eaf6;">
                <td colspan="2"><b>TOTAL PRACTICAL MARKS</b></td>
                <td class="c"><b>--</b></td>
                <td><input type="text" placeholder="Total" style="width:100%;"></td>
                <td class="c"><input type="text" placeholder="%" style="width:100%;"></td>
            </tr>
        </table>

        <p style="font-size:12pt;font-weight:bold;margin:10px 0 5px;">Workplace Observation</p>
        <table class="ft">
            <tr>
                <th style="width:40px;">No</th>
                <th class="l">Tasks Observed</th>
                <th style="width:100px;">Technical Knowledge<br><small>(1=Fair 2=Good 3=Excellent)</small></th>
                <th style="width:100px;">Instruction Follow<br><small>(1=Fair 2=Good 3=Excellent)</small></th>
                <th style="width:100px;">Team Work<br><small>(1=Fair 2=Good 3=Excellent)</small></th>
            </tr>
            <?php for ($i = 1; $i <= 3; $i++): ?>
            <tr>
                <td class="c"><?= $i ?></td>
                <td><input type="text" placeholder="Observed task" style="width:100%;"></td>
                <td class="c">
                    <select style="width:100%;">
                        <option value="">--</option>
                        <option>1 – Fair</option>
                        <option>2 – Good</option>
                        <option>3 – Excellent</option>
                    </select>
                </td>
                <td class="c">
                    <select style="width:100%;">
                        <option value="">--</option>
                        <option>1 – Fair</option>
                        <option>2 – Good</option>
                        <option>3 – Excellent</option>
                    </select>
                </td>
                <td class="c">
                    <select style="width:100%;">
                        <option value="">--</option>
                        <option>1 – Fair</option>
                        <option>2 – Good</option>
                        <option>3 – Excellent</option>
                    </select>
                </td>
            </tr>
            <?php endfor; ?>
        </table>

        <p style="font-size:12pt;font-weight:bold;margin:15px 0 5px;">Assessor & Candidate Signatures</p>
        <table class="sig-table">
            <tr>
                <td style="width:40%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Assessor Signature:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Date:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>

        <table class="sig-table">
            <tr>
                <td style="width:40%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Candidate Signature:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Date:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>
    </div>

    <!-- PAGE 12: APPENDIX J - APPEALS FORM -->
    <div class="page">
        <table class="dht">
            <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
            <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= htmlspecialchars($ofo_code) ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
            <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>24 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
        </table>

        <div class="sec-title">11. Appendix J: APPEALS FORM
            <span style="font-size:12pt;font-weight:normal;">(<?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?>)</span>
        </div>

        <table class="ft">
            <tr><td style="width:38%;"><b>Name of ARPL Candidate:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?></span></td></tr>
            <tr><td><b>Name of Assessor:</b></td><td><span class="prefilled"><?= htmlspecialchars(($facilitator['firstName'] ?? '') . ' ' . ($facilitator['lastName'] ?? '')) ?></span></td></tr>
            <tr><td><b>Name of Institution:</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></span></td></tr>
            <tr><td><b>Name of Moderator:</b></td><td><input type="text" placeholder="Full name of moderator"></td></tr>
            <tr><td><b>Reason for Appeal:</b></td>
                <td><textarea rows="4" placeholder="State the reason for the appeal clearly..." style="width:100%;"></textarea></td></tr>
        </table>

        <p style="font-size:12pt;font-weight:bold;margin:15px 0 5px;">Signatures & Place</p>
        <table class="sig-table">
            <tr>
                <td style="width:33%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">ARPL Candidate:</label>
                    <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:33%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Place:</label>
                    <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:33%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Date:</label>
                    <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
            </tr>
        </table>

        <table class="sig-table">
            <tr>
                <td style="width:33%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Assessor:</label>
                    <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:33%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Place:</label>
                    <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:33%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Date:</label>
                    <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
            </tr>
        </table>

        <p style="font-size:12pt;font-weight:bold;margin:15px 0 5px;">Assessor Findings</p>
        <textarea rows="3" placeholder="Assessor's findings regarding the appeal..." style="width:100%;border:1px solid #ccc;padding:5px;"></textarea>

        <table class="sig-table" style="margin-top:12px;">
            <tr>
                <td style="width:40%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Assessor Signature:</label>
                    <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Date:</label>
                    <div style="height:50px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>

        <div class="note" style="margin-top:15px;">
            <b>NOTE:</b> ARPL candidate must state the reason for the appeal and forward to the moderator. The moderator must call a meeting within 1 week of receiving the appeal.
        </div>
    </div>

    <!-- PAGE 12: APPENDIX K - ACCESS RECOMMENDATION (Read-Only - From Database) -->
    <div class="page">
        <table class="dht">
            <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
            <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= htmlspecialchars($ofo_code) ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
            <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>25 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
        </table>

        <div class="sec-title">12. Appendix K: ACCESS RECOMMENDATION
            <span style="font-size:12pt;font-weight:normal;">(<?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?>)</span>
        </div>

        <?php
        // Determine recommendation status from database
        $hasRecommendation = $appendixI ? true : false;
        $isApproved = $hasRecommendation && (strtolower($appendixI['Status']) === 'ready' || strpos(strtolower($appendixI['Status']), 'recommended') !== false);
        $isNotReady = $hasRecommendation && strtolower($appendixI['Status']) === 'not yet ready';
        $statusText = $appendixI['Status'] ?? 'Not Yet Recorded';
        $statusColor = $isApproved ? '#d4edda' : ($isNotReady ? '#f8d7da' : '#e2e3e5');
        $statusTextColor = $isApproved ? '#155724' : ($isNotReady ? '#721c24' : '#383d41');
        ?>

        <table class="ft">
            <tr><td style="width:38%;"><b>Learner Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?></span></td></tr>
            <tr><td><b>ID Number:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['LearnerID'] ?? '') ?></span></td></tr>
            <tr><td><b>Trade:</b></td><td><span class="prefilled"><?= htmlspecialchars($tradeName) ?></span></td></tr>
            <tr><td><b>OFO Code:</b></td><td><span class="prefilled"><?= htmlspecialchars($appendixI['OFOCode'] ?? $ofo_code) ?></span></td></tr>
            <tr><td><b>Date of Recommendation:</b></td><td><span class="prefilled"><?= htmlspecialchars($appendixI['CreatedAt'] ? date('j M Y', strtotime($appendixI['CreatedAt'])) : 'Not Recorded') ?></span></td></tr>
        </table>

        <p style="font-size:13pt;font-weight:bold;margin:15px 0 8px;">RECOMMENDATION FOR ACCESS TO TRADE TEST</p>

        <div style="border:2px solid #333; padding:15px; margin:12px 0; background-color:#fff9f0;">
            <table style="width:100%;" class="ft">
                <tr>
                    <td style="width:50%; text-align:center; padding:15px; border-right:1px solid #ddd;">
                        <div style="font-size:14pt; font-weight:bold; margin-bottom:8px;">
                            <?php if ($isApproved): ?>
                                <span style="color:#155724;">✓ APPROVED</span>
                            <?php else: ?>
                                <span style="color:#ccc;">✗ NOT APPROVED</span>
                            <?php endif; ?>
                        </div>
                        <p style="font-size:11pt; margin:0;">APPROVED FOR TRADE TEST</p>
                    </td>
                    <td style="width:50%; text-align:center; padding:15px;">
                        <div style="font-size:14pt; font-weight:bold; margin-bottom:8px;">
                            <?php if ($isNotReady): ?>
                                <span style="color:#721c24;">✓ NOT READY</span>
                            <?php else: ?>
                                <span style="color:#ccc;">✗ NOT YET READY</span>
                            <?php endif; ?>
                        </div>
                        <p style="font-size:11pt; margin:0;">NOT YET READY FOR TRADE TEST</p>
                    </td>
                </tr>
            </table>
        </div>

        <p style="font-size:12pt;font-weight:bold;margin:15px 0 5px;">Recommendation Status</p>
        <table class="ft">
            <tr>
                <td style="width:38%;"><b>Current Status:</b></td>
                <td>
                    <span class="prefilled" style="padding:8px 15px; border-radius:3px; font-weight:bold; background-color:<?= $statusColor ?>; color:<?= $statusTextColor ?>; display:inline-block;">
                        <?= htmlspecialchars($statusText) ?>
                    </span>
                </td>
            </tr>
            <tr>
                <td><b>Recommendation ID:</b></td>
                <td><span class="prefilled"><?= htmlspecialchars($appendixI['RecommendationID'] ?? 'N/A') ?></span></td>
            </tr>
            <tr>
                <td><b>Last Updated:</b></td>
                <td><span class="prefilled"><?= htmlspecialchars($appendixI['UpdatedAt'] ? date('j M Y H:i', strtotime($appendixI['UpdatedAt'])) : 'N/A') ?></span></td>
            </tr>
        </table>

        <?php if (!empty($appendixI['Remarks'])): ?>
        <p style="font-size:12pt;font-weight:bold;margin:15px 0 5px;">Assessment Remarks</p>
        <div style="min-height:60px;border:1px solid #333;padding:10px;background-color:#f9f9f9; font-size:11pt;">
            <p style="margin:0;"><?= nl2br(htmlspecialchars($appendixI['Remarks'])) ?></p>
        </div>
        <?php endif; ?>

        <p style="font-size:12pt;font-weight:bold;margin:15px 0 5px;">Assessment Information</p>
        <table class="ft">
            <tr><td style="width:38%;"><b>Trade Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($appendixI['Trade'] ?? $tradeName) ?></span></td></tr>
            <tr><td><b>Recorded Date:</b></td><td><span class="prefilled"><?= htmlspecialchars($appendixI['CreatedAt'] ? date('j M Y H:i', strtotime($appendixI['CreatedAt'])) : 'N/A') ?></span></td></tr>
            <tr><td><b>Data Source:</b></td><td><span class="prefilled" style="font-size:10pt;"><?= htmlspecialchars($tableName ?? 'Not Found') ?></span></td></tr>
        </table>

        <div style="margin-top:15px; padding:10px; background-color:#f0f7ff; border-left:4px solid #2196F3; font-size:10pt;">
            <p style="margin:0;"><b>Note:</b> This recommendation data is retrieved from the database and displayed as a read-only record. 
            <?php if ($hasRecommendation): ?>
                Data is populated from <?= htmlspecialchars($tradeName) ?> Access Recommendation table.
            <?php else: ?>
                No recommendation has been recorded yet for this learner.
            <?php endif; ?>
            </p>
            <p style="margin:5px 0 0 0; color:#666; font-size:9pt;">DEBUG: <?= htmlspecialchars($debugInfo) ?></p>
        </div>
    </div>

    <!-- PAGE 13: APPENDIX L - STATEMENT OF RESULTS -->
    <div class="page">
        <table class="dht">
            <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
            <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= htmlspecialchars($ofo_code) ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
            <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>26 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
        </table>

        <div class="sec-title">13. Appendix L: Statement of Results: NAMB
            <span style="font-size:12pt;font-weight:normal;">(<?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?>)</span>
        </div>
        <div class="note"><b>NOTE:</b> This Statement of Results is not an Occupational Certificate but indicates that the learner/candidate has complied with the requirements of the knowledge, practical skills and workplace components of the Occupational (Trade) qualification.</div>

        <p style="font-size:13pt;font-weight:bold;margin:10px 0 5px;">Provider type</p>
        <table class="ft">
            <tr>
                <td>Assessment Centre &nbsp;<input type="checkbox" name="ptype_ac_<?=$learnerID?>" value="ac"></td>
                <td>Skills Development Provider (SDP) &nbsp;<input type="checkbox" name="ptype_sdp_<?=$learnerID?>" value="sdp" <?= !empty($ctx['provider_name']) ? 'checked' : '' ?>></td>
            </tr>
        </table>

        <p style="font-size:13pt;font-weight:bold;margin:10px 0 5px;">Provider Details</p>
        <table class="ft">
            <tr><td style="width:38%;"><b>Provider Name</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></span></td></tr>
            <tr><td><b>Provider Accreditation No</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></span></td></tr>
            <tr><td><b>Physical Address</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['p_address'] ?? '') ?></span></td></tr>
            <tr><td><b>Postal address</b></td><td><input type="text" placeholder="Postal address"></td></tr>
            <tr><td><b>Tel no</b></td><td><input type="tel" placeholder="Provider telephone"></td></tr>
            <tr><td><b>Fax no</b></td><td><input type="tel" placeholder="Provider fax"></td></tr>
            <tr><td><b>Contact person</b></td><td><input type="text" placeholder="Contact person name"></td></tr>
            <tr><td><b>Position</b></td><td><input type="text" placeholder="Position / Title"></td></tr>
            <tr><td><b>Cellphone no</b></td><td><input type="tel" placeholder="Cell number"></td></tr>
            <tr><td><b>E-mail address</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['email'] ?? '') ?></span></td></tr>
        </table>

        <p style="font-size:13pt;font-weight:bold;margin:10px 0 5px;">Candidate detail</p>
        <table class="ft">
            <tr>
                <td style="width:38%;"><b>Type</b></td>
                <td>Learner <input type="checkbox" name="ctype_learner_<?=$learnerID?>" value="learner" checked>
                    &nbsp;&nbsp; ARPL Process <input type="checkbox" name="ctype_arpl_<?=$learnerID?>" value="arpl" checked></td>
            </tr>
            <tr><td><b>Full Names</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?></span></td></tr>
            <tr><td><b>Surname</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['LastName']) ?></span></td></tr>
            <tr><td><b>ID Number</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['LearnerID'] ?? '') ?></span></td></tr>
            <tr><td><b>Address</b></td><td><span class="prefilled"><?= htmlspecialchars(($learner['AddressLine1'] ?? '') . ' ' . ($learner['AddressLine2'] ?? '')) ?></span></td></tr>
            <tr><td><b>Tel/Cell No</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['PhoneNumber'] ?? '') ?></span></td></tr>
            <tr><td><b>E-mail address</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['EmailAddress'] ?? '') ?></span></td></tr>
        </table>

        <p style="font-size:13pt;font-weight:bold;margin:10px 0 5px;">Trade information</p>
        <table class="ft">
            <tr>
                <th class="l">Qualification Title</th>
                <th>OFO Code</th>
                <th>SAQA Qualification ID</th>
                <th>NQF Level + Credits</th>
            </tr>
            <tr>
                <td><?= htmlspecialchars($tradeName) ?></td>
                <td class="c"><?= htmlspecialchars($ofo_code) ?></td>
                <td class="c"><span class="prefilled">NQF-Q-2019-ARPL</span></td>
                <td class="c">NQF 4</td>
            </tr>
        </table>

        <p style="font-size:13pt;font-weight:bold;margin:12px 0 5px;">Eligibility Requirements for External Integrated Summative Assessment (Trade Test)</p>

        <p style="font-size:12pt;font-weight:bold;margin:8px 0 4px;">Knowledge Modules</p>
        <table class="ft">
            <tr>
                <th style="width:90px;">Number</th>
                <th class="l">Title</th>
                <th class="l">Evidence<br>(e.g. test or portfolio of evidence)<br>Test to be included in PoE</th>
                <th class="l">Reference</th>
                <th style="width:80px;">Achieved<br>Yes/No</th>
                <th style="width:100px;">Assessment Date</th>
            </tr>
            <?php for ($i = 1; $i <= 10; $i++): ?>
            <tr>
                <td><input type="text" name="km_num_<?=$i?>" placeholder="e.g. 1" style="width:100%;"></td>
                <td><input type="text" name="km_title_<?=$i?>" placeholder="Module title" style="width:100%;"></td>
                <td><input type="text" name="km_evidence_<?=$i?>" placeholder="Evidence type" style="width:100%;"></td>
                <td><input type="text" name="km_reference_<?=$i?>" placeholder="Ref no" style="width:100%;"></td>
                <td>
                    <select name="km_achieved_<?=$i?>" style="width:100%;">
                        <option value="">--</option>
                        <option value="Yes">Yes</option>
                        <option value="No">No</option>
                    </select>
                </td>
                <td><input type="date" name="km_date_<?=$i?>" style="width:100%;"></td>
            </tr>
            <?php endfor; ?>
        </table>

        <p style="font-size:12pt;font-weight:bold;margin:10px 0 4px;">Practical Skill Modules</p>
        <table class="ft">
            <tr>
                <th style="width:90px;">Number</th>
                <th class="l">Title</th>
                <th class="l">Evidence</th>
                <th class="l">Reference</th>
                <th style="width:80px;">Achieved<br>Yes/No</th>
                <th style="width:100px;">Assessment Date</th>
            </tr>
            <?php for ($i = 1; $i <= 10; $i++): ?>
            <tr>
                <td><input type="text" name="psm_num_<?=$i?>" placeholder="e.g. 1" style="width:100%;"></td>
                <td><input type="text" name="psm_title_<?=$i?>" placeholder="Module title" style="width:100%;"></td>
                <td><input type="text" name="psm_evidence_<?=$i?>" placeholder="Evidence type" style="width:100%;"></td>
                <td><input type="text" name="psm_reference_<?=$i?>" placeholder="Ref no" style="width:100%;"></td>
                <td>
                    <select name="psm_achieved_<?=$i?>" style="width:100%;">
                        <option value="">--</option>
                        <option value="Yes">Yes</option>
                        <option value="No">No</option>
                    </select>
                </td>
                <td><input type="date" name="psm_date_<?=$i?>" style="width:100%;"></td>
            </tr>
            <?php endfor; ?>
        </table>

        <p style="font-size:12pt;font-weight:bold;margin:10px 0 4px;">Work Place Experience (interview)</p>
        <table class="ft">
            <tr>
                <th style="width:90px;">Number</th>
                <th class="l">Title</th>
                <th class="l">Evidence</th>
                <th class="l">Reference</th>
                <th style="width:80px;">Achieved<br>Yes/No</th>
                <th style="width:100px;">Assessment Date</th>
            </tr>
            <?php for ($i = 1; $i <= 10; $i++): ?>
            <tr>
                <td><input type="text" name="wpe_num_<?=$i?>" placeholder="e.g. 1" style="width:100%;"></td>
                <td><input type="text" name="wpe_title_<?=$i?>" placeholder="Activity title" style="width:100%;"></td>
                <td><input type="text" name="wpe_evidence_<?=$i?>" placeholder="Evidence type" style="width:100%;"></td>
                <td><input type="text" name="wpe_reference_<?=$i?>" placeholder="Ref no" style="width:100%;"></td>
                <td>
                    <select name="wpe_achieved_<?=$i?>" style="width:100%;">
                        <option value="">--</option>
                        <option value="Yes">Yes</option>
                        <option value="No">No</option>
                    </select>
                </td>
                <td><input type="date" name="wpe_date_<?=$i?>" style="width:100%;"></td>
            </tr>
            <?php endfor; ?>
        </table>

        <!-- Candidate Signature Section -->
        <table class="sig-table" style="margin-top:20px;">
            <tr>
                <td style="width:40%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Candidate Signature:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Date:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>

        <div style="margin-top:12px;">
            <div style="display:flex;gap:20px;">
                <div style="flex:1;">
                    <label style="font-weight:bold;">SDP/AC Assessor – Name:</label>
                    <div style="border-bottom:1px solid #000;padding:4px;height:20px;"><?= htmlspecialchars(($facilitator['firstName'] ?? '') . ' ' . ($facilitator['lastName'] ?? '')) ?></div>
                </div>
                <div style="flex:1;">
                    <label style="font-weight:bold;">Position:</label>
                    <div style="border-bottom:1px solid #000;padding:4px;height:20px;"></div>
                </div>
            </div>
        </div>

        <!-- Assessor Signature Section -->
        <table class="sig-table" style="margin-top:12px;">
            <tr>
                <td style="width:40%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Assessor Signature:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Date:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>

        <div style="margin-top:12px;">
            <div style="display:flex;gap:20px;">
                <div style="flex:1;">
                    <label style="font-weight:bold;">SDP/AC Manager – Name:</label>
                    <div style="border-bottom:1px solid #000;padding:4px;height:20px;"></div>
                </div>
                <div style="flex:1;">
                    <label style="font-weight:bold;">Position:</label>
                    <div style="border-bottom:1px solid #000;padding:4px;height:20px;"></div>
                </div>
            </div>
        </div>

        <!-- Manager Signature Section -->
        <table class="sig-table" style="margin-top:12px;">
            <tr>
                <td style="width:40%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Manager Signature:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Date:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>

        <div style="margin-top:12px;">
            <div style="display:flex;gap:20px;">
                <div style="flex:1;">
                    <label style="font-weight:bold;">NAMB Verifier – Name:</label>
                    <div style="border-bottom:1px solid #000;padding:4px;height:20px;"></div>
                </div>
                <div style="flex:1;">
                    <label style="font-weight:bold;">Position:</label>
                    <div style="border-bottom:1px solid #000;padding:4px;height:20px;"></div>
                </div>
            </div>
        </div>

        <!-- Verifier Signature Section -->
        <table class="sig-table" style="margin-top:12px;">
            <tr>
                <td style="width:40%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Verifier Signature:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;padding:10px;vertical-align:top;">
                    <label style="font-weight:bold;">Date:</label>
                    <div style="height:60px;border-bottom:1px solid #000;margin-top:8px;"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>

        <div style="margin-top:12px;">
            <label style="font-size:13pt;font-weight:bold;">Trade Test Serial Number:</label>
            <div style="border-bottom:1px solid #000;margin-top:4px;">
                <input type="text" placeholder="e.g. TT-<?= date('Y') ?>-PL-<?= str_pad($learnerID,5,'0',STR_PAD_LEFT) ?>" style="font-size:13pt;border:none;width:100%;padding:3px 4px;">
            </div>
        </div>
    </div>

    <!-- PAGE 14: APPENDIX M - CANDIDATE PRE-ASSESSMENT AGREEMENT -->
    <div class="page">
        <table class="dht">
            <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
            <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= htmlspecialchars($ofo_code) ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
            <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>30 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
        </table>

        <div class="sec-title">14. Appendix M: Candidate Pre-Assessment Agreement
            <span style="font-size:12pt;font-weight:normal;">(<?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?>)</span>
        </div>

        <table class="ft">
            <tr><td style="width:42%;"><b>Full Name of the Candidate</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['FirstName'] . ' ' . $learner['LastName']) ?></span></td></tr>
            <tr><td><b>Candidates ID Number</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['LearnerID'] ?? '') ?></span></td></tr>
            <tr><td><b>Trade</b></td><td><?= htmlspecialchars($tradeName) ?></td></tr>
            <tr><td><b>Date of Agreement</b></td><td><input type="date" value="<?= date('Y-m-d') ?>"></td></tr>
        </table>

        <p style="font-size:13pt;font-weight:bold;margin:12px 0 6px;">Type of Assessment:</p>
        <table class="ft">
            <tr>
                <td>Theory Test &nbsp;<input type="checkbox" name="ta_th_<?=$learnerID?>"></td>
                <td>Practical Assessment &nbsp;<input type="checkbox" name="ta_pr_<?=$learnerID?>"></td>
                <td>Workplace Experience Evaluation &nbsp;<input type="checkbox" name="ta_wp_<?=$learnerID?>"></td>
            </tr>
        </table>

        <div class="note" style="margin:12px 0;">
            <b>NOTE:</b> I hereby agree to be assessed and I commit to abide by the rules and regulations of the Assessment.
            I also agree to the Trade Test Centre's confidentiality agreement with regards to the Assessment materials (documentation).
        </div>

        <table class="sig-table">
            <tr>
                <td style="width:40%;">
                    <label>Signature of Candidate:</label>
                    <div class="sig-pad-wrapper">
                        <canvas class="sig-pad-canvas" data-sig-id="candidate-sig6-<?= $learnerID ?>" width="300" height="80"></canvas>
                        <div class="sig-pad-buttons">
                            <button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig6-<?= $learnerID ?>')">Clear</button>
                        </div>
                        <input type="hidden" name="candidate-sig6-<?= $learnerID ?>" id="candidate-sig6-<?= $learnerID ?>-data">
                    </div>
                </td>
                <td style="width:30%;">
                    <label>Date:</label>
                    <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>
        <table class="sig-table">
            <tr>
                <td style="width:40%;">
                    <label>Signature of Assessor:</label>
                    <div class="sig-pad-wrapper">
                        <canvas class="sig-pad-canvas" data-sig-id="assessor-sig5-<?= $learnerID ?>" width="300" height="80"></canvas>
                        <div class="sig-pad-buttons">
                            <button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig5-<?= $learnerID ?>')">Clear</button>
                        </div>
                        <input type="hidden" name="assessor-sig5-<?= $learnerID ?>" id="assessor-sig5-<?= $learnerID ?>-data">
                    </div>
                </td>
                <td style="width:30%;">
                    <label>Date:</label>
                    <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
                </td>
                <td style="width:30%;"></td>
            </tr>
        </table>
    </div>

    <!-- PAGE 14: LEARNER DOCUMENTS & POE -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Supporting Documents</td></tr>
        </table>

        <div class="appendix-title">Learner Documents & Proof of Evidence (POE)</div>
        
        <p style="font-size:12pt;margin:5px 0;">Total supporting documents attached: <?php echo count($learnerDocuments); ?></p>

        <?php if (!empty($learnerDocuments)): ?>
        <table class="ft" style="font-size:11px;">
            <tr><th style="width:50%;">Document Name</th><th style="width:20%;">Type</th><th style="width:15%;">Upload Date</th><th style="width:15%;">Status</th></tr>
            <?php $count = 0; foreach ($learnerDocuments as $doc): if ($count++ >= 10) break; ?>
            <tr>
                <td><small><?php echo htmlspecialchars(substr($doc['document_name'] ?? $doc['file_name'] ?? 'Document', 0, 60)); ?></small></td>
                <td><small><?php echo htmlspecialchars($doc['document_type'] ?? $doc['file_type'] ?? 'File'); ?></small></td>
                <td><small><?php echo isset($doc['upload_date']) ? date('d M Y', strtotime($doc['upload_date'])) : 'N/A'; ?></small></td>
                <td><small><?php echo htmlspecialchars($doc['status'] ?? 'Uploaded'); ?></small></td>
            </tr>
            <?php endforeach; ?>
        </table>
        <?php else: ?>
        <p><em>No learner documents currently uploaded</em></p>
        <?php endif; ?>

        <p style="font-size:12pt;font-weight:bold;margin:15px 0;">Proof of Evidence (POE) Records:</p>
        <?php if (!empty($poeData)): ?>
        <table class="ft" style="font-size:11px;">
            <tr><th style="width:30%;">POE Type</th><th style="width:50%;">Description</th><th style="width:20%;">Date</th></tr>
            <?php foreach ($poeData as $poe): ?>
            <tr>
                <td><?php echo htmlspecialchars($poe['poe_type'] ?? 'Evidence'); ?></td>
                <td><small><?php echo htmlspecialchars(substr($poe['poe_description'] ?? '', 0, 80)); ?></small></td>
                <td><?php echo isset($poe['uploaded_date']) ? date('d M Y', strtotime($poe['uploaded_date'])) : 'N/A'; ?></td>
            </tr>
            <?php endforeach; ?>
        </table>
        <?php else: ?>
        <p><em>No POE records available</em></p>
        <?php endif; ?>
    </div>

    <!-- PAGE 15: APPENDIX N - PRE-ASSESSMENT CHECKLIST -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Appendix N</td></tr>
        </table>

        <div class="appendix-title">Appendix N: Pre-Assessment Agreement & Checklist</div>
        
        <p style="font-size:12pt;font-weight:bold;">Learner Pre-Assessment Checklist</p>
        <table class="ft" style="font-size:12px;">
            <tr><th style="width:5%;text-align:center;">✓</th><th>Pre-Assessment Requirement</th><th style="width:20%;text-align:center;">Verified</th></tr>
            <tr><td style="text-align:center;">☐</td><td>ID/Passport verified and copied</td><td style="text-align:center;">____</td></tr>
            <tr><td style="text-align:center;">☐</td><td>Employment history documented</td><td style="text-align:center;">____</td></tr>
            <tr><td style="text-align:center;">☐</td><td>Relevant qualifications provided</td><td style="text-align:center;">____</td></tr>
            <tr><td style="text-align:center;">☐</td><td>References confirmed</td><td style="text-align:center;">____</td></tr>
            <tr><td style="text-align:center;">☐</td><td>POE documentation collected</td><td style="text-align:center;">____</td></tr>
            <tr><td style="text-align:center;">☐</td><td>Assessment rules explained</td><td style="text-align:center;">____</td></tr>
            <tr><td style="text-align:center;">☐</td><td>Health & safety briefing completed</td><td style="text-align:center;">____</td></tr>
            <tr><td style="text-align:center;">☐</td><td>Learner agreement signed</td><td style="text-align:center;">____</td></tr>
        </table>

        <p style="font-size:12pt;font-weight:bold;margin:15px 0;">Assessment Readiness Confirmation</p>
        <table class="ft">
            <tr><td style="width:50%;"><b>All pre-assessment requirements completed</b></td><td><span style="font-size:12px;font-weight:bold;">☐ YES    ☐ NO</span></td></tr>
            <tr><td><b>Learner is ready for assessment</b></td><td><span style="font-size:12px;font-weight:bold;">☐ YES    ☐ NO</span></td></tr>
        </table>

        <p style="font-size:11pt;margin:20px 0;font-style:italic;">
            <b>Note:</b> This portfolio contains all required supporting documents and assessment evidence. 
            It is ready for submission to the relevant assessment authority for quality assurance review.
        </p>

        <table class="ft" style="margin-top:15px;">
            <tr><td style="width:50%;"><b>Coordinator Name</b></td><td>_______________________________</td></tr>
            <tr><td><b>Signature</b></td><td>_________________________ Date: _________</td></tr>
            <tr><td><b>Assessment Provider</b></td><td><?php echo htmlspecialchars($ctx['provider_name'] ?? 'RLMSS'); ?></td></tr>
        </table>
    </div>

    <!-- PAGE 15: THEORY ASSESSMENT PAPERS -->
    <?php if (!empty($theoryPapers)): ?>
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Theory Assessment Papers</td></tr>
        </table>

        <div class="appendix-title">Appendix L: Theory Assessment Papers</div>
        
        <p style="font-size:12pt;margin:10px 0;"><strong>Total Theory Papers Uploaded:</strong> <?php echo count($theoryPapers); ?></p>

        <!-- THEORY PAPERS - QUESTIONS THEN SCRIPT FOR EACH PAPER -->
        <?php 
        $paperIndex = 0;
        foreach ($theoryPapers as $paper): 
            $paperIndex++;
            $filePath = $paper['combined_pdf_path'] ?? '';
            $paperTitle = $paper['paper_title'] ?? '';
            
            // Use helper function to resolve file path
            $actualFile = resolveDocumentPath($filePath);
            
            // Check if file exists and is within size limit
            $fileExists = $actualFile && file_exists($actualFile) && filesize($actualFile) < 10485760;
            
            // Load questions for this paper from database
            // JOIN through paper_title since arpl_poe doesn't have paper_id
            $questionsForPaper = [];
            if (!empty($paperTitle)) {
                $st = $conn->prepare("
                    SELECT aq.question_number, aq.question_text, aq.marks, aq.question_type, aq.difficulty_level 
                    FROM arpl_questions aq
                    INNER JOIN arpl_papers ap ON aq.paper_id = ap.id
                    WHERE ap.paper_title = ? 
                    AND ap.trade_ofo_code = ?
                    ORDER BY aq.question_number ASC
                ");
                if ($st) {
                    $st->bind_param("ss", $paperTitle, $ofo_code);
                    $st->execute();
                    $result = $st->get_result();
                    while ($row = $result->fetch_assoc()) {
                        $questionsForPaper[] = $row;
                    }
                    $st->close();
                }
            }
        ?>
        
        <!-- PAPER SECTION - EACH PAPER ON ITS OWN VISUAL BLOCK -->
        <div style="margin:25px 0;padding:20px;border:2px solid #0066cc;border-radius:6px;background:#f0f7ff;page-break-inside:avoid;">
            
            <!-- PAPER HEADER -->
            <div style="font-size:14px;font-weight:bold;margin-bottom:15px;color:#0066cc;border-bottom:2px solid #0066cc;padding-bottom:10px;">
                Paper <?php echo $paperIndex; ?>: <?php echo htmlspecialchars($paper['paper_title']); ?>
            </div>
            
            <!-- PAPER METADATA -->
            <div style="font-size:10px;color:#666;margin-bottom:15px;padding:10px;background:#fff;border-radius:3px;">
                <strong>Paper Number:</strong> <?php echo htmlspecialchars($paper['paper_number']); ?> | 
                <strong>Questions:</strong> <?php echo htmlspecialchars($paper['question_count'] ?? count($questionsForPaper)); ?> | 
                <strong>Upload Date:</strong> <?php echo isset($paper['created_at']) ? date('d M Y', strtotime($paper['created_at'])) : 'N/A'; ?>
            </div>
            
            <!-- QUESTIONS SECTION HEADER -->
            <div style="font-size:12px;font-weight:bold;margin-bottom:10px;color:#333;background:#e8f0ff;padding:8px 10px;border-radius:3px;">
                ▸ Questions (<?php echo count($questionsForPaper); ?> questions)
            </div>
            
            <!-- QUESTIONS FROM DATABASE -->
            <div style="margin:10px 0;background:#f9f9f9;padding:15px;border:1px solid #ccc;border-radius:3px;font-size:11px;">
                <?php if (!empty($questionsForPaper)): ?>
                    <!-- ACTUAL QUESTIONS FROM DATABASE -->
                    <?php foreach ($questionsForPaper as $q): ?>
                    <div style="margin-bottom:15px;padding-bottom:15px;border-bottom:1px solid #e0e0e0;">
                        <div style="font-weight:bold;color:#0066cc;margin-bottom:5px;">
                            Q<?php echo htmlspecialchars($q['question_number']); ?>: <?php echo htmlspecialchars(substr($q['question_text'], 0, 120)); ?><?php echo strlen($q['question_text']) > 120 ? '...' : ''; ?>
                        </div>
                        <div style="margin-left:15px;color:#666;font-size:10px;">
                            <strong>Type:</strong> <?php echo htmlspecialchars($q['question_type']); ?> | 
                            <strong>Marks:</strong> <?php echo htmlspecialchars($q['marks']); ?> | 
                            <strong>Level:</strong> <?php echo htmlspecialchars($q['difficulty_level']); ?>
                        </div>
                        <div style="margin-left:15px;margin-top:5px;color:#333;line-height:1.5;">
                            <?php echo htmlspecialchars($q['question_text']); ?>
                        </div>
                    </div>
                    <?php endforeach; ?>
                    <small style="color:#999;display:block;margin-top:10px;padding-top:10px;border-top:1px solid #e0e0e0;">
                        [All assessment questions displayed above - see script PDF below for reference]
                    </small>
                <?php else: ?>
                    <div style="padding:15px;background:#fff3cd;border:1px solid #ffc107;border-radius:3px;">
                        <strong style="color:#856404;">Questions Not Available in Database</strong><br>
                        <small style="color:#856404;">No questions found for this paper. Questions may not have been imported yet. View the uploaded script PDF below for question content.</small>
                    </div>
                <?php endif; ?>
            </div>
            
            <!-- SCRIPT/PDF SECTION HEADER -->
            <div style="font-size:12px;font-weight:bold;margin:20px 0 10px 0;color:#333;background:#e8f0ff;padding:8px 10px;border-radius:3px;">
                ▸ Uploaded Script
            </div>
            
            <!-- PDF EMBED OR ERROR MESSAGE -->
            <?php if ($fileExists): 
                $fileData = file_get_contents($actualFile);
                $base64Data = base64_encode($fileData);
                $fileSize = filesize($actualFile);
            ?>
            <div style="margin:10px 0;background:#f9f9f9;padding:15px;border:1px solid #ccc;border-radius:3px;">
                <embed src="data:application/pdf;base64,<?php echo $base64Data; ?>" 
                       type="application/pdf" 
                       style="width:100%;height:600px;border:1px solid #ddd;border-radius:3px;" />
                <div style="font-size:10px;color:#999;margin-top:8px;text-align:right;">
                    File size: <?php echo round($fileSize / 1024, 2); ?> KB
                </div>
            </div>
            <?php else: ?>
            <div style="margin:10px 0;padding:15px;background:#fff3cd;border:2px solid #ffc107;border-radius:3px;font-size:11px;">
                <strong style="color:#856404;">⚠ Script Not Available</strong><br>
                <small style="color:#856404;">Paper <?php echo htmlspecialchars($paper['paper_number']); ?> - <?php echo htmlspecialchars($paper['paper_title']); ?> file is not available for viewing or is too large to embed.</small>
            </div>
            <?php endif; ?>
            
        </div>
        
        <?php endforeach; ?>
    </div>
    <?php endif; ?>

    <!-- PAGE 16: THEORY ASSESSMENT REGISTER -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Theory Assessment Register</td></tr>
        </table>

        <div class="appendix-title">Appendix M: Theory Assessment Register (Sitting)</div>
        
        <div style="margin:15px 0;padding:15px;background:#f9f9f9;border:1px solid #ddd;border-radius:4px;">
            <p style="font-size:12pt;margin:0 0 10px 0;"><strong>Status:</strong></p>
            
            <?php if (false): // Placeholder for when register is uploaded ?>
                <p style="font-size:11pt;color:#28a745;">
                    <strong>✓ Uploaded</strong><br>
                    Theory assessment register submitted on [Date]
                </p>
            <?php else: ?>
                <p style="font-size:11pt;color:#dc3545;">
                    <strong>✗ Not Uploaded</strong><br>
                    Theory assessment register (attendance, invigilator details, etc.) has not yet been submitted.
                </p>
                
                <div style="margin-top:15px;padding:12px;background:#fff3cd;border:1px solid #ffc107;border-radius:3px;">
                    <strong>Required Information:</strong>
                    <ul style="margin:5px 0;padding-left:20px;font-size:10pt;">
                        <li>Invigilator Name & Signature</li>
                        <li>Assessment Venue Details</li>
                        <li>Date and Time of Assessment</li>
                        <li>Attendance Register / Candidate List</li>
                        <li>Assessment Provider Sign-Off</li>
                    </ul>
                </div>
            <?php endif; ?>
        </div>

        <!-- FORM FIELDS FOR THEORY REGISTER (if needed later) -->
        <table class="ft" style="margin-top:20px;">
            <tr><th colspan="2" style="background:#f0f0f0;padding:8px;">Theory Assessment Sitting Details</th></tr>
            <tr><td style="width:40%;"><b>Assessment Date:</b></td><td><input type="text" style="width:100%;border:none;border-bottom:1px solid #000;" placeholder="Not recorded"></td></tr>
            <tr><td><b>Invigilator Name:</b></td><td><input type="text" style="width:100%;border:none;border-bottom:1px solid #000;" placeholder="Not recorded"></td></tr>
            <tr><td><b>Venue:</b></td><td><input type="text" style="width:100%;border:none;border-bottom:1px solid #000;" placeholder="Not recorded"></td></tr>
            <tr><td><b>Attendance Status:</b></td><td><input type="text" style="width:100%;border:none;border-bottom:1px solid #000;" placeholder="Pending"></td></tr>
        </table>
    </div>

    <!-- PAGE 17: PRACTICAL ASSESSMENT SCRIPTS -->
    <?php if (!empty($practicalScripts)): ?>
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Practical Assessment Scripts</td></tr>
        </table>

        <div class="appendix-title">Appendix N: Practical Assessment Scripts</div>
        
        <p style="font-size:12pt;margin:10px 0;"><strong>Total Practical Scripts Uploaded:</strong> <?php echo count($practicalScripts); ?></p>

        <!-- PRACTICAL SCRIPTS - QUESTIONS THEN SCRIPT FOR EACH SCRIPT -->
        <?php 
        $scriptIndex = 0;
        foreach ($practicalScripts as $script): 
            $scriptIndex++;
            $filePath = $script['combined_pdf_path'] ?? '';
            $paperTitle = $script['paper_title'] ?? '';
            
            // Use helper function to resolve file path
            $actualFile = resolveDocumentPath($filePath);
            
            // Check if file exists and is within size limit
            $fileExists = $actualFile && file_exists($actualFile) && filesize($actualFile) < 10485760;
            
            // Load questions for this practical paper from database
            // JOIN through paper_title since arpl_poe doesn't have paper_id
            $questionsForPaper = [];
            if (!empty($paperTitle)) {
                $st = $conn->prepare("
                    SELECT aq.question_number, aq.question_text, aq.marks, aq.question_type, aq.difficulty_level 
                    FROM arpl_questions aq
                    INNER JOIN arpl_papers ap ON aq.paper_id = ap.id
                    WHERE ap.paper_title = ? 
                    AND ap.trade_ofo_code = ?
                    ORDER BY aq.question_number ASC
                ");
                if ($st) {
                    $st->bind_param("ss", $paperTitle, $ofo_code);
                    $st->execute();
                    $result = $st->get_result();
                    while ($row = $result->fetch_assoc()) {
                        $questionsForPaper[] = $row;
                    }
                    $st->close();
                }
            }
        ?>
        
        <!-- SCRIPT SECTION - EACH SCRIPT ON ITS OWN VISUAL BLOCK -->
        <div style="margin:25px 0;padding:20px;border:2px solid #cc6600;border-radius:6px;background:#fff8f0;page-break-inside:avoid;">
            
            <!-- SCRIPT HEADER -->
            <div style="font-size:14px;font-weight:bold;margin-bottom:15px;color:#cc6600;border-bottom:2px solid #cc6600;padding-bottom:10px;">
                Script <?php echo $scriptIndex; ?>: <?php echo htmlspecialchars($script['paper_title']); ?>
            </div>
            
            <!-- SCRIPT METADATA -->
            <div style="font-size:10px;color:#666;margin-bottom:15px;padding:10px;background:#fff;border-radius:3px;">
                <strong>Script Number:</strong> <?php echo htmlspecialchars($script['paper_number']); ?> | 
                <strong>Questions:</strong> <?php echo htmlspecialchars($script['question_count'] ?? count($questionsForPaper)); ?> | 
                <strong>Upload Date:</strong> <?php echo isset($script['created_at']) ? date('d M Y', strtotime($script['created_at'])) : 'N/A'; ?>
            </div>
            
            <!-- QUESTIONS SECTION HEADER -->
            <div style="font-size:12px;font-weight:bold;margin-bottom:10px;color:#333;background:#ffe8cc;padding:8px 10px;border-radius:3px;">
                ▸ Questions (<?php echo count($questionsForPaper); ?> questions)
            </div>
            
            <!-- QUESTIONS FROM DATABASE -->
            <div style="margin:10px 0;background:#f9f9f9;padding:15px;border:1px solid #ccc;border-radius:3px;font-size:11px;">
                <?php if (!empty($questionsForPaper)): ?>
                    <!-- ACTUAL QUESTIONS FROM DATABASE -->
                    <?php foreach ($questionsForPaper as $q): ?>
                    <div style="margin-bottom:15px;padding-bottom:15px;border-bottom:1px solid #e0e0e0;">
                        <div style="font-weight:bold;color:#cc6600;margin-bottom:5px;">
                            Q<?php echo htmlspecialchars($q['question_number']); ?>: <?php echo htmlspecialchars(substr($q['question_text'], 0, 120)); ?><?php echo strlen($q['question_text']) > 120 ? '...' : ''; ?>
                        </div>
                        <div style="margin-left:15px;color:#666;font-size:10px;">
                            <strong>Type:</strong> <?php echo htmlspecialchars($q['question_type']); ?> | 
                            <strong>Marks:</strong> <?php echo htmlspecialchars($q['marks']); ?> | 
                            <strong>Level:</strong> <?php echo htmlspecialchars($q['difficulty_level']); ?>
                        </div>
                        <div style="margin-left:15px;margin-top:5px;color:#333;line-height:1.5;">
                            <?php echo htmlspecialchars($q['question_text']); ?>
                        </div>
                    </div>
                    <?php endforeach; ?>
                    <small style="color:#999;display:block;margin-top:10px;padding-top:10px;border-top:1px solid #e0e0e0;">
                        [All assessment questions displayed above - see script PDF below for reference]
                    </small>
                <?php else: ?>
                    <div style="padding:15px;background:#fff3cd;border:1px solid #ffc107;border-radius:3px;">
                        <strong style="color:#856404;">Questions Not Available in Database</strong><br>
                        <small style="color:#856404;">No questions found for this script. Questions may not have been imported yet. View the uploaded script PDF below for question content.</small>
                    </div>
                <?php endif; ?>
            </div>
            
            <!-- SCRIPT/PDF SECTION HEADER -->
            <div style="font-size:12px;font-weight:bold;margin:20px 0 10px 0;color:#333;background:#ffe8cc;padding:8px 10px;border-radius:3px;">
                ▸ Uploaded Practical Script
            </div>
            
            <!-- PDF EMBED OR ERROR MESSAGE -->
            <?php if ($fileExists): 
                $fileData = file_get_contents($actualFile);
                $base64Data = base64_encode($fileData);
                $fileSize = filesize($actualFile);
            ?>
            <div style="margin:10px 0;background:#f9f9f9;padding:15px;border:1px solid #ccc;border-radius:3px;">
                <embed src="data:application/pdf;base64,<?php echo $base64Data; ?>" 
                       type="application/pdf" 
                       style="width:100%;height:600px;border:1px solid #ddd;border-radius:3px;" />
                <div style="font-size:10px;color:#999;margin-top:8px;text-align:right;">
                    File size: <?php echo round($fileSize / 1024, 2); ?> KB
                </div>
            </div>
            <?php else: ?>
            <div style="margin:10px 0;padding:15px;background:#fff3cd;border:2px solid #ffc107;border-radius:3px;font-size:11px;">
                <strong style="color:#856404;">⚠ Script Not Available</strong><br>
                <small style="color:#856404;">Script <?php echo htmlspecialchars($script['paper_number']); ?> - <?php echo htmlspecialchars($script['paper_title']); ?> file is not available for viewing or is too large to embed.</small>
            </div>
            <?php endif; ?>
            
        </div>
        
        <?php endforeach; ?>
    </div>
    <?php endif; ?>

    <!-- PAGE 18: PRACTICAL ATTENDANCE REGISTER -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Practical Attendance Register</td></tr>
        </table>

        <div class="appendix-title">Appendix O: Practical Attendance Register</div>
        
        <div style="margin:15px 0;padding:15px;background:#f9f9f9;border:1px solid #ddd;border-radius:4px;">
            <p style="font-size:12pt;margin:0 0 10px 0;"><strong>Status:</strong></p>
            
            <?php if (false): // Placeholder for when register is uploaded ?>
                <p style="font-size:11pt;color:#28a745;">
                    <strong>✓ Uploaded</strong><br>
                    Practical attendance register submitted on [Date]
                </p>
            <?php else: ?>
                <p style="font-size:11pt;color:#dc3545;">
                    <strong>✗ Not Uploaded</strong><br>
                    Practical assessment attendance register has not yet been submitted.
                </p>
                
                <div style="margin-top:15px;padding:12px;background:#fff3cd;border:1px solid #ffc107;border-radius:3px;">
                    <strong>Required Information:</strong>
                    <ul style="margin:5px 0;padding-left:20px;font-size:10pt;">
                        <li>Practical Assessment Dates</li>
                        <li>Venue / Workshop Location</li>
                        <li>Assessor Name & Signature</li>
                        <li>Candidate Attendance Records</li>
                        <li>Equipment / Materials Used</li>
                        <li>Health & Safety Compliance Sign-Off</li>
                    </ul>
                </div>
            <?php endif; ?>
        </div>

        <!-- FORM FIELDS FOR PRACTICAL ATTENDANCE REGISTER (if needed later) -->
        <table class="ft" style="margin-top:20px;">
            <tr><th colspan="2" style="background:#f0f0f0;padding:8px;">Practical Assessment Details</th></tr>
            <tr><td style="width:40%;"><b>Assessment Dates:</b></td><td><input type="text" style="width:100%;border:none;border-bottom:1px solid #000;" placeholder="Not recorded"></td></tr>
            <tr><td><b>Workshop Location:</b></td><td><input type="text" style="width:100%;border:none;border-bottom:1px solid #000;" placeholder="Not recorded"></td></tr>
            <tr><td><b>Assessor Name:</b></td><td><input type="text" style="width:100%;border:none;border-bottom:1px solid #000;" placeholder="Not recorded"></td></tr>
            <tr><td><b>Attendance Status:</b></td><td><input type="text" style="width:100%;border:none;border-bottom:1px solid #000;" placeholder="Pending"></td></tr>
        </table>
    </div>

    <!-- PAGE 19: WORKPLACE EXPERIENCE REGISTER -->
    <div class="page">
        <table class="dht">
            <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Workplace Experience Register</td></tr>
        </table>

        <div class="appendix-title">Appendix P: Workplace Experience Register</div>
        
        <div style="margin:15px 0;padding:15px;background:#f9f9f9;border:1px solid #ddd;border-radius:4px;">
            <p style="font-size:12pt;margin:0 0 10px 0;"><strong>Status:</strong></p>
            
            <?php if (!empty($arplWorkExperience)): ?>
                <p style="font-size:11pt;color:#28a745;">
                    <strong>✓ Work Experience Recorded</strong><br>
                    <?php echo count($arplWorkExperience); ?> employment record(s) on file
                </p>
                
                <!-- WORK EXPERIENCE RECORDS -->
                <table class="ft" style="font-size:11px;margin:15px 0;">
                    <tr>
                        <th style="width:30%;">Employer</th>
                        <th style="width:20%;text-align:center;">Start Date</th>
                        <th style="width:20%;text-align:center;">End Date</th>
                        <th style="width:30%;">Position / Role</th>
                    </tr>
                    <?php foreach ($arplWorkExperience as $exp): ?>
                    <tr>
                        <td><?php echo htmlspecialchars($exp['employer_name'] ?? 'N/A'); ?></td>
                        <td style="text-align:center;"><?php echo isset($exp['start_date']) ? date('M Y', strtotime($exp['start_date'])) : 'N/A'; ?></td>
                        <td style="text-align:center;"><?php echo isset($exp['end_date']) ? date('M Y', strtotime($exp['end_date'])) : 'Current'; ?></td>
                        <td><?php echo htmlspecialchars($exp['position'] ?? $exp['job_title'] ?? 'N/A'); ?></td>
                    </tr>
                    <?php endforeach; ?>
                </table>
            <?php else: ?>
                <p style="font-size:11pt;color:#dc3545;">
                    <strong>✗ No Work Experience Recorded</strong><br>
                    Workplace experience records are pending submission.
                </p>
                
                <div style="margin-top:15px;padding:12px;background:#fff3cd;border:1px solid #ffc107;border-radius:3px;">
                    <strong>To Complete This Section, Provide:</strong>
                    <ul style="margin:5px 0;padding-left:20px;font-size:10pt;">
                        <li>Employment History (dates, employers, positions)</li>
                        <li>Workplace Supervisory References</li>
                        <li>Evidence of Relevant Trade Experience</li>
                        <li>Skills Developed at Each Workplace</li>
                        <li>Employer Contact Details & Verification</li>
                    </ul>
                </div>
            <?php endif; ?>
        </div>

        <!-- ADDITIONAL NOTES -->
        <div style="margin-top:20px;padding:12px;background:#e7f3ff;border:1px solid #0066cc;border-radius:3px;font-size:11px;">
            <strong>Note on Assessment Evidence:</strong><br>
            <ul style="margin:5px 0;padding-left:20px;font-size:10pt;">
                <li>This portfolio contains all assessment evidence submitted by the learner</li>
                <li>Theory papers show scanned question scripts answered by the learner</li>
                <li>Practical scripts demonstrate hands-on competency in trade activities</li>
                <li>Workplace experience validates applied skills in real-world settings</li>
                <li>All registers provide institutional verification of assessments conducted</li>
            </ul>
        </div>
    </div>

</body>
</html>
