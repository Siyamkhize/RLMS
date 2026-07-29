<?php
// ARPL PDF Generator v3 - Exact Mobile App Format Replication
// Generates professional ARPL portfolio PDF matching mobile app structure exactly
// Supports all 3 trades: Electrician (671101), Bricklaying (641201), Plumbing (642601)

ini_set('max_execution_time', 600);
ini_set('memory_limit', '1024M');
ini_set('max_input_time', 600);

session_start();
@include __DIR__ . '/../connection.php';
date_default_timezone_set('Africa/Johannesburg');

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// ══════════════════════════════════════════════════════════════════
// REQUEST VALIDATION & AUTH
// ══════════════════════════════════════════════════════════════════
$input = file_get_contents('php://input');
$data = json_decode($input, true);

if (!$data || !isset($data['learnerID']) || !isset($data['classID'])) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['status' => 'error', 'message' => 'Missing learnerID or classID']);
    exit;
}

$learnerID = (int)$data['learnerID'];
$classID = (int)$data['classID'];
$ofoNumber = $data['ofoNumber'] ?? '671101'; // Default: Electrician

// Auth check
$is_sdp = isset($_SESSION['sdp_id']);
$is_facilitator = isset($_SESSION['facilitator_id']);
if (!$is_sdp && !$is_facilitator) {
    http_response_code(403);
    header('Content-Type: application/json');
    echo json_encode(['status' => 'error', 'message' => 'Not authorized']);
    exit;
}

// ══════════════════════════════════════════════════════════════════
// TRADE CONFIGURATION
// ══════════════════════════════════════════════════════════════════
$tradeConfig = [
    '671101' => ['name' => 'Electrician',  'table_suffix' => 'electrician'],
    '641201' => ['name' => 'Bricklaying',  'table_suffix' => 'bricklaying'],
    '642601' => ['name' => 'Plumbing',     'table_suffix' => 'plumbing'],
];

if (!isset($tradeConfig[$ofoNumber])) {
    $ofoNumber = '671101';
}

$tradeName = $tradeConfig[$ofoNumber]['name'];
$tableSuffix = $tradeConfig[$ofoNumber]['table_suffix'];

// ══════════════════════════════════════════════════════════════════
// LOAD LEARNER & CLASS DATA
// ══════════════════════════════════════════════════════════════════
$sql = "SELECT LearnerID, Title, Name, Surname, IDNumber, DateOfBirth,
               PhoneNumber, Email, Gender, Race, Language,
               AddressLine1, AddressLine2, AddressLine3, PostalCode,
               SchoolName, SchoolCompletion, SchoolGrade
        FROM learnerdetails
        WHERE LearnerID = ? AND classID = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param('ii', $learnerID, $classID);
$stmt->execute();
$learner = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$learner) {
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode(['status' => 'error', 'message' => 'Learner not found']);
    exit;
}

// Get class & context data
$sql = "SELECT c.className, s.siteName, s.siteID, s.Province, s.District,
               p.Project_name, p.Contract_no, p.Financial_year,
               p.Start_date, p.End_date, sdp.sdp_name, sdp.accreditation_n,
               sdp.p_address, sdp.email FROM class c
        JOIN sites s ON c.siteID = s.siteID
        JOIN project p ON s.project_id = p.project_id
        JOIN sdp ON s.sdp_id = sdp.sdp_id
        WHERE c.classID = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param('i', $classID);
$stmt->execute();
$ctx = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$ctx) {
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode(['status' => 'error', 'message' => 'Class data not found']);
    exit;
}

// Get facilitator
$facilitator_id = (int)($_SESSION['facilitator_id'] ?? 0);
$facilitator = ['firstName' => '', 'lastName' => '', 'assessorNo' => ''];
if ($facilitator_id > 0) {
    $stmt = $conn->prepare("SELECT * FROM facilitator WHERE facilitator_id = ?");
    $stmt->bind_param('i', $facilitator_id);
    $stmt->execute();
    if ($frow = $stmt->get_result()->fetch_assoc()) {
        $facilitator = $frow;
    }
    $stmt->close();
}

// ══════════════════════════════════════════════════════════════════
// LOAD APPENDIX DATA (B, D, E, H)
// ══════════════════════════════════════════════════════════════════

// Appendix B: Self-Evaluation Activities (Competency Scale 1-5)
$appendixB = [];
$stmt = $conn->prepare("
    SELECT activity_id, activity_name, competency_scale_id, comments, rating_date
    FROM arplappxb_activity_ratings
    WHERE learnerID = ? AND ofo_number = ?
    ORDER BY activity_id
");
if ($stmt) {
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    while ($row = $stmt->get_result()->fetch_assoc()) {
        $appendixB[$row['activity_id']] = $row;
    }
    $stmt->close();
}

// Appendix D: Practical Skills (Yes/No)
$appendixD = [];
$stmt = $conn->prepare("
    SELECT * FROM arpl_appendix_d
    WHERE learnerID = ? AND ofo_number = ?
");
if ($stmt) {
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    if ($row = $stmt->get_result()->fetch_assoc()) {
        $appendixD = $row;
    }
    $stmt->close();
}

// Appendix E: Workplace Experience (Competency Scale 1-5)
$appendixE = [];
$table_e = 'arplappxe_' . $tableSuffix . '_activity_ratings';
$stmt = $conn->prepare("
    SELECT activity_id, activity_name, competency_scale_id, comments, rating_date
    FROM $table_e
    WHERE learnerID = ? AND ofo_number = ?
    ORDER BY activity_id
");
if ($stmt) {
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    while ($row = $stmt->get_result()->fetch_assoc()) {
        $appendixE[$row['activity_id']] = $row;
    }
    $stmt->close();
}

$today = date('d F Y');
$refno = 'ARPL-' . date('Y') . '-' . substr($tradeName, 0, 2) . '-' . str_pad($learnerID, 4, '0', STR_PAD_LEFT);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= htmlspecialchars($tradeName) ?> ARPL - <?= htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']) ?></title>
<style>
/* ── Reset & Base ── */
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:"Times New Roman",Times,serif;font-size:12pt;color:#000;background:#ccc;}
.page{max-width:820px;margin:16px auto;background:#fff;padding:50px 58px;box-shadow:0 3px 20px rgba(0,0,0,.25);}

/* ── Toolbar (screen only) ── */
.toolbar{display:flex;justify-content:flex-end;gap:10px;margin-bottom:20px;}
.toolbar button{padding:8px 22px;border:none;border-radius:4px;cursor:pointer;font-size:11pt;font-weight:700;background:#006341;color:#fff;}
.toolbar button:hover{opacity:.88;}
.toolbar button.sec{background:#fff;color:#006341;border:2px solid #006341;}

/* ── Cover Page ── */
.cover-page{
  position:relative;
  min-height:94vh;
  display:flex;
  flex-direction:column;
  align-items:center;
  justify-content:flex-start;
  text-align:center;
  padding:10px 0 30px;
  overflow:hidden;
  page-break-after:always;
}

/* Watermark */
.wm{
  position:absolute;
  top:50%; left:50%;
  transform:translate(-50%,-50%) rotate(-38deg);
  font-size:54pt;
  font-weight:bold;
  color:rgba(0,0,0,0.055);
  white-space:nowrap;
  pointer-events:none;
  z-index:0;
  letter-spacing:3px;
  font-family:Arial,sans-serif;
  user-select:none;
}

.cover-page > *{ position:relative; z-index:1; }

/* ── Logo block ── */
.cover-logo-row{
  display:flex;
  align-items:center;
  gap:14px;
  align-self:flex-start;
  margin-bottom:60px;
}

.dhet-coa{ width:88px; height:auto; flex-shrink:0; }

.dhet-text{
  text-align:left;
  font-family:Arial,Helvetica,sans-serif;
  line-height:1.2;
}
.dhet-text .t1{ font-size:20pt; font-weight:bold; color:#000; line-height:1.05; }
.dhet-text .t2{ font-size:20pt; font-weight:bold; color:#000; margin-bottom:5px; }
.dhet-text hr{ border:none; border-top:1.5px solid #000; margin:4px 0 5px; }
.dhet-text .t3{ font-size:9pt; color:#333; }
.dhet-text .t4{ font-size:9.5pt; color:#333; }
.dhet-text .t5{ font-size:9.5pt; font-weight:bold; color:#000; text-transform:uppercase; letter-spacing:.4px; }

/* ── Title block ── */
.cover-title-block{ width:100%; text-align:center; margin-top:10px; }
.cover-title-block .ct{ font-family:"Times New Roman",Times,serif; font-weight:bold; color:#000; display:block; }
.ct-arpl  { font-size:16pt; margin-bottom:4px; }
.ct-bracket{ font-size:16pt; margin-bottom:32px; }
.ct-toolkit{ font-size:14pt; margin-bottom:32px; }
.ct-ofo   { font-size:13pt; margin-bottom:32px; }
.ct-label { font-size:12pt; margin-bottom:2px; }
.ct-value { font-size:12pt; margin-bottom:28px; }

/* ── Document header table (dht) ── */
.dht{width:100%;border-collapse:collapse;margin-bottom:12px;font-size:10pt;}
.dht td{border:1px solid #000;padding:4px 7px;}

/* ── Titles ── */
.doc-title{text-align:center;font-size:15pt;font-weight:bold;margin:8px 0 3px;}
.doc-sub  {text-align:center;font-size:12pt;font-weight:bold;margin-bottom:5px;}
.sec-title{font-size:13pt;font-weight:bold;margin:18px 0 7px;}
.sec-sub  {font-size:12pt;font-weight:bold;margin:12px 0 5px;}

/* ── Form table (ft) ── */
table.ft{width:100%;border-collapse:collapse;margin-bottom:10px;font-size:11pt;}
table.ft th{background:#000;color:#fff;padding:5px 8px;border:1px solid #000;text-align:center;}
table.ft th.l{text-align:left;}
table.ft td{border:1px solid #000;padding:4px 7px;vertical-align:middle;}
table.ft td.c{text-align:center;}
table.ft tr:nth-child(even) td{background:#f8f8f8;}

/* ── Inputs & form elements ── */
input[type=text],input[type=email],input[type=tel],input[type=date],textarea,select{
  width:100%;border:none;border-bottom:1px solid #666;
  font-family:inherit;font-size:11pt;padding:2px 3px;
  background:transparent;color:#000;outline:none;}
textarea{resize:vertical;min-height:38px;border:1px solid #888;padding:4px;}
select{border:none;border-bottom:1px solid #666;background:transparent;}
input:focus,textarea:focus,select:focus{background:#fffde7;border-color:#006341;}
td input,td select{border:none;border-bottom:1px dashed #999;width:100%;}
td input:focus,td select:focus{background:#fffde7;}

/* ── Pre-filled fields (prefilled italic green) ── */
.prefilled{font-style:italic;color:#006341;}

/* ── Radio / Checkbox ── */
.rc{text-align:center;}
.rc input[type=radio],.rc input[type=checkbox]{width:16px;height:16px;cursor:pointer;accent-color:#006341;}

/* ── Signature row ── */
.sig-row{display:flex;gap:22px;margin-top:10px;align-items:flex-end;}
.sig-blk{flex:1;}
.sig-blk label{font-size:10pt;font-weight:bold;display:block;margin-bottom:3px;}
.sig-line{border-bottom:1px solid #000;min-height:28px;padding:2px 4px;}
.sig-line input{border:none;background:transparent;width:100%;font-size:11pt;}

/* ── Note box ── */
.note{border:1px solid #000;padding:8px 12px;margin:8px 0;font-size:11pt;font-style:italic;}

/* ── Page break ── */
.pb{page-break-before:always;margin-top:28px;padding-top:18px;border-top:1px dashed #ccc;}

/* ── Info box ── */
.info{background:#e8f5e9;border-left:4px solid #006341;padding:8px 12px;font-size:10.5pt;margin-bottom:10px;color:#1b5e20;}

@media print{
  body{background:#fff;}
  .page{box-shadow:none;padding:14px 24px;margin:0;max-width:100%;}
  .toolbar{display:none;}
  .cover-page{min-height:0;page-break-after:always;}
  .pb{page-break-before:always;}
}
</style>
</head>
<body>
<div class="page">

<!-- ════════════════════════════════════════════════
     TOOLBAR
════════════════════════════════════════════════ -->
<div class="toolbar">
  <button class="sec" onclick="window.history.back()">← Back</button>
  <button onclick="window.print()">🖨 Print / Save as PDF</button>
</div>

<!-- ════════════════════════════════════════════════
     COVER PAGE
════════════════════════════════════════════════ -->
<div class="cover-page">
  <div class="wm"><?= htmlspecialchars($ctx['sdp_name'] ?? 'Training Provider') ?></div>

  <!-- DHET Logo block -->
  <div class="cover-logo-row">
    <img class="dhet-coa" src="/logs/education.jpg" alt="DHET Logo">
    <div class="dhet-text">
      <div class="t1">Higher Education</div>
      <div class="t2">&amp; Training</div>
      <hr>
      <div class="t3">Department:</div>
      <div class="t4">Higher Education and Training</div>
      <div class="t5">REPUBLIC OF SOUTH AFRICA</div>
    </div>
  </div>

  <!-- Title block -->
  <div class="cover-title-block">
    <span class="ct ct-arpl">ARTISAN RECOGNITION OF PRIOR LEARNING</span>
    <span class="ct ct-bracket">(ARPL)</span>
    <span class="ct ct-toolkit">TOOLKIT</span>
    <span class="ct ct-ofo">OFO: <?= $ofoNumber ?></span>
    <span class="ct ct-label">Trade Title:</span>
    <span class="ct ct-value"><?= htmlspecialchars($tradeName) ?></span>
    <span class="ct ct-label">Alternative Title/Specialization:</span>
    <span class="ct ct-value">None</span>
  </div>
</div>

<!-- ════════════════════════════════════════════════
     CONTENTS PAGE
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? 'AC000153NAMB') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>2 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="doc-title"><?= strtoupper(htmlspecialchars($tradeName)) ?> ARPL TOOLKIT</div>
<div class="doc-sub">ARTISAN RECOGNITION OF PRIOR LEARNING (ARPL)</div>

<div class="sec-title">CONTENTS</div>
<table class="ft" style="margin-top:10px;">
  <tr><th class="l" style="width:70%;">INDEX</th><th>Page</th></tr>
  <tr><td>Appendix A: Application Form</td><td class="c">3</td></tr>
  <tr><td>Competency Proficiency Scale</td><td class="c">5</td></tr>
  <tr><td>Appendix B: Self-Evaluation Checklist</td><td class="c">6</td></tr>
  <tr><td>Appendix C: Trade Curriculum Content</td><td class="c">9</td></tr>
  <tr><td>Appendix D: Practical Skills Assessment</td><td class="c">12</td></tr>
  <tr><td>Appendix E: Workplace Experience Evaluation</td><td class="c">15</td></tr>
  <tr><td>Appendix F: Assessment Evaluation Agreement</td><td class="c">18</td></tr>
  <tr><td>Appendix G: Appeals Form</td><td class="c">21</td></tr>
  <tr><td>Appendix H: Access Recommendation</td><td class="c">22</td></tr>
  <tr><td>Appendix I: Statement of Results</td><td class="c">25</td></tr>
  <tr><td>Appendix J: Candidate Pre-Assessment Agreement</td><td class="c">28</td></tr>
</table>

<p style="font-size:11pt;margin-top:14px;"><b>NOTE:</b> All appendices to be included in the PoE</p>

<div class="info" style="margin-top:20px;">
  <b>Toolkit for:</b> <?= htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']) ?>
  (ID: <?= htmlspecialchars($learner['IDNumber']) ?>)
  | Class: <?= htmlspecialchars($ctx['className'] ?? '') ?>
  | Trade: <?= htmlspecialchars($tradeName) ?>
</div>
</div>

<!-- ════════════════════════════════════════════════
     APPENDIX A - APPLICATION FORM
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>3 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">1. Appendix A: Application Form</div>

<table class="ft" style="margin-bottom:8px;">
  <tr><td style="width:38%;"><b>Ref Number:</b></td>
      <td><span class="prefilled"><?= $refno ?></span></td></tr>
</table>

<div class="sec-sub">APPLICATION FOR RECOGNITION OF PRIOR LEARNING IN A LISTED TRADE</div>

<p style="font-size:11pt;font-weight:bold;margin:8px 0 6px;">Applicant Details:</p>
<table class="ft">
  <tr><td style="width:38%;"><b>Trade Title</b></td><td><?= htmlspecialchars($tradeName) ?></td></tr>
  <tr><td><b>OFO Code</b></td><td><?= $ofoNumber ?></td></tr>
  <tr><td><b>Specialization</b></td><td><input type="text" placeholder="e.g. None"></td></tr>
  <tr><td><b>Candidate Name</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']) ?></span></td></tr>
</table>

<table class="ft">
  <tr>
    <th class="l" style="width:50%;">Physical Address</th>
    <th class="l">Postal Address</th>
  </tr>
  <tr>
    <td><span class="prefilled"><?= htmlspecialchars($learner['AddressLine1'] ?? '') ?></span></td>
    <td><input type="text" placeholder="Postal address"></td>
  </tr>
  <tr>
    <td><span class="prefilled"><?= htmlspecialchars(($learner['AddressLine2'] ?? '') . ' ' . ($learner['PostalCode'] ?? '')) ?></span></td>
    <td><input type="text" placeholder="Postal code"></td>
  </tr>
</table>

<table class="ft">
  <tr><td style="width:38%;"><b>Tel no</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['PhoneNumber'] ?? '') ?></span></td></tr>
  <tr><td><b>Cell no</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['PhoneNumber'] ?? '') ?></span></td></tr>
  <tr><td><b>E-mail</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['Email'] ?? '') ?></span></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Employment Status:</p>
<table class="ft">
  <tr>
    <td style="width:38%;"><b>Currently employed</b></td>
    <td>Yes <input type="radio" name="emp">  No <input type="radio" name="emp"></td>
  </tr>
  <tr>
    <td><b>Self employed</b></td>
    <td>Yes <input type="radio" name="selfemp">  No <input type="radio" name="selfemp"></td>
  </tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Employment History</p>
<table class="ft">
  <tr>
    <th class="l">Company</th>
    <th class="l">Position/Job Title</th>
    <th class="l">Period &amp; Duration</th>
    <th class="l">Contact</th>
  </tr>
  <tr><td><input type="text" placeholder="Company"></td><td><input type="text" placeholder="Title"></td><td><input type="text" placeholder="2018–2022"></td><td><input type="tel" placeholder="Tel"></td></tr>
  <tr><td><input type="text" placeholder="Company"></td><td><input type="text" placeholder="Title"></td><td><input type="text" placeholder="2013–2017"></td><td><input type="tel" placeholder="Tel"></td></tr>
  <tr><td><input type="text" placeholder="Company"></td><td><input type="text" placeholder="Title"></td><td><input type="text" placeholder="2008–2012"></td><td><input type="tel" placeholder="Tel"></td></tr>
</table>

<div class="sig-row">
  <div class="sig-blk"><label>Candidate Signature:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Date:</label><div class="sig-line"><input type="date"></div></div>
</div>
</div>

<!-- ════════════════════════════════════════════════
     COMPETENCY SCALE (Reference Page)
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>5 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">Competency Proficiency Scale</div>
<table class="ft">
  <tr><th colspan="3">COMPETENCY PROFICIENCY SCALE FOR SELF-EVALUATION</th></tr>
  <tr><th style="width:55px;">Score</th><th>Proficiency Level</th><th class="l">Description</th></tr>
  <tr><td class="c"><b>1</b></td><td><b>Fundamental</b></td><td>Can perform under direct supervision; needs assistance in most aspects</td></tr>
  <tr><td class="c"><b>2</b></td><td><b>Novice</b></td><td>Can perform most tasks with minimal supervision; developing competency</td></tr>
  <tr><td class="c"><b>3</b></td><td><b>Intermediate</b></td><td>Can perform independently with occasional guidance; competent</td></tr>
  <tr><td class="c"><b>4</b></td><td><b>Advanced</b></td><td>Can perform consistently and independently; can guide others</td></tr>
  <tr><td class="c"><b>5</b></td><td><b>Expert</b></td><td>Mastery level; can train others; innovates and improves processes</td></tr>
</table>
</div>

<!-- ════════════════════════════════════════════════
     APPENDIX B - SELF-EVALUATION CHECKLIST
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>6 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">2. Appendix B: Self-Evaluation Checklist (Interview)</div>

<table class="ft">
  <tr>
    <th style="width:34px;">No</th>
    <th class="l">Activity / Competency Area</th>
    <th style="width:60px;">Rating (1-5)</th>
    <th class="l">Comments</th>
  </tr>
  <?php if (empty($appendixB)): ?>
  <tr><td colspan="4" style="text-align:center;padding:20px;font-style:italic;">No self-evaluation data saved yet</td></tr>
  <?php else: ?>
    <?php foreach ($appendixB as $idx => $item): ?>
    <tr>
      <td class="c"><?= $idx ?></td>
      <td><?= htmlspecialchars($item['activity_name'] ?? '') ?></td>
      <td class="c"><input type="text" value="<?= $item['competency_scale_id'] ?? '' ?>" style="width:50px;text-align:center;"></td>
      <td><span class="prefilled"><?= htmlspecialchars($item['comments'] ?? '') ?></span></td>
    </tr>
    <?php endforeach; ?>
  <?php endif; ?>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Candidate Details</p>
<table class="ft">
  <tr><td style="width:35%;"><b>Candidate Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']) ?></span></td></tr>
  <tr><td><b>ID Number:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['IDNumber']) ?></span></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Assessor Details</p>
<table class="ft">
  <tr><td style="width:35%;"><b>Assessor Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($facilitator['firstName'] ?? '') ?></span></td></tr>
  <tr><td><b>Assessor Number:</b></td><td><span class="prefilled"><?= htmlspecialchars($facilitator['assessorNo'] ?? '') ?></span></td></tr>
</table>

<div class="sig-row">
  <div class="sig-blk"><label>Candidate:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Assessor:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Date:</label><div class="sig-line"><input type="date"></div></div>
</div>
</div>

<!-- ════════════════════════════════════════════════
     APPENDIX D - PRACTICAL SKILLS ASSESSMENT
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>12 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">3. Appendix D: Practical Skills Assessment Evaluation Checklist</div>
<p style="font-size:11pt;margin:8px 0;">Response: YES | NO | NOT APPLICABLE</p>

<?php
// Define trade-specific practical criteria
$practicalCriteria = [
    '671101' => [ // Electrician
        'Safety', 'Hand & power tools', 'Measuring equipment', 'Plans & drawings',
        'Identification of cables', 'Conduit & ducting', 'Cable management',
        'Distribution boards', 'Wiring systems', 'Lighting circuits', 'Power circuits',
        'Protection devices', 'Testing & commissioning', 'Health & safety',
        'Environmental awareness'
    ],
    '641201' => [ // Bricklaying
        'Safety', 'Tools', 'Measuring equipment', 'Plans & drawings',
        'Brick identification', 'Mortar preparation', 'Material handling',
        'Cavity walls', 'Solid walls', 'Arches & openings', 'Pointing',
        'Bonding patterns', 'Structural components', 'Health & safety',
        'Environmental awareness'
    ],
    '642601' => [ // Plumbing
        'Safety', 'Tools', 'Measuring equipment', 'Plans & drawings',
        'Pipe identification', 'Fittings & joints', 'Material handling',
        'Water systems', 'Drainage systems', 'Sanitary ware', 'Valves',
        'System testing', 'Installations', 'Health & safety',
        'Environmental awareness'
    ]
];

$criteria = $practicalCriteria[$ofoNumber] ?? $practicalCriteria['671101'];
?>

<table class="ft">
  <tr>
    <th style="width:34px;">No</th>
    <th class="l">Practical Criteria</th>
    <th style="width:100px;">Response</th>
  </tr>
  <?php foreach ($criteria as $idx => $criterion): ?>
  <tr>
    <td class="c"><?= $idx + 1 ?></td>
    <td><?= htmlspecialchars($criterion) ?></td>
    <td class="c"><input type="text" placeholder="Yes/No/N/A" style="width:90px;text-align:center;"></td>
  </tr>
  <?php endforeach; ?>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Assessor Verification</p>
<table class="ft">
  <tr><td><b>Assessor Findings:</b><br><textarea rows="3" placeholder="Assessor comments on practical skills assessment..."></textarea></td></tr>
</table>

<div class="sig-row">
  <div class="sig-blk"><label>Assessor:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Date:</label><div class="sig-line"><input type="date"></div></div>
</div>
</div>

<!-- ════════════════════════════════════════════════
     APPENDIX E - WORKPLACE EXPERIENCE EVALUATION
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>15 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">4. Appendix E: Workplace Experience Evaluation (Interview)</div>
<p style="font-size:11pt;margin:8px 0;">Competency Scale: 1=Fundamental | 2=Novice | 3=Intermediate | 4=Advanced | 5=Expert</p>

<table class="ft">
  <tr>
    <th style="width:34px;">No</th>
    <th class="l">Workplace Activity</th>
    <th style="width:60px;">Rating (1-5)</th>
    <th class="l">Comments</th>
  </tr>
  <?php if (empty($appendixE)): ?>
  <tr><td colspan="4" style="text-align:center;padding:20px;font-style:italic;">No workplace experience data recorded yet</td></tr>
  <?php else: ?>
    <?php foreach ($appendixE as $idx => $item): ?>
    <tr>
      <td class="c"><?= $idx ?></td>
      <td><?= htmlspecialchars($item['activity_name'] ?? '') ?></td>
      <td class="c"><input type="text" value="<?= $item['competency_scale_id'] ?? '' ?>" style="width:50px;text-align:center;"></td>
      <td><span class="prefilled"><?= htmlspecialchars($item['comments'] ?? '') ?></span></td>
    </tr>
    <?php endforeach; ?>
  <?php endif; ?>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Witness Details</p>
<table class="ft">
  <tr><td style="width:35%;"><b>Witness Name:</b></td><td><input type="text" placeholder="Workplace supervisor/witness"></td></tr>
  <tr><td><b>Witness Contact:</b></td><td><input type="tel" placeholder="Contact number"></td></tr>
</table>

<div class="sig-row">
  <div class="sig-blk"><label>Candidate:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Witness:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Date:</label><div class="sig-line"><input type="date"></div></div>
</div>
</div>

<!-- ════════════════════════════════════════════════
     APPENDIX F - ASSESSMENT EVALUATION AGREEMENT
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>18 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">5. Appendix F: Assessment Evaluation Agreement</div>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">ASSESSMENT COMPONENTS</p>

<p style="font-size:11pt;margin:8px 0;"><b>Knowledge Assessment</b></p>
<table class="ft">
  <tr>
    <th class="l" style="width:50%;">Component</th>
    <th style="width:20%;">Score</th>
    <th style="width:30%;">Percentage</th>
  </tr>
  <tr><td>Written Knowledge Examination</td><td><input type="text" placeholder="Score" style="text-align:center;"></td><td><input type="text" placeholder="%" style="text-align:center;"></td></tr>
  <tr><td>Knowledge Assessment Total</td><td><input type="text" placeholder="Total" style="text-align:center;"></td><td><input type="text" placeholder="%" style="text-align:center;"></td></tr>
</table>

<p style="font-size:11pt;margin:8px 0;"><b>Practical Assessment</b></p>
<table class="ft">
  <tr>
    <th class="l" style="width:50%;">Task / Component</th>
    <th style="width:20%;">Score</th>
    <th style="width:30%;">Percentage</th>
  </tr>
  <tr><td>Practical Task 1</td><td><input type="text" placeholder="Score" style="text-align:center;"></td><td><input type="text" placeholder="%" style="text-align:center;"></td></tr>
  <tr><td>Practical Task 2</td><td><input type="text" placeholder="Score" style="text-align:center;"></td><td><input type="text" placeholder="%" style="text-align:center;"></td></tr>
  <tr><td>Practical Assessment Total</td><td><input type="text" placeholder="Total" style="text-align:center;"></td><td><input type="text" placeholder="%" style="text-align:center;"></td></tr>
</table>

<p style="font-size:11pt;margin:8px 0;"><b>Workplace Observation</b></p>
<table class="ft">
  <tr>
    <th class="l" style="width:50%;">Observation Area</th>
    <th style="width:20%;">Score</th>
    <th style="width:30%;">Percentage</th>
  </tr>
  <tr><td>Technical Competence</td><td><input type="text" placeholder="Score" style="text-align:center;"></td><td><input type="text" placeholder="%" style="text-align:center;"></td></tr>
  <tr><td>Workplace Behaviour</td><td><input type="text" placeholder="Score" style="text-align:center;"></td><td><input type="text" placeholder="%" style="text-align:center;"></td></tr>
  <tr><td>Workplace Total</td><td><input type="text" placeholder="Total" style="text-align:center;"></td><td><input type="text" placeholder="%" style="text-align:center;"></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">OVERALL ASSESSMENT RESULT</p>
<table class="ft">
  <tr>
    <th class="l">Assessment Component</th>
    <th style="width:20%;">Weighting</th>
    <th style="width:20%;">Score</th>
    <th style="width:30%;">Weighted Result</th>
  </tr>
  <tr><td>Knowledge Assessment</td><td class="c">40%</td><td><input type="text" style="text-align:center;"></td><td><input type="text" style="text-align:center;"></td></tr>
  <tr><td>Practical Assessment</td><td class="c">40%</td><td><input type="text" style="text-align:center;"></td><td><input type="text" style="text-align:center;"></td></tr>
  <tr><td>Workplace Observation</td><td class="c">20%</td><td><input type="text" style="text-align:center;"></td><td><input type="text" style="text-align:center;"></td></tr>
  <tr><td><b>FINAL SCORE</b></td><td class="c"><b>100%</b></td><td colspan="2" style="text-align:center;"><input type="text" style="text-align:center;font-weight:bold;"></td></tr>
</table>

<div class="sig-row">
  <div class="sig-blk"><label>Assessor:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Candidate:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Date:</label><div class="sig-line"><input type="date"></div></div>
</div>
</div>

<!-- ════════════════════════════════════════════════
     APPENDIX G - APPEALS FORM
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>21 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">6. Appendix G: Appeals Form</div>

<table class="ft">
  <tr><td style="width:35%;"><b>Candidate Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']) ?></span></td></tr>
  <tr><td><b>Assessment Date:</b></td><td><input type="date"></td></tr>
  <tr><td><b>Reason for Appeal:</b></td><td><textarea rows="3" placeholder="Explain reason for appeal..."></textarea></td></tr>
  <tr><td><b>Supporting Evidence:</b></td><td><textarea rows="3" placeholder="Provide supporting evidence or documentation..."></textarea></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Formal Appeal Process</p>
<table class="ft">
  <tr><td><b>Submitted to:</b></td><td><input type="text" placeholder="Appeals officer name"></td></tr>
  <tr><td><b>Date Received:</b></td><td><input type="date"></td></tr>
  <tr><td><b>Appeal Decision:</b></td><td><input type="text" placeholder="Upheld / Rejected / Referred"></td></tr>
  <tr><td><b>Reason for Decision:</b></td><td><textarea rows="3" placeholder="Reasoning..."></textarea></td></tr>
</table>

<div class="sig-row">
  <div class="sig-blk"><label>Candidate:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Appeals Officer:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Date:</label><div class="sig-line"><input type="date"></div></div>
</div>
</div>

<!-- ════════════════════════════════════════════════
     APPENDIX H - ACCESS RECOMMENDATION
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>22 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">7. Appendix H: Access Recommendation</div>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">ASSESSMENT COMPONENTS EVALUATION</p>

<table class="ft">
  <tr>
    <th class="l">Assessment Component</th>
    <th style="width:30%;">Result</th>
    <th class="l">Recommendation</th>
  </tr>
  <tr>
    <td>Knowledge Assessment</td>
    <td><input type="text" placeholder="Pass/Fail"></td>
    <td><input type="text" placeholder="Comment"></td>
  </tr>
  <tr>
    <td>Practical Assessment</td>
    <td><input type="text" placeholder="Pass/Fail"></td>
    <td><input type="text" placeholder="Comment"></td>
  </tr>
  <tr>
    <td>Workplace Observation</td>
    <td><input type="text" placeholder="Pass/Fail"></td>
    <td><input type="text" placeholder="Comment"></td>
  </tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">OVERALL RECOMMENDATION</p>

<table class="ft">
  <tr><td style="width:35%;"><b>Overall Result:</b></td><td><input type="text" placeholder="Access to Qualification / Gap Closure / Not Yet Competent"></td></tr>
  <tr><td><b>Assessor Comment:</b></td><td><textarea rows="3" placeholder="Provide detailed assessment feedback..."></textarea></td></tr>
</table>

<table class="ft">
  <tr>
    <th>Option</th>
    <th class="c" style="width:80px;">Select</th>
    <th class="l">Details</th>
  </tr>
  <tr>
    <td>Access to full Qualification</td>
    <td class="c"><input type="checkbox"></td>
    <td>Candidate has demonstrated full competency</td>
  </tr>
  <tr>
    <td>Access - Gap Closure Required</td>
    <td class="c"><input type="checkbox"></td>
    <td>Specify unit standards for gap closure below</td>
  </tr>
  <tr>
    <td>Not Yet Competent</td>
    <td class="c"><input type="checkbox"></td>
    <td>Further training and reassessment required</td>
  </tr>
  <tr>
    <td>Referred to Trade Test</td>
    <td class="c"><input type="checkbox"></td>
    <td>Candidate referred to formal trade test</td>
  </tr>
</table>

<div class="sig-row">
  <div class="sig-blk"><label>Assessor:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Moderator:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Date:</label><div class="sig-line"><input type="date"></div></div>
</div>
</div>

<!-- ════════════════════════════════════════════════
     APPENDIX I - STATEMENT OF RESULTS
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>25 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">8. Appendix I: Statement of Results</div>

<div style="text-align:center;margin:20px 0;">
  <div style="font-size:14pt;font-weight:bold;">ARTISAN RECOGNITION OF PRIOR LEARNING</div>
  <div style="font-size:12pt;font-weight:bold;margin:5px 0;">Statement of Results</div>
  <div style="font-size:11pt;margin:10px 0;"><?= htmlspecialchars($tradeName . ' - OFO ' . $ofoNumber) ?></div>
</div>

<table class="ft">
  <tr><td style="width:35%;"><b>Candidate Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']) ?></span></td></tr>
  <tr><td><b>ID Number:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['IDNumber']) ?></span></td></tr>
  <tr><td><b>Assessment Date:</b></td><td><input type="date"></td></tr>
  <tr><td><b>Assessment Provider:</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></span></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">ASSESSMENT RESULTS</p>

<table class="ft">
  <tr>
    <th class="l">Assessment Area</th>
    <th style="width:25%;">Score/Grade</th>
    <th style="width:25%;">Result</th>
    <th class="l">Remarks</th>
  </tr>
  <tr>
    <td>Knowledge Assessment</td>
    <td><input type="text" style="text-align:center;"></td>
    <td><input type="text" style="text-align:center;"></td>
    <td><input type="text"></td>
  </tr>
  <tr>
    <td>Practical Assessment</td>
    <td><input type="text" style="text-align:center;"></td>
    <td><input type="text" style="text-align:center;"></td>
    <td><input type="text"></td>
  </tr>
  <tr>
    <td>Workplace Observation</td>
    <td><input type="text" style="text-align:center;"></td>
    <td><input type="text" style="text-align:center;"></td>
    <td><input type="text"></td>
  </tr>
  <tr style="background:#e8f5e9;font-weight:bold;">
    <td>OVERALL RESULT</td>
    <td><input type="text" style="text-align:center;font-weight:bold;"></td>
    <td><input type="text" style="text-align:center;font-weight:bold;"></td>
    <td><input type="text"></td>
  </tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">QUALIFICATION ACCESS STATUS</p>

<div class="res-grid">
  <div class="res-item">
    <strong style="color:#006341;">✓ Full Access Granted</strong>
    Candidate has demonstrated full competency in all areas and is granted access to the full qualification
  </div>
  <div class="res-item">
    <strong style="color:#ff6f00;">⟡ Gap Closure Required</strong>
    Candidate requires gap closure in specified areas (see details below)
  </div>
  <div class="res-item">
    <strong style="color:#d32f2f;">✗ Not Yet Competent</strong>
    Candidate has not demonstrated sufficient competency. Further training required
  </div>
  <div class="res-item">
    <strong style="color:#006341;">→ Trade Test Referred</strong>
    Candidate has been referred to formal trade test for final determination
  </div>
</div>

<div class="sig-row">
  <div class="sig-blk"><label>Assessor:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Moderator:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Date:</label><div class="sig-line"><input type="date"></div></div>
</div>
</div>

<!-- ════════════════════════════════════════════════
     APPENDIX J - CANDIDATE PRE-ASSESSMENT AGREEMENT
════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>28 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">9. Appendix J: Candidate Pre-Assessment Agreement</div>

<p style="font-size:11pt;margin:10px 0;"><b>This agreement confirms that the candidate has:</b></p>

<table class="ft">
  <tr>
    <th class="c" style="width:50px;">☐</th>
    <th class="l">Confirmations</th>
  </tr>
  <tr>
    <td class="c"><input type="checkbox"></td>
    <td>Been informed of the purpose, scope and requirements of the ARPL assessment</td>
  </tr>
  <tr>
    <td class="c"><input type="checkbox"></td>
    <td>Been provided with information about the competency standards and assessment criteria</td>
  </tr>
  <tr>
    <td class="c"><input type="checkbox"></td>
    <td>Been informed of the assessment methods and activities that will be used</td>
  </tr>
  <tr>
    <td class="c"><input type="checkbox"></td>
    <td>Been given an opportunity to ask questions and clarify any uncertainties</td>
  </tr>
  <tr>
    <td class="c"><input type="checkbox"></td>
    <td>Been informed of the appeals and grievance procedures</td>
  </tr>
  <tr>
    <td class="c"><input type="checkbox"></td>
    <td>Consented to the assessment process and provision of evidence</td>
  </tr>
  <tr>
    <td class="c"><input type="checkbox"></td>
    <td>Been informed that the assessment is fair, valid and reliable</td>
  </tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Candidate Acknowledgement</p>

<table class="ft">
  <tr><td style="width:35%;"><b>Candidate Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']) ?></span></td></tr>
  <tr><td><b>ID Number:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['IDNumber']) ?></span></td></tr>
  <tr><td><b>Date of Agreement:</b></td><td><input type="date"></td></tr>
</table>

<p style="font-size:10pt;margin:12px 0;font-style:italic;">I confirm that I have read and understood the above agreement and agree to participate in the ARPL assessment process on the terms and conditions stated.</p>

<div class="sig-row">
  <div class="sig-blk"><label>Candidate Signature:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Assessor Signature:</label><div class="sig-line"></div></div>
  <div class="sig-blk"><label>Date:</label><div class="sig-line"><input type="date"></div></div>
</div>

<div class="note">
  <b>Note:</b> This completed agreement form must be retained as evidence of proper pre-assessment procedures and filed with the ARPL portfolio
</div>
</div>

</div><!-- End .page -->
</body>
</html>
