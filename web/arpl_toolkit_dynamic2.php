<?php
// ============================================================
// ARPL TOOLKIT - Single Learner per Form
// Entry points:
//   SDP dashboard : ?classID=X&learnerID=Y  (sdp session)
//   Facilitator   : session classID + ?learnerID=Y
// ============================================================
session_start();
include 'connection.php';
date_default_timezone_set('Africa/Johannesburg');
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
// ── Auth ─────────────────────────────────────────────────────
$is_sdp         = isset($_SESSION['sdp_id']);
$is_facilitator = isset($_SESSION['facilitator_id']);

if (!$is_sdp && !$is_facilitator) {
    header("Location: index.php");
    exit;
}

// ── Resolve classID & learnerID from GET or session ──────────
$classID   = isset($_GET['classID'])   ? (int)$_GET['classID']   : (int)($_SESSION['classID'] ?? 0);
$learnerID = isset($_GET['learnerID']) ? (int)$_GET['learnerID'] : 0;

if (!$classID) {
    echo "<script>alert('No class selected. Please go back and select a class.'); window.history.back();</script>";
    exit;
}
if (!$learnerID) {
    echo "<script>alert('No learner selected. Please go back and select a learner.'); window.history.back();</script>";
    exit;
}

// ── STEP 1 – FACILITATOR / ASSESSOR ──────────────────────────
$facilitator = ['firstName' => '', 'lastName' => '', 'assessorNo' => ''];
$facilitator_id = isset($_SESSION['facilitator_id']) ? (int)$_SESSION['facilitator_id'] : 0;

if ($facilitator_id > 0) {
    $st = $conn->prepare("SELECT * FROM facilitator WHERE facilitator_id = ?");
    $st->bind_param("i", $facilitator_id);
    $st->execute();
    $frow = $st->get_result()->fetch_assoc();
    $st->close();
    if ($frow) { $facilitator = $frow; }
}
// Fallback – find facilitator for this class
if (empty($facilitator['firstName'])) {
    $st = $conn->prepare("SELECT * FROM facilitator WHERE FIND_IN_SET(?, classID) > 0 LIMIT 1");
    $st->bind_param("i", $classID);
    $st->execute();
    $frow = $st->get_result()->fetch_assoc();
    $st->close();
    if ($frow) { $facilitator = $frow; }
}

// ── STEP 2 – CLASS + SITE + PROJECT + SDP ────────────────────
$sql = "SELECT c.*, s.siteID, s.siteName, s.Province, s.District, s.Municipality,
               s.cell_phone AS site_phone, s.email AS site_email,
               s.project_id, s.sdp_id, s.qualification_id,
               p.Project_name, p.Contract_no, p.Financial_year,
               p.Start_date, p.End_date, p.sdp_name, p.Project_funder,
               sdp.sdp_name AS provider_name, sdp.accreditation_n,
               sdp.p_address AS provider_address, sdp.email AS provider_email
        FROM class c
        JOIN sites s   ON c.siteID   = s.siteID
        JOIN project p ON s.project_id = p.project_id
        JOIN sdp       ON s.sdp_id   = sdp.sdp_id
        WHERE c.classID = ?";
$st = $conn->prepare($sql);
$st->bind_param("i", $classID);
$st->execute();
$ctx = $st->get_result()->fetch_assoc();
$st->close();

if (!$ctx) {
    echo "<script>alert('Class data not found.'); window.history.back();</script>";
    exit;
}

$project_id       = (int)($ctx['project_id']     ?? 0);
$siteID           = (int)($ctx['siteID']          ?? 0);
$qualification_id =       $ctx['qualification_id'] ?? '';

// ── STEP 3 – QUALIFICATION NAME (static for Plumber) ───────────
$qual_name = 'Plumber';
$qual_type = 'Legacy';
$qualification_id = '642601';

// ── STEP 4 – UNIT STANDARDS ───────────────────────────────────
$unit_standards = [];
$tbl = ($qual_type === 'Occupational') ? 'occupational_unit_standards' : 'unitstandard';
$id_col = ($qual_type === 'Occupational') ? 'Module_Code' : 'unitstandard_id';

$st = $conn->prepare(
    "SELECT $id_col AS us_id, unit_standard_name FROM $tbl WHERE qualification_id = ?"
);
$st->bind_param("s", $qualification_id);
$st->execute();
$usres = $st->get_result();
while ($row = $usres->fetch_assoc()) { $unit_standards[] = $row; }
$st->close();

// ── STEP 5 – ASSESSMENTS per unit standard ───────────────────
$assessments_by_us = [];
foreach ($unit_standards as $us) {
    $us_id = $us['us_id'];
    $assessments_by_us[$us_id] = ['summative' => [], 'formative' => []];
    foreach (['assessment_type', 'assesment_type'] as $col) {
        $st = $conn->prepare(
            "SELECT assessment_id, question_number, exercise, answer, marks,
                    $col AS atype, question_type, specific_outcome, assessment_criteria
             FROM assessments
             WHERE project_id = ? AND unit_standard_id = ?
             ORDER BY question_number"
        );
        if ($st) {
            $st->bind_param("ss", $project_id, $us_id);
            if ($st->execute()) {
                $ar = $st->get_result();
                while ($row = $ar->fetch_assoc()) {
                    $t   = strtolower($row['atype'] ?? 'summative');
                    $key = (strpos($t, 'form') !== false) ? 'formative' : 'summative';
                    $assessments_by_us[$us_id][$key][] = $row;
                }
                $st->close();
                break;
            }
            $st->close();
        }
    }
}

// ── STEP 6 – SINGLE LEARNER ───────────────────────────────────
$st = $conn->prepare(
    "SELECT LearnerID, Title, Name, Surname, IDNumber, DateOfBirth,
            PhoneNumber, Email, Gender, Race, Language,
            AddressLine1, AddressLine2, AddressLine3, PostalCode,
            SchoolName, SchoolCompletion, SchoolGrade,
            activity_statu, signature
     FROM learnerdetails
     WHERE LearnerID = ? AND classID = ?"
);
$st->bind_param("ii", $learnerID, $classID);
$st->execute();
$single_learner = $st->get_result()->fetch_assoc();
$st->close();

if (!$single_learner) {
    echo "<script>alert('Learner not found in this class.'); window.history.back();</script>";
    exit;
}

// ── Load existing ARPL toolkit data if it exists ─────────────
$arpl_data = null;
$st = $conn->prepare("SELECT form_data FROM arpl_toolkit2_data WHERE learner_id = ?");
if ($st) {
    $st->bind_param("i", $learnerID);
    $st->execute();
    $result = $st->get_result();
    if ($row = $result->fetch_assoc()) {
        $arpl_data = json_decode($row['form_data'], true);
    }
    $st->close();
}

// ── Load signatures from files ───────────────────────────────
require_once 'signature_handler.php';
$signature_handler = new SignatureHandler($conn);
$signature_data = $signature_handler->getAllSignatureDataURLs($learnerID);

// Merge signature data with form data for JavaScript loading
if ($arpl_data && !empty($signature_data)) {
    $arpl_data = array_merge($arpl_data, $signature_data);
} elseif (!$arpl_data && !empty($signature_data)) {
    $arpl_data = $signature_data;
}

// Wrap in array so the template loop still works (one iteration)
$learners = [$single_learner];

// ── STEP 7 – POE for this learner ─────────────────────────────
$poe_by_learner = [];
$st = $conn->prepare(
    "SELECT learnerID, exercise, type, filePath, submitted_at
     FROM poe WHERE learnerID = ?"
);
$st->bind_param("i", $learnerID);
$st->execute();
$pres = $st->get_result();
while ($p = $pres->fetch_assoc()) {
    $lid = $p['learnerID'];
    $t   = strtolower($p['type'] ?? 'summative');
    $key = (strpos($t, 'form') !== false) ? 'formative' : 'summative';
    preg_match('/- (\S+) -/', $p['exercise'], $m);
    $usid = $m[1] ?? 'general';
    $poe_by_learner[$lid][$usid][$key][] = $p;
}
$st->close();

$today = date('d F Y');
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>ARPL Toolkit – <?= htmlspecialchars($single_learner['Name'].' '.$single_learner['Surname']) ?> – <?= htmlspecialchars($qual_name) ?></title>
<script src="https://cdn.jsdelivr.net/npm/signature_pad@4.1.7/dist/signature_pad.umd.min.js"></script>
<style>
/* ── Signature Pad ── */
.sig-pad-wrapper{display:flex;flex-direction:column;gap:8px;}
.sig-pad-canvas{border:1px dashed #999;border-radius:4px;background:#fff;touch-action:none;width:100%;height:80px;}
.sig-pad-buttons{display:flex;gap:8px;}
.sig-pad-btn{padding:4px 12px;border:1px solid #006341;background:#fff;color:#006341;border-radius:4px;cursor:pointer;font-size:10pt;}
.sig-pad-btn:hover{background:#006341;color:#fff;}
@media print{
  .sig-pad-buttons{display:none;}
  .sig-pad-canvas{border:none;}
}
/* ── Reset ── */
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:"Times New Roman",Times,serif;font-size:12pt;color:#000;background:#ccc;}

/* ── Page wrapper ── */
.page{max-width:820px;margin:16px auto;background:#fff;padding:50px 58px;
      box-shadow:0 3px 20px rgba(0,0,0,.25);}

/* ── Toolbar (screen only) ── */
.toolbar{display:flex;justify-content:flex-end;gap:10px;margin-bottom:20px;}
.toolbar button{padding:8px 22px;border:none;border-radius:4px;cursor:pointer;
                font-size:11pt;font-weight:700;background:#006341;color:#fff;}
.toolbar button:hover{opacity:.88;}
.toolbar button.sec{background:#fff;color:#006341;border:2px solid #006341;}

/* ══════════════════════════════════════
   COVER PAGE  — matches screenshot exactly
══════════════════════════════════════ */

/* The cover sits inside .page, fills one printed page */
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

/* ── diagonal watermark (light grey, behind everything) ── */
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

/* everything above watermark */
.cover-page > *{ position:relative; z-index:1; }

/* ── TOP-LEFT: logo block ── */
.cover-logo-row{
  display:flex;
  align-items:center;
  justify-content:center; /* Center the entire logo row */
  gap:14px;
  margin-bottom:60px;
}

/* The actual SA Coat of Arms image */
.dhet-coa{
  width:88px;
  height:auto;
  flex-shrink:0;
}

/* text to the right of the logo */
.dhet-text{
  text-align:center; /* Center the text inside dhet-text */
  font-family:Arial,Helvetica,sans-serif;
  line-height:1.2;
}
.dhet-text .t1{            /* "higher education" */
  font-size:20pt;
  font-weight:bold;
  color:#000;
  line-height:1.05;
}
.dhet-text .t2{            /* "& training" */
  font-size:20pt;
  font-weight:bold;
  color:#000;
  margin-bottom:5px;
}
.dhet-text hr{
  border:none;
  border-top:1.5px solid #000;
  margin:4px 0 5px;
}
.dhet-text .t3{            /* "Department:" */
  font-size:9pt;
  color:#333;
}
.dhet-text .t4{            /* "Higher Education and Training" */
  font-size:9.5pt;
  color:#333;
}
.dhet-text .t5{            /* "REPUBLIC OF SOUTH AFRICA" */
  font-size:9.5pt;
  font-weight:bold;
  color:#000;
  text-transform:uppercase;
  letter-spacing:.4px;
}

/* ── CENTRE TEXT (all bold, centred, widely spaced) ── */
.cover-title-block{
  width:100%;
  text-align:center;
  margin-top:10px;
}
.cover-title-block .ct{
  font-family:"Times New Roman",Times,serif;
  font-weight:bold;
  color:#000;
  display:block;
}
.ct-arpl  { font-size:16pt; margin-bottom:4px; }
.ct-bracket{ font-size:16pt; margin-bottom:32px; }
.ct-toolkit{ font-size:14pt; margin-bottom:32px; }
.ct-ofo   { font-size:13pt; margin-bottom:32px; }
.ct-label { font-size:12pt; margin-bottom:2px; }
.ct-value { font-size:12pt; margin-bottom:28px; }

/* ══════════════════════════════════════
   DOC HEADER TABLE (all other pages)
══════════════════════════════════════ */
.dht{width:100%;border-collapse:collapse;margin-bottom:12px;font-size:10pt;}
.dht td{border:1px solid #000;padding:4px 7px;}

/* ── Titles ── */
.doc-title{text-align:center;font-size:15pt;font-weight:bold;margin:8px 0 3px;}
.doc-sub  {text-align:center;font-size:12pt;font-weight:bold;margin-bottom:5px;}
.sec-title{font-size:13pt;font-weight:bold;margin:18px 0 7px;}
.sec-sub  {font-size:12pt;font-weight:bold;margin:12px 0 5px;}

/* ── Generic table ── */
table.ft{width:100%;border-collapse:collapse;margin-bottom:10px;font-size:12pt;}
table.ft th{background:#000;color:#fff;padding:10px 12px;border:1px solid #000;text-align:center;}
table.ft th.l{text-align:left;}
table.ft td{border:1px solid #000;padding:10px 12px;vertical-align:middle;}
table.ft td.c{text-align:center;}
table.ft tr:nth-child(even) td{background:#f8f8f8;}

/* ── Inputs ── */
input[type=text],input[type=email],input[type=tel],input[type=date],
textarea,select{
  width:100%;border:none;border-bottom:1px solid #666;
  font-family:inherit;font-size:12pt;padding:4px 6px;
  background:transparent;color:#000;outline:none;}
textarea{resize:vertical;min-height:50px;border:1px solid #888;padding:6px;}
select{border:none;border-bottom:1px solid #666;background:transparent;}
input:focus,textarea:focus,select:focus{background:#fffde7;border-color:#006341;}
td input,td select{border:none;border-bottom:1px dashed #999;width:100%;}
td input:focus,td select:focus{background:#fffde7;}

/* Pre-filled */
.prefilled{font-style:italic;color:#006341;}

/* ── Radio / Checkbox ── */
.rc{text-align:center;}
.rc input[type=radio],.rc input[type=checkbox]{width:16px;height:16px;cursor:pointer;accent-color:#006341;}

/* ── Score scale ── */
.scn{font-size:13pt;font-weight:bold;text-align:center;}

/* ── Signature row/table (signature tab layout) ── */
.sig-row{display:flex;gap:22px;margin-top:10px;align-items:flex-end;}
.sig-table{width:100%;border-collapse:collapse;margin-top:10px;}
.sig-table td{border:none;padding:4px 0;vertical-align:bottom;}
.sig-blk{flex:1;}
.sig-blk label{font-size:10pt;font-weight:bold;display:block;margin-bottom:3px;}
.sig-line{border-bottom:1px solid #000;min-height:28px;padding:2px 4px;}
.sig-line input{border:none;background:transparent;width:100%;font-size:11pt;}

/* ── Note box ── */
.note{border:1px solid #000;padding:8px 12px;margin:8px 0;font-size:11pt;font-style:italic;}

/* ── Result items ── */
.res-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:10px;}
.res-item{border:1px solid #000;padding:9px 12px;}
.res-item strong{display:block;margin-bottom:5px;}

/* ── Page breaks ── */
.pb{page-break-before:always;margin-top:28px;padding-top:18px;border-top:1px dashed #ccc;}

/* ── US section ── */
.us-block{border:1px solid #000;padding:10px 14px;margin-bottom:16px;}
.us-block h4{font-size:11.5pt;margin-bottom:8px;color:#006341;}
.us-block h5{font-size:10.5pt;margin:8px 0 4px;background:#e8f5e9;padding:4px 8px;
             border-left:3px solid #006341;}

/* ── Alert / info ── */
.info{background:#e8f5e9;border-left:4px solid #006341;padding:8px 12px;
      font-size:10.5pt;margin-bottom:10px;color:#1b5e20;}

@media print{
  @page {
    size: A4;
    margin: 15mm;
  }
  body{background:#fff; -webkit-print-color-adjust: exact; print-color-adjust: exact;}
  .page{box-shadow:none;padding:0;margin:0;max-width:100%;width:100%;}
  .toolbar{display:none !important;}
  .sig-pad-buttons{display:none !important;}
  .bottom-print-button{display:none !important;}
  .cover-page{min-height:0;page-break-after:always;}
  .pb{page-break-before:always;}
  /* Prevent page breaks inside tables and sections */
  table, tr, td, th, .us-block {
    page-break-inside: avoid;
  }
}
</style>
</head>
<body>
<div class="page">

<!-- ══════════════════════════════════════════
     TOOLBAR (hidden on print)
══════════════════════════════════════════ -->
<div class="toolbar">
  <button class="sec" onclick="window.history.back()">← Back</button>
  <button onclick="saveArplData()">💾 Save</button>
  <button onclick="window.print()">🖨 Print / Save as PDF</button>
</div>

<!-- ══════════════════════════════════════════════════════════
     COVER PAGE  — matches Word document screenshot exactly
══════════════════════════════════════════════════════════ -->
<div class="cover-page">

  <!-- diagonal watermark -->
  <div class="wm"><?= htmlspecialchars($ctx['provider_name'] ?? 'MTL Training and Projects') ?></div>

  <!-- ── TOP LEFT: DHET Logo block (logo + text side by side) ── -->
  <div class="cover-logo-row">

    <!-- SA Coat of Arms SVG — accurately drawn to match the real DHET logo -->
    <img class="dhet-coa" src="logs/education.jpg" alt="Education logo">

    <!-- DHET text exactly as in screenshot -->
    <div class="dhet-text">
      <div class="t1">Higher Education</div>
      <div class="t2">&amp; Training</div>
      <hr>
      <div class="t3">Department:</div>
      <div class="t4">Higher Education and Training</div>
      <div class="t5">REPUBLIC OF SOUTH AFRICA</div>
    </div>

  </div><!-- /.cover-logo-row -->

  <!-- ── CENTRE TEXT — exact spacing and wording from screenshot ── -->
  <div class="cover-title-block">
    <span class="ct ct-arpl">ARTISAN RECOGNITION OF PRIOR LEARNING</span>
    <span class="ct ct-bracket">(ARPL)</span>
    <span class="ct ct-toolkit">TOOLKIT</span>
    <span class="ct ct-ofo">OFO: 642601</span>
    <span class="ct ct-label">Trade Title:</span>
    <span class="ct ct-value"><?= htmlspecialchars($qual_name) ?></span>
    <span class="ct ct-label">Alternative Title/Specialization:</span>
    <span class="ct ct-value">None</span>
  </div>

</div><!-- /.cover-page -->

<!-- ══════════════════════════════════════════════════════════
     CONTENTS PAGE
══════════════════════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? 'MTL Training and Projects') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? 'AC000153NAMB') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>2 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="doc-title" style="font-size:16pt;margin-bottom:6px;">
  <?= strtoupper(htmlspecialchars($qual_name)) ?> ARPL TOOLKIT
</div>
<div class="doc-sub" style="font-size:12pt;margin-bottom:16px;">
  ARTISAN RECOGNITION OF PRIOR LEARNING (ARPL)
</div>

<div class="sec-title">CONTENTS</div>
<table class="ft" style="margin-top:10px;">
  <tr><th class="l" style="width:70%;">INDEX</th><th>Page</th></tr>
  <tr><td>Appendix A: Application Form</td><td class="c">3</td></tr>
  <tr><td>Competency Proficiency Scale for Self-Evaluation/Interview</td><td class="c">5</td></tr>
  <tr><td>Appendix B: Self-Evaluation/Interview Checklist</td><td class="c">6</td></tr>
  <tr><td>Appendix C: Trade Curriculum Content Summary</td><td class="c">9</td></tr>
  <tr><td>&nbsp;&nbsp;&nbsp;Evaluation Criteria – Knowledge</td><td class="c">12</td></tr>
  <tr><td>&nbsp;&nbsp;&nbsp;Integrated Practical and Knowledge</td><td class="c">17</td></tr>
  <tr><td>&nbsp;&nbsp;&nbsp;Workplace (Done during interview/evaluation)</td><td class="c">18</td></tr>
  <tr><td>Appendix D: Practical Skills Assessment Evaluation Checklist</td><td class="c">18</td></tr>
  <tr><td>Competency Proficiency Scale for Work Place Evaluation/Interview</td><td class="c">20</td></tr>
  <tr><td>Appendix E: Work Place Experience Evaluation</td><td class="c">20</td></tr>
  <tr><td>Appendix F: Assessment Evaluation Agreement (Knowledge, Practical and Workplace)</td><td class="c">21</td></tr>
  <tr><td>Appendix G: Appeals Form</td><td class="c">24</td></tr>
  <tr><td>Appendix H: Access Recommendation</td><td class="c">25</td></tr>
  <tr><td>Appendix I: Statement of Results</td><td class="c">26</td></tr>
  <tr><td>Appendix J: Candidate Pre-Assessment Agreement</td><td class="c">30</td></tr>
</table>

<p style="font-size:11pt;margin-top:14px;"><b>NOTE:</b> All appendices to be included in the PoE</p>
<p style="font-size:11pt;margin-top:10px;">The following Attachments are separate to this document:</p>
<ul style="margin:8px 0 0 24px;font-size:11pt;line-height:2;">
  <li>Candidate Pre-Assessment Agreement</li>
  <li>Knowledge Assessment Question papers</li>
  <li>Memoranda to the Question papers</li>
  <li>Integrated Practical Tasks</li>
  <li>Practical Tasks marking matrix</li>
</ul>

<div class="info" style="margin-top:20px;display:none;">
  <b>Generating toolkit for:</b> &nbsp;
  <b><?= htmlspecialchars($single_learner['Name'].' '.$single_learner['Surname']) ?></b>
  &nbsp;(ID: <?= htmlspecialchars($single_learner['IDNumber']) ?>) &nbsp;|&nbsp;
  Class: <b><?= htmlspecialchars($ctx['className'] ?? '') ?></b> &nbsp;|&nbsp;
  Site: <b><?= htmlspecialchars($ctx['siteName'] ?? '') ?></b> &nbsp;|&nbsp;
  Qualification: <b><?= htmlspecialchars($qual_name) ?></b>
</div>
</div><!-- end contents pb -->

<!-- ═══════════════════════════════════════════════════════════
     LEARNER ARPL FORM
═══════════════════════════════════════════════════════════ -->
<?php foreach ($learners as $idx => $l):
  $lid  = $l['LearnerID'];
  $fullname = trim($l['Name'].' '.$l['Surname']);
  $refno = 'ARPL-'.date('Y').'-PL-'.str_pad($lid,4,'0',STR_PAD_LEFT);
?>

<!-- ═══════════════════════════════════════════
     APPENDIX A – APPLICATION FORM
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>3 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">1. Appendix A: Application Form
  <span style="font-size:10pt;font-weight:normal;color:#555;">&nbsp;— <?= htmlspecialchars($fullname) ?></span>
</div>

<table class="ft" style="margin-bottom:8px;">
  <tr><td style="width:38%;"><b>Ref Number:</b></td>
      <td><span class="prefilled"><?= $refno ?></span></td></tr>
</table>

<div class="sec-sub">APPLICATION FOR RECOGNITION OF PRIOR LEARNING IN A LISTED TRADE</div>
<p style="font-size:11pt;font-weight:bold;margin:8px 0 6px;">Applicant Details:</p>

<table class="ft">
  <tr><td style="width:38%;"><b>Trade Title</b></td><td><?= htmlspecialchars($qual_name) ?></td></tr>
  <tr><td><b>OFO Code</b></td><td>642601</td></tr>
  <tr><td><b>Specialization / Alternative Trade Name</b></td><td><input type="text" placeholder="e.g. None"></td></tr>
  <tr><td><b>Name of Candidate</b></td><td><span class="prefilled"><?= htmlspecialchars($fullname) ?></span></td></tr>
</table>

<table class="ft">
  <tr>
    <th class="l" style="width:50%;">Physical Address</th>
    <th class="l">Postal Address</th>
  </tr>
  <tr>
    <td><span class="prefilled" id="physical-addr-1"><?= htmlspecialchars($l['AddressLine1'] ?? '') ?></span></td>
    <td><input type="text" id="postal-addr-1" name="postal-addr-1" placeholder="Postal address line 1"></td>
  </tr>
  <tr>
    <td><span class="prefilled" id="physical-addr-2"><?= htmlspecialchars($l['AddressLine2'] ?? '') ?></span></td>
    <td><input type="text" id="postal-addr-2" name="postal-addr-2" placeholder="Postal address line 2"></td>
  </tr>
  <tr>
    <td><span class="prefilled" id="physical-addr-3"><?= htmlspecialchars(($l['AddressLine3'] ?? '').' '.($l['PostalCode'] ?? '')) ?></span></td>
    <td><input type="text" id="postal-addr-3" name="postal-addr-3" placeholder="Postal code"></td>
  </tr>
  <tr>
    <td colspan="2" style="text-align:left;">
      <label style="cursor:pointer;">
        <input type="checkbox" id="same-address" name="same-address" onchange="toggleSameAddress()"> 
        Postal Address same as Physical Address
      </label>
    </td>
  </tr>
</table>

<table class="ft">
  <tr><td style="width:38%;"><b>Tel no</b></td><td><span class="prefilled"><?= htmlspecialchars($l['PhoneNumber'] ?? '') ?></span></td></tr>
  <tr><td><b>Fax no</b></td><td><input type="tel" placeholder="Fax number"></td></tr>
  <tr><td><b>Cell no</b></td><td><span class="prefilled"><?= htmlspecialchars($l['PhoneNumber'] ?? '') ?></span></td></tr>
  <tr><td><b>E-mail address</b></td><td><span class="prefilled"><?= htmlspecialchars($l['Email'] ?? '') ?></span></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Employment Status:</p>
<table class="ft">
  <tr>
    <td style="width:38%;"><b>Currently employed</b></td>
    <td>Yes <input type="radio" name="emp_<?=$lid?>" value="yes">
        &nbsp;&nbsp; No <input type="radio" name="emp_<?=$lid?>" value="no"></td>
  </tr>
  <tr>
    <td><b>Self employed</b></td>
    <td>Yes <input type="radio" name="selfemp_<?=$lid?>" value="yes">
        &nbsp;&nbsp; No <input type="radio" name="selfemp_<?=$lid?>" value="no"></td>
  </tr>
  <tr><td><b>Current/Most recent Employer</b></td><td><input type="text" placeholder="Employer name"></td></tr>
  <tr><td><b>Position/Job Title</b></td><td><input type="text" placeholder="e.g. Plumber / Pipe Fitter"></td></tr>
  <tr><td><b>Employer Address</b></td><td><input type="text" placeholder="Employer physical address"></td></tr>
  <tr><td><b>Reference</b></td><td><input type="text" placeholder="Supervisor / Foreman name"></td></tr>
  <tr><td><b>Tel no</b></td><td><input type="tel" placeholder="Employer telephone"></td></tr>
  <tr><td><b>Fax no</b></td><td><input type="tel" placeholder="Employer fax"></td></tr>
  <tr><td><b>Cell no</b></td><td><input type="tel" placeholder="Employer cell"></td></tr>
  <tr><td><b>E-mail address</b></td><td><input type="email" placeholder="Employer email"></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Employment History</p>
<table class="ft">
  <tr>
    <th class="l">Company</th>
    <th class="l">Position/Job Title</th>
    <th class="l">Period &amp; Duration</th>
    <th class="l">Contact (Tel)</th>
  </tr>
  <tr><td><input type="text" placeholder="Company name"></td><td><input type="text" placeholder="Job title"></td><td><input type="text" placeholder="e.g. 2018–2022 (4 yrs)"></td><td><input type="tel" placeholder="Tel"></td></tr>
  <tr><td><input type="text" placeholder="Company name"></td><td><input type="text" placeholder="Job title"></td><td><input type="text" placeholder="e.g. 2013–2017 (5 yrs)"></td><td><input type="tel" placeholder="Tel"></td></tr>
  <tr><td><input type="text" placeholder="Company name"></td><td><input type="text" placeholder="Job title"></td><td><input type="text" placeholder="e.g. 2008–2012 (5 yrs)"></td><td><input type="tel" placeholder="Tel"></td></tr>
</table>

<table class="sig-table">
  <tr>
    <td style="width:40%;">
      <label>Candidate Signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="candidate-sig-<?= $lid ?>"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="candidate-sig-<?= $lid ?>" id="candidate-sig-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:30%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
    <td style="width:30%;"></td>
  </tr>
</table>
</div><!-- end pb -->


<!-- ═══════════════════════════════════════════
     COMPETENCY PROFICIENCY SCALE (Self-Eval)
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>5 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">2. Competency Proficiency Scale for Self-Evaluation (interview)</div>
<table class="ft">
  <tr><th colspan="3">COMPETENCY PROFICIENCY SCALE</th></tr>
  <tr><th style="width:55px;">Score</th><th>Proficiency Level</th><th class="l">Description</th></tr>
  <tr><td class="scn">1</td><td><b>Fundamental Awareness</b> (basic knowledge)</td><td>You have been exposed to this topic but your level of knowledge or practical skill is minimal.</td></tr>
  <tr><td class="scn">2</td><td><b>Novice</b> (limited experience)</td><td>You have experience related to this topic but you are not yet competent.</td></tr>
  <tr><td class="scn">3</td><td><b>Intermediate</b> (practical application)</td><td>You meet the minimum competency requirements related to this topic but require more knowledge, practical skills and experience.</td></tr>
  <tr><td class="scn">4</td><td><b>Advanced</b> (applied theory)</td><td>You have all the required knowledge, practical skills and experience related to this topic.</td></tr>
  <tr><td class="scn">5</td><td><b>Expert</b> (recognized authority)</td><td>You have expert knowledge, practical skills and experience related to this topic and can teach others.</td></tr>
</table>
</div>


<!-- ═══════════════════════════════════════════
     APPENDIX B – SELF-EVALUATION CHECKLIST
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>6 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">3. Appendix B: SELF-EVALUATION/INTERVIEW CHECKLIST
  <span style="font-size:10pt;font-weight:normal;">(Learner: <?= htmlspecialchars($fullname) ?>)</span>
</div>
<p style="font-size:11pt;margin-bottom:8px;"><b>Knowledge and practical skills</b> (For workplace refer to 5.3) — Ratings agreed to by candidate and Assessor.</p>

<?php
$activities = [
  1=>'Safety', 2=>'Hand and workshop tools and machines', 3=>'Measuring equipment',
  4=>'Plans and drawings', 5=>'Identification of material types (pipe and fittings)',
  6=>'Transport, storage and handling of materials', 7=>'Access equipment',
  8=>'Hot water system', 9=>'Cold water system', 10=>'Rain water systems',
  11=>'Above ground drainage systems', 12=>'Below ground drainage systems',
  13=>'SANS Codes and National Building Regulations', 14=>'Sanitary ware appliances',
  15=>'Trenching and backfill', 16=>'Basic building works', 17=>'Valves and terminal fittings',
  18=>'Hydraulic loading and air test', 19=>'Fitting and reading of meters',
  20=>'Brazing and soldering', 21=>'Jointing and laying of piping',
  22=>'Site assessment', 23=>'Risk assessment',
  24=>'Septic tank installation and maintenance', 25=>'Sheet metal fabrication'
];
?>
<table class="ft">
  <tr>
    <th style="width:34px;">No</th>
    <th class="l">ACTIVITY – Trade Related Questions</th>
    <th style="width:28px;">1</th><th style="width:28px;">2</th>
    <th style="width:28px;">3</th><th style="width:28px;">4</th>
    <th style="width:28px;">5</th>
    <th class="l">ASSESSOR COMMENTS</th>
  </tr>
  <?php foreach ($activities as $num => $act): ?>
  <tr>
    <td class="c"><?= $num ?></td>
    <td><?= htmlspecialchars($act) ?></td>
    <?php for ($r=1;$r<=5;$r++): ?>
    <td class="rc"><input type="radio" name="se_<?=$lid?>_<?=$num?>" value="<?=$r?>"></td>
    <?php endfor; ?>
    <td><input type="text" placeholder="Comment"></td>
  </tr>
  <?php endforeach; ?>
  <tr>
    <td colspan="8"><b>Additional comments</b><br>
      <textarea placeholder="Additional comments from assessor..."></textarea></td>
  </tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Candidate Details</p>
<table class="ft">
  <tr><td style="width:35%;"><b>COMPANY NAME:</b></td><td><input type="text" placeholder="Company / Employer name"></td></tr>
  <tr><td><b>CANDIDATE NAME:</b></td><td><span class="prefilled"><?= htmlspecialchars($l['Name']) ?></span></td></tr>
  <tr><td><b>SURNAME:</b></td><td><span class="prefilled"><?= htmlspecialchars($l['Surname']) ?></span></td></tr>
  <tr><td><b>ID NO:</b></td><td><span class="prefilled"><?= htmlspecialchars($l['IDNumber']) ?></span></td></tr>
  <tr><td><b>SIGNATURE:</b></td>
    <td>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="candidate-sig7-<?= $lid ?>"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig7-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="candidate-sig7-<?= $lid ?>" id="candidate-sig7-<?= $lid ?>-data">
      </div>
    </td>
  </tr>
  <tr><td><b>DATE:</b></td><td><input type="date" value="<?= date('Y-m-d') ?>"></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Assessor Details</p>
<table class="ft">
  <tr><td style="width:35%;"><b>ASSESSOR NAME:</b></td><td><span class="prefilled"><?= htmlspecialchars($facilitator['firstName'] ?? '') ?></span></td></tr>
  <tr><td><b>SURNAME:</b></td><td><span class="prefilled"><?= htmlspecialchars($facilitator['lastName'] ?? '') ?></span></td></tr>
  <tr><td><b>NAMB REG NO:</b></td><td><span class="prefilled"><?= htmlspecialchars($facilitator['assessorNo'] ?? '') ?></span></td></tr>
  <tr><td><b>SIGNATURE:</b></td>
    <td>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="assessor-sig6-<?= $lid ?>"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig6-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="assessor-sig6-<?= $lid ?>" id="assessor-sig6-<?= $lid ?>-data">
      </div>
    </td>
  </tr>
  <tr><td><b>DATE:</b></td><td><input type="date" value="<?= date('Y-m-d') ?>"></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Witness Details</p>
<table class="ft">
  <tr><td style="width:35%;"><b>WITNESS NAME:</b></td><td><input type="text" placeholder="Witness first name"></td></tr>
  <tr><td><b>SURNAME:</b></td><td><input type="text" placeholder="Witness surname"></td></tr>
  <tr><td><b>DATE:</b></td><td><input type="date" value="<?= date('Y-m-d') ?>"></td></tr>
  <tr><td><b>SIGNATURE:</b></td>
    <td>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="witness-sig-<?= $lid ?>"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('witness-sig-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="witness-sig-<?= $lid ?>" id="witness-sig-<?= $lid ?>-data">
      </div>
    </td>
  </tr>
</table>
</div><!-- end pb -->


<!-- ═══════════════════════════════════════════
     APPENDIX C – TRADE CURRICULUM (Unit Standards)
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>9 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">4. Appendix C: TRADE CURRICULUM CONTENT SUMMARY</div>

<div style="font-size:12pt;font-weight:bold;margin-bottom:10px;">Trade Overview</div>

<table class="ft" style="width:100%;">
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
<div style="margin:10px 0 10px 20px;">
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
<div style="margin:10px 0 10px 20px;">
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
<div style="margin:10px 0;">
  <strong>Scope of assessment:</strong>
  <ul style="margin:5px 0 5px 25px;">
    <li>Processes and procedures for installation and testing of above ground soil waste and vent systems and sanitary ware appliances</li>
    <li>Processes and procedures for installation and testing of below-ground drainage systems and performing basic building work</li>
    <li>Procedures and processes for installation and maintenance of cold water and hot water systems</li>
    <li>Procedures and processes for installation and maintenance of rain water systems</li>
  </ul>
</div>
</div><!-- end pb -->


<!-- ═══════════════════════════════════════════
     APPENDIX D – PRACTICAL SKILLS CHECKLIST
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>18 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">6. Appendix D: PRACTICAL SKILLS ASSESSMENT EVALUATION CHECKLIST
  <span style="font-size:10pt;font-weight:normal;">(<?= htmlspecialchars($fullname) ?>)</span>
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
  'Site assessment','Risk assessment','Septic tank','Sheet metal'
];
?>
<table class="ft">
  <tr>
    <th class="l">Criteria (Has the candidate applied and used the following with regards to the trade)</th>
    <th style="width:55px;">Yes</th>
    <th style="width:55px;">No</th>
  </tr>
  <?php foreach ($practicalCriteria as $pi => $pc): ?>
  <tr>
    <td><?= htmlspecialchars($pc) ?></td>
    <td class="rc"><input type="radio" name="prac_<?=$lid?>_<?=$pi?>" value="yes"></td>
    <td class="rc"><input type="radio" name="prac_<?=$lid?>_<?=$pi?>" value="no"></td>
  </tr>
  <?php endforeach; ?>
</table>

<table class="sig-table">
  <tr>
    <td style="width:40%;">
      <label>Candidate Signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="candidate-sig2-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig2-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="candidate-sig2-<?= $lid ?>" id="candidate-sig2-<?= $lid ?>-data">
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
      <label>Assessor Signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="assessor-sig-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="assessor-sig-<?= $lid ?>" id="assessor-sig-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:30%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
    <td style="width:30%;"></td>
  </tr>
</table>
</div><!-- end pb -->


<!-- ═══════════════════════════════════════════
     WORKPLACE SCALE + APPENDIX E
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>20 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">7. Competency Proficiency Scale for Work Place Evaluation (interview)</div>
<table class="ft">
  <tr><th colspan="3">COMPETENCY PROFICIENCY SCALE</th></tr>
  <tr><th style="width:55px;">Score</th><th>Proficiency Level</th><th class="l">Description</th></tr>
  <tr><td class="scn">1</td><td><b>Fundamental Awareness</b></td><td>Exposed; knowledge/practical skill is minimal.</td></tr>
  <tr><td class="scn">2</td><td><b>Novice</b></td><td>Experience related to topic; not yet competent.</td></tr>
  <tr><td class="scn">3</td><td><b>Intermediate</b></td><td>Meets minimum; requires more knowledge, skills and experience.</td></tr>
  <tr><td class="scn">4</td><td><b>Advanced</b></td><td>Has all required knowledge, practical skills and experience.</td></tr>
  <tr><td class="scn">5</td><td><b>Expert</b></td><td>Expert knowledge, skills and experience; can teach others.</td></tr>
</table>

<div class="sec-title" style="margin-top:20px;">8. Appendix E: WORKPLACE EXPERIENCE EVALUATION
  <span style="font-size:10pt;font-weight:normal;">(<?= htmlspecialchars($fullname) ?>)</span>
</div>

<table class="ft">
  <tr>
    <th style="width:34px;">NO</th>
    <th class="l">ACTIVITY</th>
    <th style="width:28px;">1</th><th style="width:28px;">2</th>
    <th style="width:28px;">3</th><th style="width:28px;">4</th>
    <th style="width:28px;">5</th>
    <th class="l">ASSESSOR COMMENTS</th>
  </tr>
  <?php
  $wActivities = [
    1=>'Occupational Health and Safety compliance',
    2=>'Remove and replace a burst electrical geyser',
    3=>'Setting out and installing a bathroom\'s sanitary appliances and drainage as per drawing and instructions',
    4=>'The use of appropriate fittings in the assembly and repair of plumbing systems',
    5=>'Use and care of machinery (guillotine, bending machine, plate roller) to fabricate a gutter and a downpipe',
  ];
  foreach ($wActivities as $wn => $wa): ?>
  <tr>
    <td class="c"><?= $wn ?>.</td>
    <td><?= htmlspecialchars($wa) ?></td>
    <?php for ($r=1;$r<=5;$r++): ?>
    <td class="rc"><input type="radio" name="wp_<?=$lid?>_<?=$wn?>" value="<?=$r?>"></td>
    <?php endfor; ?>
    <td><input type="text" placeholder="Comment"></td>
  </tr>
  <?php endforeach; ?>
</table>
</div><!-- end pb -->


<!-- ═══════════════════════════════════════════
     APPENDIX F – ASSESSMENT EVALUATION AGREEMENT
     (Auto-populated with unit standards + questions)
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>21 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">9. Appendix F: ASSESSMENT EVALUATION AGREEMENT
  <span style="font-size:10pt;font-weight:normal;">(<?= htmlspecialchars($fullname) ?>)</span>
</div>

<?php foreach ($unit_standards as $us):
  $usid = $us['us_id'];
  $sumQs  = $assessments_by_us[$usid]['summative']  ?? [];
  $formQs = $assessments_by_us[$usid]['formative']  ?? [];
  $poes   = $poe_by_learner[$lid][$usid] ?? [];
?>

<div class="us-block">
  <h4>Unit Standard: <?= htmlspecialchars($usid) ?> – <?= htmlspecialchars($us['unit_standard_name']) ?></h4>

  <!-- ── KNOWLEDGE SECTION (Summative) ── -->
  <h5>Knowledge Section (Summative Assessments)</h5>
  <?php if (empty($sumQs)): ?>
    <p style="font-style:italic;font-size:10pt;color:#888;">No summative questions loaded for this unit standard.</p>
  <?php else: ?>
  <table class="ft">
    <tr>
      <th style="width:34px;">Q No</th>
      <th class="l">Question / Exercise</th>
      <th class="l">Question Type</th>
      <th style="width:70px;">Max Marks</th>
      <th style="width:80px;">Candidate Score</th>
      <th style="width:60px;">%</th>
    </tr>
    <?php foreach ($sumQs as $q): ?>
    <tr>
      <td class="c"><b><?= htmlspecialchars($q['question_number'] ?? '') ?></b></td>
      <td><?= htmlspecialchars($q['exercise'] ?? '') ?></td>
      <td class="c"><?= htmlspecialchars($q['question_type'] ?? 'Knowledge') ?></td>
      <td class="c"><?= htmlspecialchars($q['marks'] ?? '') ?></td>
      <td><input type="text" placeholder="Score"></td>
      <td><input type="text" placeholder="%"></td>
    </tr>
    <?php endforeach; ?>
    <tr style="background:#e8eaf6;">
      <td colspan="3"><b>TOTAL</b></td>
      <td class="c"><b><?= array_sum(array_column($sumQs,'marks')) ?></b></td>
      <td><input type="text" placeholder="Total score"></td>
      <td><input type="text" placeholder="Total %"></td>
    </tr>
  </table>
  <?php endif; ?>

  <!-- ── PRACTICAL SECTION (Formative) ── -->
  <h5>Practical Section (Formative Assessments)</h5>
  <?php if (empty($formQs)): ?>
    <p style="font-style:italic;font-size:10pt;color:#888;">No formative questions loaded for this unit standard.</p>
  <?php else: ?>
  <table class="ft">
    <tr>
      <th style="width:34px;">Q No</th>
      <th class="l">Task / Exercise</th>
      <th class="l">Question Type</th>
      <th style="width:70px;">Max Marks</th>
      <th style="width:80px;">Candidate Score</th>
      <th style="width:60px;">%</th>
    </tr>
    <?php foreach ($formQs as $q): ?>
    <tr>
      <td class="c"><b><?= htmlspecialchars($q['question_number'] ?? '') ?></b></td>
      <td><?= htmlspecialchars($q['exercise'] ?? '') ?></td>
      <td class="c"><?= htmlspecialchars($q['question_type'] ?? 'Practical') ?></td>
      <td class="c"><?= htmlspecialchars($q['marks'] ?? '') ?></td>
      <td><input type="text" placeholder="Score"></td>
      <td><input type="text" placeholder="%"></td>
    </tr>
    <?php endforeach; ?>
    <tr style="background:#e8eaf6;">
      <td colspan="3"><b>TOTAL</b></td>
      <td class="c"><b><?= array_sum(array_column($formQs,'marks')) ?></b></td>
      <td><input type="text" placeholder="Total score"></td>
      <td><input type="text" placeholder="Total %"></td>
    </tr>
  </table>
  <?php endif; ?>

  <!-- ── POE UPLOADS ── -->
  <h5>POE Submissions (from system)</h5>
  <?php
  $allPoes = array_merge($poes['summative'] ?? [], $poes['formative'] ?? []);
  if (empty($allPoes)): ?>
    <p style="font-style:italic;font-size:10pt;color:#888;">No POE files uploaded for this unit standard.</p>
  <?php else: ?>
  <table class="ft">
    <tr>
      <th class="l">Exercise / Title</th>
      <th style="width:80px;">Type</th>
      <th class="l">File Path</th>
      <th style="width:110px;">Submitted At</th>
    </tr>
    <?php foreach ($allPoes as $poe): ?>
    <tr>
      <td><?= htmlspecialchars($poe['exercise'] ?? '') ?></td>
      <td class="c"><?= htmlspecialchars($poe['type'] ?? '') ?></td>
      <td><a href="<?= htmlspecialchars($poe['filePath'] ?? '#') ?>" target="_blank" style="font-size:10pt;"><?= htmlspecialchars(basename($poe['filePath'] ?? 'View')) ?></a></td>
      <td class="c" style="font-size:10pt;"><?= htmlspecialchars($poe['submitted_at'] ?? '') ?></td>
    </tr>
    <?php endforeach; ?>
  </table>
  <?php endif; ?>

  <!-- ── Workplace Observation for this US ── -->
  <h5>Workplace Observation</h5>
  <table class="ft">
    <tr>
      <th style="width:34px;">No</th>
      <th class="l">Tasks Observed</th>
      <th style="width:100px;">Technical Knowledge<br><small style="font-weight:300;">(1=Fair 2=Good 3=Excellent)</small></th>
      <th style="width:100px;">Interpretation of Instruction<br><small style="font-weight:300;">(1=Fair 2=Good 3=Excellent)</small></th>
      <th style="width:100px;">Team Work Attitude<br><small style="font-weight:300;">(1=Fair 2=Good 3=Excellent)</small></th>
    </tr>
    <?php for ($wi=1;$wi<=5;$wi++): ?>
    <tr>
      <td class="c"><?=$wi?></td>
      <td><input type="text" placeholder="Observed task"></td>
      <td class="c">
        <select name="obs_tk_<?=$lid?>_<?=$usid?>_<?=$wi?>">
          <option value="">--</option>
          <option>1 – Fair</option><option>2 – Good</option><option>3 – Excellent</option>
        </select>
      </td>
      <td class="c">
        <select name="obs_ii_<?=$lid?>_<?=$usid?>_<?=$wi?>">
          <option value="">--</option>
          <option>1 – Fair</option><option>2 – Good</option><option>3 – Excellent</option>
        </select>
      </td>
      <td class="c">
        <select name="obs_tw_<?=$lid?>_<?=$usid?>_<?=$wi?>">
          <option value="">--</option>
          <option>1 – Fair</option><option>2 – Good</option><option>3 – Excellent</option>
        </select>
      </td>
    </tr>
    <?php endfor; ?>
  </table>

</div><!-- end us-block -->
<?php endforeach; // end unit standards ?>

<table class="sig-table">
  <tr>
    <td style="width:40%;">
      <label>Assessor Signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="assessor-sig2-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig2-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="assessor-sig2-<?= $lid ?>" id="assessor-sig2-<?= $lid ?>-data">
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
      <label>Candidate Signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="candidate-sig3-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig3-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="candidate-sig3-<?= $lid ?>" id="candidate-sig3-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:30%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
    <td style="width:30%;"></td>
  </tr>
</table>
</div><!-- end pb -->


<!-- ═══════════════════════════════════════════
     APPENDIX G – APPEALS FORM
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>24 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">10. Appendix G: APPEALS FORM
  <span style="font-size:10pt;font-weight:normal;">(<?= htmlspecialchars($fullname) ?>)</span>
</div>

<table class="ft">
  <tr><td style="width:38%;"><b>Name of ARPL Candidate:</b></td><td><span class="prefilled"><?= htmlspecialchars($fullname) ?></span></td></tr>
  <tr><td><b>Name of Assessor:</b></td><td><span class="prefilled"><?= htmlspecialchars(($facilitator['firstName'] ?? '').' '.($facilitator['lastName'] ?? '')) ?></span></td></tr>
  <tr><td><b>Name of institution:</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></span></td></tr>
  <tr><td><b>Name of moderator:</b></td><td><input type="text" placeholder="Full name of moderator"></td></tr>
  <tr><td><b>Reason for appeal:</b></td>
      <td><textarea rows="5" placeholder="State the reason for the appeal clearly..."></textarea></td></tr>
</table>

<table class="sig-table">
  <tr>
    <td style="width:33%;">
      <label>ARPL candidate signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="candidate-sig8-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig8-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="candidate-sig8-<?= $lid ?>" id="candidate-sig8-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:33%;">
      <label>Signed at:</label>
      <div class="sig-line"><input type="text" placeholder="Place"></div>
    </td>
    <td style="width:33%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
  </tr>
</table>
<table class="sig-table">
  <tr>
    <td style="width:33%;">
      <label>Assessor signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="assessor-sig7-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig7-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="assessor-sig7-<?= $lid ?>" id="assessor-sig7-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:33%;">
      <label>Signed at:</label>
      <div class="sig-line"><input type="text" placeholder="Place"></div>
    </td>
    <td style="width:33%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
  </tr>
</table>
<table class="ft" style="margin-top:12px;">
  <tr><td><b>Assessor findings:</b><br><textarea rows="4" placeholder="Assessor's findings regarding the appeal..."></textarea></td></tr>
</table>
<table class="sig-table">
  <tr>
    <td style="width:33%;">
      <label>Assessor Signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="assessor-sig8-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig8-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="assessor-sig8-<?= $lid ?>" id="assessor-sig8-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:33%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
    <td style="width:33%;"></td>
  </tr>
</table>
<div class="note" style="margin-top:12px;"><b>NOTE:</b> ARPL candidate must state the reason for the appeal and forward to the moderator. The moderator must call a meeting within 1 week of receiving the appeal.</div>
</div>


<!-- ═══════════════════════════════════════════
     APPENDIX H – ACCESS RECOMMENDATION
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>25 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">11. Appendix H: ACCESS RECOMMENDATION
  <span style="font-size:10pt;font-weight:normal;">(<?= htmlspecialchars($fullname) ?>)</span>
</div>

<table class="ft">
  <tr><td style="width:38%;"><b>Name of the Candidate</b></td><td><span class="prefilled"><?= htmlspecialchars($fullname) ?></span></td></tr>
  <tr><td><b>Company</b></td><td><input type="text" placeholder="Employer / Company"></td></tr>
  <tr><td><b>Experience</b></td><td><input type="text" placeholder="Years and type of experience"></td></tr>
  <tr><td><b>Date of Birth</b></td>
      <td><span class="prefilled"><?= htmlspecialchars($l['DateOfBirth'] ?? '') ?></span></td></tr>
</table>

<table class="ft" style="margin-top:10px;">
  <tr>
    <th style="width:36px;">No</th>
    <th>Results</th>
    <th style="width:120px;"></th>
    <th class="l">Remarks</th>
  </tr>
  <?php
  $assessComponents = [1=>'Knowledge assessment',2=>'Practical assessment',3=>'Workplace Observation'];
  $radNames = ['ka_'.$lid,'pa_'.$lid,'wo_'.$lid];
  foreach ($assessComponents as $ci => $clabel): ?>
  <tr>
    <td class="c"><?=$ci?></td>
    <td><b><?= $clabel ?></b></td>
    <td class="c">
      Ready <input type="radio" name="<?=$radNames[$ci-1]?>" value="ready"><br>
      Not Yet Ready <input type="radio" name="<?=$radNames[$ci-1]?>" value="nyr">
    </td>
    <td><input type="text" placeholder="Remarks"></td>
  </tr>
  <?php endforeach; ?>
  <tr>
    <td class="c">4</td>
    <td colspan="3">
      <b>Overall Result</b><br><br>
      <label><input type="radio" name="overall_<?=$lid?>" value="trade_test">&nbsp; Recommended for trade test</label><br><br>
      <label><input type="radio" name="overall_<?=$lid?>" value="gap_closure">&nbsp; Recommended for gap closure</label>
    </td>
  </tr>
</table>

<table class="sig-table">
  <tr>
    <td style="width:40%;">
      <label>Signature of ARPL Candidate:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="candidate-sig4-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig4-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="candidate-sig4-<?= $lid ?>" id="candidate-sig4-<?= $lid ?>-data">
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
        <canvas class="sig-pad-canvas" data-sig-id="assessor-sig3-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig3-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="assessor-sig3-<?= $lid ?>" id="assessor-sig3-<?= $lid ?>-data">
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


<!-- ═══════════════════════════════════════════
     APPENDIX I – STATEMENT OF RESULTS
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>26 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">12. Appendix I: Statement of Results: NAMB
  <span style="font-size:10pt;font-weight:normal;">(<?= htmlspecialchars($fullname) ?>)</span>
</div>
<div class="note"><b>NOTE:</b> This Statement of Results is not an Occupational Certificate but indicates that the learner/candidate has complied with the requirements of the knowledge, practical skills and workplace components of the Occupational (Trade) qualification.</div>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Provider type</p>
<table class="ft">
  <tr>
    <td>Assessment Centre &nbsp;<input type="checkbox" name="ptype_ac_<?=$lid?>" value="ac"></td>
    <td>Skills Development Provider (SDP) &nbsp;<input type="checkbox" name="ptype_sdp_<?=$lid?>" value="sdp" <?= !empty($ctx['provider_name']) ? 'checked' : '' ?>></td>
  </tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Provider Details</p>
<table class="ft">
  <tr><td style="width:38%;"><b>Provider Name</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></span></td></tr>
  <tr><td><b>Provider Accreditation No</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></span></td></tr>
  <tr><td><b>Physical Address</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['provider_address'] ?? '') ?></span></td></tr>
  <tr><td><b>Postal address</b></td><td><input type="text" placeholder="Postal address"></td></tr>
  <tr><td><b>Tel no</b></td><td><input type="tel" placeholder="Provider telephone"></td></tr>
  <tr><td><b>Fax no</b></td><td><input type="tel" placeholder="Provider fax"></td></tr>
  <tr><td><b>Contact person</b></td><td><input type="text" placeholder="Contact person name"></td></tr>
  <tr><td><b>Position</b></td><td><input type="text" placeholder="Position / Title"></td></tr>
  <tr><td><b>Cellphone no</b></td><td><input type="tel" placeholder="Cell number"></td></tr>
  <tr><td><b>E-mail address</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['provider_email'] ?? '') ?></span></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Candidate detail</p>
<table class="ft">
  <tr>
    <td style="width:38%;"><b>Type</b></td>
    <td>Learner <input type="checkbox" name="ctype_learner_<?=$lid?>" value="learner" checked>
        &nbsp;&nbsp; ARPL Process <input type="checkbox" name="ctype_arpl_<?=$lid?>" value="arpl" checked></td>
  </tr>
  <tr><td><b>Full Names</b></td><td><span class="prefilled"><?= htmlspecialchars($l['Name']) ?></span></td></tr>
  <tr><td><b>Surname</b></td><td><span class="prefilled"><?= htmlspecialchars($l['Surname']) ?></span></td></tr>
  <tr><td><b>ID Number</b></td><td><span class="prefilled"><?= htmlspecialchars($l['IDNumber']) ?></span></td></tr>
  <tr><td><b>Address</b></td><td><span class="prefilled"><?= htmlspecialchars($l['AddressLine1'].' '.$l['AddressLine2']) ?></span></td></tr>
  <tr><td><b>Tel/Cell No</b></td><td><span class="prefilled"><?= htmlspecialchars($l['PhoneNumber'] ?? '') ?></span></td></tr>
  <tr><td><b>E-mail address</b></td><td><span class="prefilled"><?= htmlspecialchars($l['Email'] ?? '') ?></span></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Trade information</p>
<table class="ft">
  <tr>
    <th class="l">Qualification Title</th>
    <th>OFO Code</th>
    <th>SAQA Qualification ID</th>
    <th>NQF Level + Credits</th>
  </tr>
  <tr>
    <td><?= htmlspecialchars($qual_name) ?></td>
    <td class="c">642601</td>
    <td class="c"><span class="prefilled"><?= htmlspecialchars($qualification_id) ?></span></td>
    <td class="c">NQF 4</td>
  </tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:12px 0 5px;">Eligibility Requirements for External Integrated Summative Assessment (Trade Test)</p>

<p style="font-size:10pt;font-weight:bold;margin:8px 0 4px;">Knowledge Modules</p>
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
    <td><input type="text" name="km_num_<?=$i?>" placeholder="e.g. 1"></td>
    <td><input type="text" name="km_title_<?=$i?>" placeholder="Module title"></td>
    <td><input type="text" name="km_evidence_<?=$i?>" placeholder="Evidence type"></td>
    <td><input type="text" name="km_reference_<?=$i?>" placeholder="Ref no"></td>
    <td>
      <select name="km_achieved_<?=$i?>">
        <option value="">--</option>
        <option value="Yes">Yes</option>
        <option value="No">No</option>
      </select>
    </td>
    <td><input type="date" name="km_date_<?=$i?>"></td>
  </tr>
  <?php endfor; ?>
</table>

<p style="font-size:10pt;font-weight:bold;margin:10px 0 4px;">Practical Skill Modules</p>
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
    <td><input type="text" name="psm_num_<?=$i?>" placeholder="e.g. 1"></td>
    <td><input type="text" name="psm_title_<?=$i?>" placeholder="Module title"></td>
    <td><input type="text" name="psm_evidence_<?=$i?>" placeholder="Evidence type"></td>
    <td><input type="text" name="psm_reference_<?=$i?>" placeholder="Ref no"></td>
    <td>
      <select name="psm_achieved_<?=$i?>">
        <option value="">--</option>
        <option value="Yes">Yes</option>
        <option value="No">No</option>
      </select>
    </td>
    <td><input type="date" name="psm_date_<?=$i?>"></td>
  </tr>
  <?php endfor; ?>
</table>

<p style="font-size:10pt;font-weight:bold;margin:10px 0 4px;">Work Place Experience (interview)</p>
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
    <td><input type="text" name="wpe_num_<?=$i?>" placeholder="e.g. 1"></td>
    <td><input type="text" name="wpe_title_<?=$i?>" placeholder="Activity title"></td>
    <td><input type="text" name="wpe_evidence_<?=$i?>" placeholder="Evidence type"></td>
    <td><input type="text" name="wpe_reference_<?=$i?>" placeholder="Ref no"></td>
    <td>
      <select name="wpe_achieved_<?=$i?>">
        <option value="">--</option>
        <option value="Yes">Yes</option>
        <option value="No">No</option>
      </select>
    </td>
    <td><input type="date" name="wpe_date_<?=$i?>"></td>
  </tr>
  <?php endfor; ?>
</table>
</table>

<!-- Signatures -->
<table class="sig-table">
  <tr>
    <td style="width:40%;">
      <label>Candidate Signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="candidate-sig5-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig5-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="candidate-sig5-<?= $lid ?>" id="candidate-sig5-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:30%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
    <td style="width:30%;"></td>
  </tr>
</table>
<div class="sig-row" style="margin-top:10px;">
  <div class="sig-blk"><label>SDP/AC Assessor – Name:</label><div class="sig-line"><span class="prefilled"><?= htmlspecialchars(($facilitator['firstName'] ?? '').' '.($facilitator['lastName'] ?? '')) ?></span></div></div>
  <div class="sig-blk"><label>Position:</label><div class="sig-line"><input type="text" placeholder="Position / Title"></div></div>
</div>
<table class="sig-table">
  <tr>
    <td style="width:40%;">
      <label>Assessor Signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="assessor-sig4-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig4-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="assessor-sig4-<?= $lid ?>" id="assessor-sig4-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:30%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
    <td style="width:30%;"></td>
  </tr>
</table>
<div class="sig-row" style="margin-top:8px;">
  <div class="sig-blk"><label>SDP/AC Manager – Name:</label><div class="sig-line"><input type="text" placeholder="Manager name"></div></div>
  <div class="sig-blk"><label>Position:</label><div class="sig-line"><input type="text" placeholder="Position"></div></div>
</div>
<table class="sig-table">
  <tr>
    <td style="width:40%;">
      <label>Manager Signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="manager-sig-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('manager-sig-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="manager-sig-<?= $lid ?>" id="manager-sig-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:30%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
    <td style="width:30%;"></td>
  </tr>
</table>
<div class="sig-row" style="margin-top:8px;">
  <div class="sig-blk"><label>NAMB Verifier – Name:</label><div class="sig-line"><input type="text" placeholder="Verifier name"></div></div>
  <div class="sig-blk"><label>Position:</label><div class="sig-line"><input type="text" placeholder="Position"></div></div>
</div>
<table class="sig-table">
  <tr>
    <td style="width:40%;">
      <label>Verifier Signature:</label>
      <div class="sig-pad-wrapper">
        <canvas class="sig-pad-canvas" data-sig-id="verifier-sig-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('verifier-sig-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="verifier-sig-<?= $lid ?>" id="verifier-sig-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:30%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
    <td style="width:30%;"></td>
  </tr>
</table>
<div style="margin-top:12px;">
  <label style="font-size:11pt;font-weight:bold;">Trade Test Serial Number:</label>
  <div style="border-bottom:1px solid #000;margin-top:4px;">
    <input type="text" placeholder="e.g. TT-<?= date('Y') ?>-PL-<?= str_pad($lid,5,'0',STR_PAD_LEFT) ?>" style="font-size:11pt;border:none;width:100%;padding:3px 4px;">
  </div>
</div>
</div><!-- end pb -->


<!-- ═══════════════════════════════════════════
     APPENDIX J – PRE-ASSESSMENT AGREEMENT
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>30 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">13. Appendix J: Candidate Pre-Assessment Agreement
  <span style="font-size:10pt;font-weight:normal;">(<?= htmlspecialchars($fullname) ?>)</span>
</div>

<table class="ft">
  <tr><td style="width:42%;"><b>Full Name of the Candidate</b></td><td><span class="prefilled"><?= htmlspecialchars($fullname) ?></span></td></tr>
  <tr><td><b>Candidates ID Number</b></td><td><span class="prefilled"><?= htmlspecialchars($l['IDNumber']) ?></span></td></tr>
  <tr><td><b>Trade</b></td><td><?= htmlspecialchars($qual_name) ?></td></tr>
  <tr><td><b>Date of Agreement</b></td><td><input type="date" value="<?= date('Y-m-d') ?>"></td></tr>
</table>

<p style="font-size:11pt;font-weight:bold;margin:12px 0 6px;">Type of Assessment:</p>
<table class="ft">
  <tr>
    <td>Theory Test &nbsp;<input type="checkbox" name="ta_th_<?=$lid?>"></td>
    <td>Practical Assessment &nbsp;<input type="checkbox" name="ta_pr_<?=$lid?>"></td>
    <td>Workplace Experience Evaluation &nbsp;<input type="checkbox" name="ta_wp_<?=$lid?>"></td>
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
        <canvas class="sig-pad-canvas" data-sig-id="candidate-sig6-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig6-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="candidate-sig6-<?= $lid ?>" id="candidate-sig6-<?= $lid ?>-data">
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
        <canvas class="sig-pad-canvas" data-sig-id="assessor-sig5-<?= $lid ?>" width="300" height="80"></canvas>
        <div class="sig-pad-buttons">
          <button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig5-<?= $lid ?>')">Clear</button>
        </div>
        <input type="hidden" name="assessor-sig5-<?= $lid ?>" id="assessor-sig5-<?= $lid ?>-data">
      </div>
    </td>
    <td style="width:30%;">
      <label>Date:</label>
      <div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div>
    </td>
    <td style="width:30%;"></td>
  </tr>
</table>

<?php if ($idx < count($learners)-1): ?>
<?php endif; ?>

</div><!-- end pb (Appendix J) -->

<?php endforeach; // end learner block ?>

<!-- ─── BOTTOM PRINT BUTTON ─── -->
<div class="bottom-print-button" style="text-align:right;margin:20px 0 10px;">
  <button onclick="window.print()" style="padding:10px 28px;background:#1a237e;color:#fff;border:none;border-radius:4px;font-size:12pt;font-weight:700;cursor:pointer;">🖨 Print / Download PDF</button>
</div>

</div><!-- /.page -->

<script>
// Toggle postal address same as physical
function toggleSameAddress() {
    const checkbox = document.getElementById('same-address');
    const physical1 = document.getElementById('physical-addr-1');
    const physical2 = document.getElementById('physical-addr-2');
    const physical3 = document.getElementById('physical-addr-3');
    const postal1 = document.getElementById('postal-addr-1');
    const postal2 = document.getElementById('postal-addr-2');
    const postal3 = document.getElementById('postal-addr-3');
    
    if (checkbox.checked) {
        postal1.value = physical1.textContent;
        postal2.value = physical2.textContent;
        postal3.value = physical3.textContent;
        postal1.disabled = true;
        postal2.disabled = true;
        postal3.disabled = true;
    } else {
        postal1.value = '';
        postal2.value = '';
        postal3.value = '';
        postal1.disabled = false;
        postal2.disabled = false;
        postal3.disabled = false;
    }
}

(function() {
    // ARPL Toolkit save/load functions
    const learnerID = <?php echo $learnerID; ?>;
    const classID = <?php echo $classID; ?>;
    const projectID = <?php echo $project_id ?? 'null'; ?>;
    const siteID = <?php echo $siteID ?? 'null'; ?>;

    const savedData = <?php echo $arpl_data ? json_encode($arpl_data) : 'null'; ?>;
    
    // Store all signature pads
    const signaturePads = {};
    
    // Initialize all signature pads
    function initSignaturePads() {
        document.querySelectorAll('.sig-pad-canvas').forEach(canvas => {
            const sigId = canvas.getAttribute('data-sig-id');
            
            // Set canvas dimensions based on container
            const rect = canvas.getBoundingClientRect();
            const dpr = window.devicePixelRatio || 1;
            canvas.width = rect.width * dpr;
            canvas.height = 80 * dpr;
            const ctx = canvas.getContext('2d');
            ctx.scale(dpr, dpr);
            
            const signaturePad = new SignaturePad(canvas, {
                backgroundColor: 'rgb(255, 255, 255)'
            });
            
            // Store the signature pad
            signaturePads[sigId] = signaturePad;
        });
        
        // Load saved signatures after all pads are initialized
        if (savedData) {
            Object.keys(signaturePads).forEach(sigId => {
                if (savedData[sigId]) {
                    try {
                        signaturePads[sigId].fromDataURL(savedData[sigId]);
                    } catch (error) {
                        console.warn('Failed to load signature for', sigId, error);
                    }
                }
            });
        }
    }
    
    // Clear a signature pad
    window.clearSignature = function(sigId) {
        if (signaturePads[sigId]) {
            signaturePads[sigId].clear();
        }
    };

    // Collect all form data
    function collectFormData() {
        const data = {};
        
        // Get all inputs
        document.querySelectorAll('input, select, textarea').forEach(el => {
            const name = el.name || el.id;
            if (!name) return;
            
            if (el.type === 'radio' || el.type === 'checkbox') {
                if (el.checked) {
                    // Handle candidate detail type checkboxes specially
                    if (name.startsWith('ctype_')) {
                        if (!data['candidate_detail_types']) {
                            data['candidate_detail_types'] = [];
                        }
                        data['candidate_detail_types'].push(el.value);
                    } else {
                        data[name] = el.value;
                    }
                }
            } else {
                data[name] = el.value;
            }
        });
        
        // Collect signature data
        Object.keys(signaturePads).forEach(sigId => {
            const signaturePad = signaturePads[sigId];
            if (signaturePad && !signaturePad.isEmpty()) {
                data[sigId] = signaturePad.toDataURL();
            }
        });
        
        return data;
    }

    // Pre-fill form with saved data
    function loadFormData() {
        if (!savedData) return;
        
        Object.keys(savedData).forEach(name => {
            const value = savedData[name];
            
            // Handle candidate detail types specially
            if (name === 'candidate_detail_types' && Array.isArray(value)) {
                value.forEach(type => {
                    const checkbox = document.querySelector(`input[name^="ctype_"][value="${type}"]`);
                    if (checkbox) {
                        checkbox.checked = true;
                    }
                });
                return;
            }
            
            const elements = document.getElementsByName(name);
            
            if (elements.length > 0) {
                elements.forEach(el => {
                    if (el.type === 'radio' || el.type === 'checkbox') {
                        if (el.value === value || (el.type === 'checkbox' && value === 'on')) {
                            el.checked = true;
                        }
                    } else {
                        el.value = value;
                    }
                });
            } else {
                const elById = document.getElementById(name);
                if (elById) {
                    elById.value = value;
                }
            }
        });
        
        // If "same address" was checked, apply it
        const sameAddressCheckbox = document.getElementById('same-address');
        if (sameAddressCheckbox && sameAddressCheckbox.checked) {
            toggleSameAddress();
        }
    }

    // Save data to backend
    window.saveArplData = async function() {
        const formData = collectFormData();
        
        try {
            const response = await fetch('save_arpl_toolkit2.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    learner_id: learnerID,
                    class_id: classID,
                    project_id: projectID,
                    site_id: siteID,
                    form_data: formData
                })
            });
            
            const result = await response.json();
            
            if (result.success) {
                alert('Data saved successfully!');
            } else {
                alert('Error saving data: ' + result.message);
            }
        } catch (error) {
            alert('Error saving data: ' + error.message);
        }
    };

    // Load data when page loads
    document.addEventListener('DOMContentLoaded', () => {
        initSignaturePads();
        // Use setTimeout to ensure canvas dimensions are properly calculated
        setTimeout(() => {
            loadFormData();
        }, 100);
    });
})();
</script>

</body>
</html>
