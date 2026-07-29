<?php
// ============================================================
// ARPL TOOLKIT PDF GENERATOR - EXACT MOBILE APP FORMAT
// Generates professional ARPL portfolio PDF for all trades
// Trades: Electrician (671101), Bricklaying (641201), Plumbing (642601)
// ============================================================

session_start();
include __DIR__ . '/../../../connection.php';
date_default_timezone_set('Africa/Johannesburg');

// ── Auth ─────────────────────────────────────────────────────
$is_sdp         = isset($_SESSION['sdp_id']);
$is_facilitator = isset($_SESSION['facilitator_id']);
if (!$is_sdp && !$is_facilitator) {
    header("Location: index.php");
    exit;
}

// ── Resolve classID & learnerID from GET or session ──────────
// Support both lowercase and capitalized parameter names
$classID   = isset($_GET['classID']) ? (int)$_GET['classID'] : 
             (isset($_GET['ClassID']) ? (int)$_GET['ClassID'] : (int)($_SESSION['classID'] ?? 0));
$learnerID = isset($_GET['learnerID']) ? (int)$_GET['learnerID'] : 
             (isset($_GET['LearnerID']) ? (int)$_GET['LearnerID'] : 0);

if (!$classID || !$learnerID) {
    echo "<script>alert('Missing class or learner. Please try again.'); window.history.back();</script>";
    exit;
}

// ── FACILITATOR DATA ──────────────────────────────────────────
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

// Fallback
if (empty($facilitator['firstName'])) {
    $st = $conn->prepare("SELECT * FROM facilitator WHERE FIND_IN_SET(?, classID) > 0 LIMIT 1");
    $st->bind_param("i", $classID);
    $st->execute();
    $frow = $st->get_result()->fetch_assoc();
    $st->close();
    if ($frow) { $facilitator = $frow; }
}

// ── CLASS + SITE + PROJECT + SDP ──────────────────────────────
$sql = "SELECT c.*, s.siteID, s.siteName, s.Province, s.District, s.Municipality,
               s.cell_phone, s.email, s.project_id, s.sdp_id, s.qualification_id,
               p.Project_name, p.Contract_no, p.Financial_year, p.Start_date, p.End_date,
               sdp.sdp_name, sdp.accreditation_n, sdp.p_address, sdp.email
        FROM class c
        JOIN sites s ON c.siteID = s.siteID
        JOIN project p ON s.project_id = p.project_id
        JOIN sdp ON s.sdp_id = sdp.sdp_id
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

// ── LEARNER ───────────────────────────────────────────────────
$st = $conn->prepare("SELECT * FROM learnerdetails WHERE LearnerID = ? AND classID = ?");
$st->bind_param("ii", $learnerID, $classID);
$st->execute();
$learner = $st->get_result()->fetch_assoc();
$st->close();

if (!$learner) {
    echo "<script>alert('Learner not found in this class.'); window.history.back();</script>";
    exit;
}

// ── QUALIFICATION (OFO) ───────────────────────────────────────
$ofoNumber = isset($_GET['ofoNumber']) ? trim($_GET['ofoNumber']) : ($ctx['qualification_id'] ?? '642601');

$tradeConfig = [
    '671101' => ['name' => 'Electrician',  'table_suffix' => 'electrician'],
    '641201' => ['name' => 'Bricklaying',  'table_suffix' => 'bricklaying'],
    '642601' => ['name' => 'Plumbing',     'table_suffix' => 'plumbing'],
];

if (!isset($tradeConfig[$ofoNumber])) {
    $ofoNumber = '642601';
}

$tradeName = $tradeConfig[$ofoNumber]['name'];
$tableSuffix = $tradeConfig[$ofoNumber]['table_suffix'];

$today = date('d F Y');
$fullname = trim($learner['Name'].' '.$learner['Surname']);
$refno = 'ARPL-'.date('Y').'-'.substr($tradeName, 0, 2).'-'.str_pad($learnerID,4,'0',STR_PAD_LEFT);

?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>ARPL Toolkit – <?= htmlspecialchars($fullname) ?> – <?= htmlspecialchars($tradeName) ?></title>
<script src="https://cdn.jsdelivr.net/npm/signature_pad@4.1.7/dist/signature_pad.umd.min.js"></script>
<style>
/* ── Reset ── */
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:"Times New Roman",Times,serif;font-size:12pt;color:#000;background:#ccc;}
.page{max-width:820px;margin:16px auto;background:#fff;padding:50px 58px;box-shadow:0 3px 20px rgba(0,0,0,.25);}

/* ── Toolbar ── */
.toolbar{display:flex;justify-content:flex-end;gap:10px;margin-bottom:20px;}
.toolbar button{padding:8px 22px;border:none;border-radius:4px;cursor:pointer;font-size:11pt;font-weight:700;background:#006341;color:#fff;}
.toolbar button:hover{opacity:.88;}
.toolbar button.sec{background:#fff;color:#006341;border:2px solid #006341;}

/* ── Signature Pad ── */
.sig-pad-wrapper{display:flex;flex-direction:column;gap:8px;}
.sig-pad-canvas{border:1px dashed #999;border-radius:4px;background:#fff;touch-action:none;width:100%;height:80px;}
.sig-pad-buttons{display:flex;gap:8px;}
.sig-pad-btn{padding:4px 12px;border:1px solid #006341;background:#fff;color:#006341;border-radius:4px;cursor:pointer;font-size:10pt;}
.sig-pad-btn:hover{background:#006341;color:#fff;}

/* ── Cover Page ── */
.cover-page{position:relative;min-height:94vh;display:flex;flex-direction:column;align-items:center;justify-content:flex-start;text-align:center;padding:10px 0 30px;overflow:hidden;page-break-after:always;}
.wm{position:absolute;top:50%; left:50%;transform:translate(-50%,-50%) rotate(-38deg);font-size:54pt;font-weight:bold;color:rgba(0,0,0,0.055);white-space:nowrap;pointer-events:none;z-index:0;letter-spacing:3px;font-family:Arial,sans-serif;user-select:none;}
.cover-page > * { position:relative; z-index:1; }
.cover-logo-row{display:flex;align-items:center;justify-content:center;gap:14px;margin-bottom:60px;}
.dhet-coa{width:88px;height:auto;flex-shrink:0;}
.dhet-text{text-align:center;font-family:Arial,Helvetica,sans-serif;line-height:1.2;}
.dhet-text .t1{font-size:20pt;font-weight:bold;color:#000;line-height:1.05;}
.dhet-text .t2{font-size:20pt;font-weight:bold;color:#000;margin-bottom:5px;}
.dhet-text hr{border:none;border-top:1.5px solid #000;margin:4px 0 5px;}
.dhet-text .t3{font-size:9pt;color:#333;}
.dhet-text .t4{font-size:9.5pt;color:#333;}
.dhet-text .t5{font-size:9.5pt;font-weight:bold;color:#000;text-transform:uppercase;letter-spacing:.4px;}
.cover-title-block{width:100%;text-align:center;margin-top:10px;}
.cover-title-block .ct{font-family:"Times New Roman",Times,serif;font-weight:bold;color:#000;display:block;}
.ct-arpl  { font-size:16pt; margin-bottom:4px; }
.ct-bracket{ font-size:16pt; margin-bottom:32px; }
.ct-toolkit{ font-size:14pt; margin-bottom:32px; }
.ct-ofo   { font-size:13pt; margin-bottom:32px; }
.ct-label { font-size:12pt; margin-bottom:2px; }
.ct-value { font-size:12pt; margin-bottom:28px; }

/* ── Document Header Table (dht) ── */
.dht{width:100%;border-collapse:collapse;margin-bottom:12px;font-size:10pt;}
.dht td{border:1px solid #000;padding:4px 7px;}

/* ── Titles ── */
.doc-title{text-align:center;font-size:15pt;font-weight:bold;margin:8px 0 3px;}
.doc-sub{text-align:center;font-size:12pt;font-weight:bold;margin-bottom:5px;}
.sec-title{font-size:13pt;font-weight:bold;margin:18px 0 7px;}
.sec-sub{font-size:12pt;font-weight:bold;margin:12px 0 5px;}

/* ── Form Table (ft) ── */
table.ft{width:100%;border-collapse:collapse;margin-bottom:10px;font-size:12pt;}
table.ft th{background:#000;color:#fff;padding:10px 12px;border:1px solid #000;text-align:center;}
table.ft th.l{text-align:left;}
table.ft td{border:1px solid #000;padding:10px 12px;vertical-align:middle;}
table.ft td.c{text-align:center;}
table.ft tr:nth-child(even) td{background:#f8f8f8;}

/* ── Inputs ── */
input[type=text],input[type=email],input[type=tel],input[type=date],textarea,select{width:100%;border:none;border-bottom:1px solid #666;font-family:inherit;font-size:12pt;padding:4px 6px;background:transparent;color:#000;outline:none;}
textarea{resize:vertical;min-height:50px;border:1px solid #888;padding:6px;}
select{border:none;border-bottom:1px solid #666;background:transparent;}
input:focus,textarea:focus,select:focus{background:#fffde7;border-color:#006341;}
td input,td select{border:none;border-bottom:1px dashed #999;width:100%;}
td input:focus,td select:focus{background:#fffde7;}
.prefilled{font-style:italic;color:#006341;}

/* ── Radio / Checkbox ── */
.rc{text-align:center;}
.rc input[type=radio],.rc input[type=checkbox]{width:16px;height:16px;cursor:pointer;accent-color:#006341;}

/* ── Score scale ── */
.scn{font-size:13pt;font-weight:bold;text-align:center;}

/* ── Signature row ── */
.sig-row{display:flex;gap:22px;margin-top:10px;align-items:flex-end;}
.sig-table{width:100%;border-collapse:collapse;margin-top:10px;}
.sig-table td{border:none;padding:4px 0;vertical-align:bottom;}
.sig-blk{flex:1;}
.sig-blk label{font-size:10pt;font-weight:bold;display:block;margin-bottom:3px;}
.sig-line{border-bottom:1px solid #000;min-height:28px;padding:2px 4px;}
.sig-line input{border:none;background:transparent;width:100%;font-size:11pt;}

/* ── Note box ── */
.note{border:1px solid #000;padding:8px 12px;margin:8px 0;font-size:11pt;font-style:italic;}

/* ── Page breaks ── */
.pb{page-break-before:always;margin-top:28px;padding-top:18px;border-top:1px dashed #ccc;}

@media print{
@page {size: A4; margin: 15mm;}
body{background:#fff; -webkit-print-color-adjust: exact; print-color-adjust: exact;}
.page{box-shadow:none;padding:0;margin:0;max-width:100%;width:100%;}
.toolbar{display:none !important;}
.sig-pad-buttons{display:none !important;}
.cover-page{min-height:0;page-break-after:always;}
.pb{page-break-before:always;}
table, tr, td, th {page-break-inside: avoid;}
}
</style>
</head>
<body>
<div class="page">

<!-- TOOLBAR -->
<div class="toolbar">
<button class="sec" onclick="window.history.back()">← Back</button>
<button onclick="window.print()">🖨 Print / Save as PDF</button>
</div>

<!-- COVER PAGE -->
<div class="cover-page">
<div class="wm"><?= htmlspecialchars($ctx['sdp_name'] ?? 'Training Provider') ?></div>
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

<!-- CONTENTS PAGE -->
<div class="pb">
<table class="dht">
<tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? 'AC000153NAMB') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>2 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>
<div class="doc-title"><?= strtoupper(htmlspecialchars($tradeName)) ?> ARPL TOOLKIT</div>
<div class="doc-sub">ARTISAN RECOGNITION OF PRIOR LEARNING (ARPL)</div>
<div class="sec-title">CONTENTS</div>
<table class="ft"><tr><th class="l" style="width:70%;">INDEX</th><th>Page</th></tr>
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
</div>

<!-- APPENDIX A: APPLICATION FORM -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>3 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">1. Appendix A: Application Form</div>
<table class="ft" style="margin-bottom:8px;"><tr><td style="width:38%;"><b>Ref Number:</b></td><td><span class="prefilled"><?= $refno ?></span></td></tr></table>
<div class="sec-sub">APPLICATION FOR RECOGNITION OF PRIOR LEARNING IN A LISTED TRADE</div>
<table class="ft"><tr><td style="width:38%;"><b>Trade Title</b></td><td><?= htmlspecialchars($tradeName) ?></td></tr>
<tr><td><b>OFO Code</b></td><td><?= $ofoNumber ?></td></tr>
<tr><td><b>Specialization</b></td><td><input type="text" placeholder="e.g. None"></td></tr>
<tr><td><b>Candidate Name</b></td><td><span class="prefilled"><?= htmlspecialchars($fullname) ?></span></td></tr></table>
<table class="ft"><tr><th class="l" style="width:50%;">Physical Address</th><th class="l">Postal Address</th></tr>
<tr><td><span class="prefilled"><?= htmlspecialchars($learner['AddressLine1'] ?? '') ?></span></td><td><input type="text"></td></tr>
<tr><td><span class="prefilled"><?= htmlspecialchars(($learner['AddressLine2'] ?? '').' '.($learner['PostalCode'] ?? '')) ?></span></td><td><input type="text"></td></tr></table>
<table class="ft"><tr><td style="width:38%;"><b>Tel no</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['PhoneNumber'] ?? '') ?></span></td></tr>
<tr><td><b>Cell no</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['PhoneNumber'] ?? '') ?></span></td></tr>
<tr><td><b>E-mail</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['Email'] ?? '') ?></span></td></tr></table>
<table class="ft"><tr><th class="l">Company</th><th class="l">Position/Job Title</th><th class="l">Period &amp; Duration</th><th class="l">Contact</th></tr>
<tr><td><input type="text" placeholder="Company"></td><td><input type="text" placeholder="Title"></td><td><input type="text" placeholder="2018–2022"></td><td><input type="tel" placeholder="Tel"></td></tr>
<tr><td><input type="text" placeholder="Company"></td><td><input type="text" placeholder="Title"></td><td><input type="text" placeholder="2013–2017"></td><td><input type="tel" placeholder="Tel"></td></tr>
<tr><td><input type="text" placeholder="Company"></td><td><input type="text" placeholder="Title"></td><td><input type="text" placeholder="2008–2012"></td><td><input type="tel" placeholder="Tel"></td></tr></table>
<table class="sig-table"><tr><td style="width:40%;"><label>Candidate Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="candidate-sig-1-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig-1-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
</div>

<!-- COMPETENCY SCALE -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>5 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">Competency Proficiency Scale</div>
<table class="ft"><tr><th colspan="3">COMPETENCY PROFICIENCY SCALE FOR SELF-EVALUATION</th></tr>
<tr><th style="width:55px;">Score</th><th>Proficiency Level</th><th class="l">Description</th></tr>
<tr><td class="scn">1</td><td><b>Fundamental</b></td><td>Can perform under direct supervision; needs assistance in most aspects</td></tr>
<tr><td class="scn">2</td><td><b>Novice</b></td><td>Can perform most tasks with minimal supervision; developing competency</td></tr>
<tr><td class="scn">3</td><td><b>Intermediate</b></td><td>Can perform independently with occasional guidance; competent</td></tr>
<tr><td class="scn">4</td><td><b>Advanced</b></td><td>Can perform consistently and independently; can guide others</td></tr>
<tr><td class="scn">5</td><td><b>Expert</b></td><td>Mastery level; can train others; innovates and improves processes</td></tr>
</table>
</div>

<!-- APPENDIX B: SELF-EVALUATION CHECKLIST -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>6 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">2. Appendix B: SELF-EVALUATION/INTERVIEW CHECKLIST</div>

<?php
// Trade-specific activities
$activities = [
    '671101' => [ // Electrician
        'Safety', 'Hand and power tools', 'Measuring equipment', 'Plans and drawings',
        'Identification of cables and conductors', 'Conduit and ducting', 'Cable management',
        'Distribution boards and panels', 'Wiring systems', 'Lighting circuits', 'Power circuits',
        'Protection devices', 'Testing and commissioning', 'Health and safety regulations',
        'Environmental awareness', 'Renewable energy systems', 'Smart metering', 'Fire safety',
        'Earthing and bonding', 'Cable sizing'
    ],
    '641201' => [ // Bricklaying
        'Safety', 'Tools and equipment', 'Measuring equipment', 'Plans and drawings',
        'Brick identification', 'Mortar preparation', 'Material handling', 'Cavity walls',
        'Solid walls', 'Arches and openings', 'Pointing and finishes', 'Bonding patterns',
        'Structural components', 'Health and safety', 'Environmental awareness',
        'Quality control', 'Workplace procedures', 'Site management', 'Building regulations',
        'Damp proof courses'
    ],
    '642601' => [ // Plumbing
        'Safety', 'Hand and workshop tools', 'Measuring equipment', 'Plans and drawings',
        'Identification of pipe and fittings', 'Transportation and handling', 'Access equipment',
        'Hot water systems', 'Cold water systems', 'Rain water systems', 'Above ground drainage',
        'Below ground drainage', 'SANS codes and regulations', 'Sanitary ware', 'Trenching',
        'Basic building works', 'Valves and fittings', 'Hydraulic loading', 'Meter installation',
        'Brazing and soldering', 'Jointing methods', 'Site assessment', 'Risk assessment',
        'Septic tanks', 'Sheet metal fabrication'
    ]
];

$acts = $activities[$ofoNumber] ?? $activities['642601'];
?>

<table class="ft"><tr><th style="width:34px;">No</th><th class="l">ACTIVITY – Trade Related Questions</th><th style="width:28px;">1</th><th style="width:28px;">2</th><th style="width:28px;">3</th><th style="width:28px;">4</th><th style="width:28px;">5</th><th class="l">ASSESSOR COMMENTS</th></tr>
<?php foreach ($acts as $num => $act): ?>
<tr><td class="c"><?= $num + 1 ?></td><td><?= htmlspecialchars($act) ?></td><?php for ($r=1;$r<=5;$r++): ?><td class="rc"><input type="radio" name="se_<?=$learnerID?>_<?=$num?>" value="<?=$r?>"></td><?php endfor; ?><td><input type="text" placeholder="Comment"></td></tr>
<?php endforeach; ?>
</table>

<table class="sig-table"><tr><td style="width:40%;"><label>Candidate Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="candidate-sig-b-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig-b-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>

<table class="sig-table"><tr><td style="width:40%;"><label>Assessor Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="assessor-sig-b-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig-b-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
</div>

<!-- APPENDIX C: CURRICULUM (Simplified - showing section) -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>9 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">3. Appendix C: TRADE CURRICULUM CONTENT SUMMARY</div>
<p style="font-size:11pt;margin:10px 0;"><b>Note:</b> Curriculum content is trade-specific and displayed for <?= htmlspecialchars($tradeName) ?> (OFO <?= $ofoNumber ?>). Detailed knowledge areas and competency requirements are included in full version.</p>
<div class="note">The complete curriculum for <?= htmlspecialchars($tradeName) ?> includes <?= count($activities[$ofoNumber] ?? []) ?> main activity areas covering safety, tools, practical skills, and workplace requirements.</div>
</div>

<!-- APPENDIX D: PRACTICAL SKILLS -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>12 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">4. Appendix D: PRACTICAL SKILLS ASSESSMENT EVALUATION CHECKLIST</div>
<p style="font-size:11pt;margin:8px 0;">Response: YES | NO | NOT APPLICABLE</p>

<?php
$practical = [
    '671101' => ['Safety', 'Hand and power tools', 'Measuring equipment', 'Plans and drawings', 'Cable identification', 'Conduit and ducting', 'Wiring systems', 'Distribution boards', 'Lighting circuits', 'Power circuits', 'Protection devices', 'Testing and commissioning', 'Earthing and bonding', 'Health and safety', 'Environmental awareness'],
    '641201' => ['Safety', 'Tools', 'Measuring equipment', 'Plans and drawings', 'Brick identification', 'Mortar preparation', 'Material handling', 'Cavity walls', 'Solid walls', 'Arches and openings', 'Pointing', 'Bonding patterns', 'Structural components', 'Health and safety', 'Environmental awareness'],
    '642601' => ['Safety', 'Hand and workshop tools', 'Measuring equipment', 'Plans and drawings', 'Pipe identification', 'Material handling', 'Access equipment', 'Hot water systems', 'Cold water systems', 'Drainage systems', 'Sanitary ware', 'Valves and fittings', 'System testing', 'Health and safety', 'Environmental awareness']
];

$prax = $practical[$ofoNumber] ?? $practical['642601'];
?>

<table class="ft"><tr><th class="l">Practical Criteria</th><th style="width:55px;">Yes</th><th style="width:55px;">No</th></tr>
<?php foreach ($prax as $idx => $crit): ?>
<tr><td><?= htmlspecialchars($crit) ?></td><td class="rc"><input type="radio" name="prac_<?=$learnerID?>_<?=$idx?>" value="yes"></td><td class="rc"><input type="radio" name="prac_<?=$learnerID?>_<?=$idx?>" value="no"></td></tr>
<?php endforeach; ?>
</table>

<table class="sig-table"><tr><td style="width:40%;"><label>Candidate Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="candidate-sig-d-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig-d-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
<table class="sig-table"><tr><td style="width:40%;"><label>Assessor Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="assessor-sig-d-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig-d-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
</div>

<!-- APPENDIX E: WORKPLACE EVALUATION -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>15 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">5. Appendix E: WORKPLACE EXPERIENCE EVALUATION</div>
<p style="font-size:11pt;margin:8px 0;">Competency Scale: 1=Fundamental | 2=Novice | 3=Intermediate | 4=Advanced | 5=Expert</p>

<table class="ft"><tr><th style="width:34px;">No</th><th class="l">Workplace Activity</th><th style="width:28px;">1</th><th style="width:28px;">2</th><th style="width:28px;">3</th><th style="width:28px;">4</th><th style="width:28px;">5</th><th class="l">Comments</th></tr>
<?php for ($w=1; $w<=5; $w++): ?>
<tr><td class="c"><?= $w ?></td><td><input type="text" placeholder="Activity"></td><?php for ($r=1;$r<=5;$r++): ?><td class="rc"><input type="radio" name="wp_<?=$learnerID?>_<?=$w?>" value="<?=$r?>"></td><?php endfor; ?><td><input type="text" placeholder="Comment"></td></tr>
<?php endfor; ?>
</table>

<table class="sig-table"><tr><td style="width:40%;"><label>Candidate Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="candidate-sig-e-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig-e-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
</div>

<!-- APPENDIX F: ASSESSMENT EVALUATION AGREEMENT -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>18 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">6. Appendix F: ASSESSMENT EVALUATION AGREEMENT</div>
<table class="ft"><tr><td style="width:35%;"><b>Candidate:</b></td><td><span class="prefilled"><?= htmlspecialchars($fullname) ?></span></td></tr>
<tr><td><b>Trade:</b></td><td><?= htmlspecialchars($tradeName) ?> (OFO <?= $ofoNumber ?>)</td></tr>
<tr><td><b>Assessor:</b></td><td><span class="prefilled"><?= htmlspecialchars(($facilitator['firstName'] ?? '').' '.($facilitator['lastName'] ?? '')) ?></span></td></tr>
<tr><td><b>Assessment Centre:</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></span></td></tr></table>
<p style="font-size:11pt;font-weight:bold;margin:10px 0;">Assessment Components:</p>
<table class="ft"><tr><td style="width:35%;"><b>Knowledge Assessment</b></td><td>Scheduled: <input type="date"></td></tr>
<tr><td><b>Practical Assessment</b></td><td>Scheduled: <input type="date"></td></tr>
<tr><td><b>Workplace Evaluation</b></td><td>Scheduled: <input type="date"></td></tr></table>
<table class="sig-table"><tr><td style="width:40%;"><label>Candidate Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="candidate-sig-f-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig-f-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
<table class="sig-table"><tr><td style="width:40%;"><label>Assessor Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="assessor-sig-f-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig-f-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
</div>

<!-- APPENDIX G: APPEALS FORM -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>21 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">7. Appendix G: APPEALS FORM</div>
<table class="ft"><tr><td style="width:38%;"><b>Candidate Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($fullname) ?></span></td></tr>
<tr><td><b>Assessor Name:</b></td><td><span class="prefilled"><?= htmlspecialchars(($facilitator['firstName'] ?? '').' '.($facilitator['lastName'] ?? '')) ?></span></td></tr>
<tr><td><b>Institution:</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></span></td></tr>
<tr><td><b>Reason for Appeal:</b></td><td><textarea rows="4" placeholder="State reason clearly..."></textarea></td></tr></table>
<table class="sig-table"><tr><td style="width:40%;"><label>Candidate Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="candidate-sig-g-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig-g-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
</div>

<!-- APPENDIX H: ACCESS RECOMMENDATION -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>22 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">8. Appendix H: ACCESS RECOMMENDATION</div>
<table class="ft"><tr><td style="width:38%;"><b>Candidate Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($fullname) ?></span></td></tr>
<tr><td><b>Trade:</b></td><td><?= htmlspecialchars($tradeName) ?></td></tr>
<tr><td><b>Date of Birth:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['DateOfBirth'] ?? '') ?></span></td></tr></table>
<table class="ft"><tr><th>Assessment Component</th><th style="width:120px;">Ready / Not Yet Ready</th><th class="l">Remarks</th></tr>
<tr><td>Knowledge Assessment</td><td class="c"><input type="text" placeholder="Ready/NRY"></td><td><input type="text" placeholder="Remarks"></td></tr>
<tr><td>Practical Assessment</td><td class="c"><input type="text" placeholder="Ready/NRY"></td><td><input type="text" placeholder="Remarks"></td></tr>
<tr><td>Workplace Evaluation</td><td class="c"><input type="text" placeholder="Ready/NRY"></td><td><input type="text" placeholder="Remarks"></td></tr>
<tr><td><b>Overall Recommendation:</b></td><td colspan="2"><label><input type="radio" name="overall_<?=$learnerID?>" value="trade_test"> Recommended for Trade Test</label>&nbsp;&nbsp;<label><input type="radio" name="overall_<?=$learnerID?>" value="gap_closure"> Recommended for Gap Closure</label></td></tr></table>
<table class="sig-table"><tr><td style="width:40%;"><label>Assessor Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="assessor-sig-h-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig-h-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
</div>

<!-- APPENDIX I: STATEMENT OF RESULTS -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>25 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">9. Appendix I: STATEMENT OF RESULTS</div>
<table class="ft"><tr><td style="width:38%;"><b>Candidate Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($fullname) ?></span></td></tr>
<tr><td><b>ID Number:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['IDNumber']) ?></span></td></tr>
<tr><td><b>Trade:</b></td><td><?= htmlspecialchars($tradeName) ?> (OFO <?= $ofoNumber ?>)</td></tr>
<tr><td><b>Provider:</b></td><td><span class="prefilled"><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></span></td></tr>
<tr><td><b>Assessment Date:</b></td><td><input type="date"></td></tr></table>
<p style="font-size:11pt;font-weight:bold;margin:10px 0;">Results:</p>
<table class="ft"><tr><th>Component</th><th style="width:120px;">Status</th><th style="width:100px;">Score</th></tr>
<tr><td>Knowledge Assessment</td><td class="c"><input type="text" placeholder="Pass/Fail"></td><td class="c"><input type="text" placeholder="Score"></td></tr>
<tr><td>Practical Assessment</td><td class="c"><input type="text" placeholder="Pass/Fail"></td><td class="c"><input type="text" placeholder="Score"></td></tr>
<tr><td>Workplace Evaluation</td><td class="c"><input type="text" placeholder="Pass/Fail"></td><td class="c"><input type="text" placeholder="Score"></td></tr>
<tr style="background:#e8eaf6;"><td><b>Overall Result</b></td><td colspan="2" class="c"><b><input type="text" placeholder="PASS/FAIL" style="width:50%;"></b></td></tr></table>
<table class="sig-table"><tr><td style="width:40%;"><label>Assessor Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="assessor-sig-i-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig-i-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
</div>

<!-- APPENDIX J: PRE-ASSESSMENT AGREEMENT -->
<div class="pb">
<table class="dht"><tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['sdp_name'] ?? '') ?></td></tr>
<tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br><?= $ofoNumber ?></td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
<tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>28 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr></table>
<div class="sec-title">10. Appendix J: CANDIDATE PRE-ASSESSMENT AGREEMENT</div>
<table class="ft"><tr><td style="width:42%;"><b>Candidate Name:</b></td><td><span class="prefilled"><?= htmlspecialchars($fullname) ?></span></td></tr>
<tr><td><b>ID Number:</b></td><td><span class="prefilled"><?= htmlspecialchars($learner['IDNumber']) ?></span></td></tr>
<tr><td><b>Trade:</b></td><td><?= htmlspecialchars($tradeName) ?></td></tr>
<tr><td><b>Date of Agreement:</b></td><td><input type="date" value="<?= date('Y-m-d') ?>"></td></tr></table>
<div class="note" style="margin:12px 0;"><b>NOTE:</b> I hereby agree to be assessed and commit to abide by the rules and regulations of the Assessment. I also agree to the Trade Test Centre's confidentiality agreement regarding assessment materials.</div>
<table class="sig-table"><tr><td style="width:40%;"><label>Candidate Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="candidate-sig-j-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('candidate-sig-j-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
<table class="sig-table"><tr><td style="width:40%;"><label>Assessor Signature:</label><div class="sig-pad-wrapper"><canvas class="sig-pad-canvas" data-sig-id="assessor-sig-j-<?= $learnerID ?>"></canvas><div class="sig-pad-buttons"><button type="button" class="sig-pad-btn" onclick="clearSignature('assessor-sig-j-<?= $learnerID ?>')">Clear</button></div></div></td><td style="width:30%;"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></td></tr></table>
</div>

<!-- END PAGE -->
</div><!-- /.page -->

<script>
// Initialize signature pads
const signaturePads = {};

function initializeSignaturePads() {
    document.querySelectorAll('.sig-pad-canvas').forEach(canvas => {
        const sigId = canvas.getAttribute('data-sig-id');
        const rect = canvas.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;
        canvas.width = rect.width * dpr;
        canvas.height = 80 * dpr;
        const ctx = canvas.getContext('2d');
        ctx.scale(dpr, dpr);
        const signaturePad = new SignaturePad(canvas, {
            backgroundColor: 'rgb(255, 255, 255)'
        });
        signaturePads[sigId] = signaturePad;
    });
}

// Clear signature
window.clearSignature = function(sigId) {
    if (signaturePads[sigId]) {
        signaturePads[sigId].clear();
    }
};

// Initialize on load
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(initializeSignaturePads, 100);
});

// Print handler
window.addEventListener('beforeprint', function() {
    // Prepare for print
});
</script>

</body>
</html>
<?php
?>
