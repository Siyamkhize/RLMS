<?php
/**
 * Generate ARPL Portfolio PDF
 * Creates a complete ARPL portfolio PDF for a learner
 * 
 * Endpoint: POST web/api/generate_arpl_pdf.php
 * 
 * Request:
 * {
 *   "learnerID": 16389,
 *   "ofo_code": "671101"
 * }
 * 
 * Response: PDF file download or JSON status
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

ini_set('display_errors', 0);
error_reporting(E_ALL);

$root_conn_file = __DIR__ . '/../connection.php';
if (!file_exists($root_conn_file)) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'error',
        'message' => 'Connection file not found'
    ]);
    exit;
}

@require_once $root_conn_file;

try {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON request');
    }
    
    if (!isset($conn) || !$conn) {
        throw new Exception('Database connection failed');
    }
    
    $learnerID = isset($data['learnerID']) ? intval($data['learnerID']) : 0;
    $ofo_code = isset($data['ofo_code']) ? trim($data['ofo_code']) : '';
    
    if ($learnerID <= 0 || empty($ofo_code)) {
        throw new Exception('Missing or invalid learnerID or ofo_code parameter');
    }
    
    // Get learner data
    $sql = "SELECT name, surname, idNumber FROM learnerdetails WHERE learnerID = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $learner = $result->fetch_assoc();
    $stmt->close();
    
    if (!$learner) {
        throw new Exception('Learner not found');
    }
    
    // Get trade name
    $tradeNames = [
        '671101' => 'Electrician',
        '641201' => 'Bricklaying',
        '642601' => 'Plumbing',
        '651302' => 'Welding'
    ];
    
    $tradeName = isset($tradeNames[$ofo_code]) ? $tradeNames[$ofo_code] : 'Unknown Trade';
    
    // Determine trade-specific tables based on OFO code
    $tradeLower = strtolower(preg_replace('/\s+/', '', $tradeName));
    if ($tradeLower === 'electrician') {
        $tradeLower = 'electrician';
    } elseif ($tradeLower === 'bricklaying') {
        $tradeLower = 'bricklaying';
    } elseif ($tradeLower === 'plumbing') {
        $tradeLower = 'plumbing';
    }
    
    // Get learner documents
    $documents = [];
    $docSql = "SELECT * FROM learner_document WHERE learner_id = ?";
    $docStmt = $conn->prepare($docSql);
    if ($docStmt) {
        $learnerIDStr = (string)$learnerID;
        $docStmt->bind_param('s', $learnerIDStr);
        $docStmt->execute();
        $docResult = $docStmt->get_result();
        while ($doc = $docResult->fetch_assoc()) {
            $documents[] = $doc;
        }
        $docStmt->close();
    }
    
    // Generate HTML content for PDF using trade-specific tables
    $htmlContent = generateARPLHTML($learner, $tradeName, $ofo_code, $learnerID, $conn, $documents, $tradeLower);
    
    // Generate PDF using HTML
    $pdfFileName = generatePDFFile($htmlContent, $learner, $learnerID);
    
    if (!$pdfFileName) {
        throw new Exception('Failed to generate PDF file');
    }
    
    // Return success with file path
    header('Content-Type: application/json');
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'file' => $pdfFileName,
        'learnerID' => $learnerID,
        'message' => 'PDF generated successfully'
    ]);
    
} catch (Exception $e) {
    header('Content-Type: application/json');
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}

/**
 * Fetch appendix data from database
 */
function fetchAppendixData($conn, $table, $learnerID, $ofo_code) {
    $sql = "SELECT * FROM `$table` WHERE learnerID = ? AND ofo_number = ? LIMIT 1";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return [];
    }
    
    $stmt->bind_param('is', $learnerID, $ofo_code);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = $result->fetch_assoc();
    $stmt->close();
    
    return $data ?: [];
}

/**
 * Fetch theory activities for a learner from trade-specific table
 */
function fetchTheoryActivities($conn, $learnerID, $tradeLower) {
    $table = "arplappxb_" . $tradeLower . "_activities";
    $sql = "SELECT a.activity_id, a.activity_number, a.activity_name, 
                   r.competency_scale_id, r.rating_date, r.comments
            FROM `$table` a
            LEFT JOIN arplappxb_activity_ratings r 
                ON a.activity_id = r.activity_id AND r.learnerID = ?
            ORDER BY a.activity_number ASC";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return [];
    }
    
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $activities = [];
    while ($row = $result->fetch_assoc()) {
        $activities[] = $row;
    }
    $stmt->close();
    
    return $activities;
}

/**
 * Fetch workplace activities for a learner from trade-specific table
 */
function fetchWorkplaceActivities($conn, $learnerID, $tradeLower) {
    $table = "arplappxe_" . $tradeLower . "_activities";
    $ratingsTable = "arplappxe_" . $tradeLower . "_activity_ratings";
    
    $sql = "SELECT a.activity_id, a.activity_number, a.activity_name, 
                   r.competency_scale_id, r.rating_date, r.comments
            FROM `$table` a
            LEFT JOIN `$ratingsTable` r 
                ON a.activity_id = r.activity_id AND r.learnerID = ?
            ORDER BY a.activity_number ASC";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return [];
    }
    
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $activities = [];
    while ($row = $result->fetch_assoc()) {
        $activities[] = $row;
    }
    $stmt->close();
    
    return $activities;
}

/**
 * Fetch ACR (Access Confirmation Recommendation) data for a learner
 */
function fetchAccessRecommendation($conn, $learnerID, $tradeLower) {
    $table = "arpl" . $tradeLower . "_access_recommendation";
    $sql = "SELECT * FROM `$table` WHERE LearnerID = ? LIMIT 1";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return null;
    }
    
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = $result->fetch_assoc();
    $stmt->close();
    
    return $data;
}

/**
 * Format activity responses for display
 */
function formatActivityResponse($activities) {
    $results = [];
    for ($i = 1; $i <= 22; $i++) {
        $key = "activity_$i";
        if (isset($activities[$key])) {
            $results[$i] = ucfirst($activities[$key]);
        }
    }
    return $results;
}

/**
 * Generate HTML content for ARPL portfolio
 */
function generateARPLHTML($learner, $tradeName, $ofo_code, $learnerID, $conn, $documents = [], $tradeLower = 'electrician') {
    $date = date('d F Y');
    
    // Fetch all appendix data from database
    $appendixA = fetchAppendixData($conn, 'arpl_appendix_a', $learnerID, $ofo_code);
    $appendixC = fetchAppendixData($conn, 'arpl_appendix_c', $learnerID, $ofo_code);
    $appendixD = fetchAppendixData($conn, 'arpl_appendix_d', $learnerID, $ofo_code);
    $appendixF = fetchAppendixData($conn, 'arpl_appendix_f', $learnerID, $ofo_code);
    $appendixG = fetchAppendixData($conn, 'arpl_appendix_g', $learnerID, $ofo_code);
    $appendixI = fetchAppendixData($conn, 'arpl_appendix_i', $learnerID, $ofo_code);
    
    // Fetch trade-specific data from mobile app tables
    $theoryActivities = fetchTheoryActivities($conn, $learnerID, $tradeLower);
    $workplaceActivities = fetchWorkplaceActivities($conn, $learnerID, $tradeLower);
    $accessRecommendation = fetchAccessRecommendation($conn, $learnerID, $tradeLower);
    
    // Separate documents by type
    $idDocuments = [];
    $cvDocuments = [];
    $qualificationDocuments = [];
    $otherDocuments = [];
    
    foreach ($documents as $doc) {
        $docName = strtolower($doc['documentName'] ?? '');
        if (strpos($docName, 'id') !== false) {
            $idDocuments[] = $doc;
        } elseif (strpos($docName, 'cv') !== false || strpos($docName, 'curriculum') !== false) {
            $cvDocuments[] = $doc;
        } elseif (strpos($docName, 'qualif') !== false || strpos($docName, 'certificate') !== false) {
            $qualificationDocuments[] = $doc;
        } else {
            $otherDocuments[] = $doc;
        }
    }
    
    $html = <<<HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARPL Portfolio - {$learner['name']} {$learner['surname']}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Arial', sans-serif;
            line-height: 1.6;
            color: #333;
            background: white;
        }
        .page {
            page-break-after: always;
            padding: 40px;
            min-height: 297mm;
            background: white;
        }
        .page:last-child {
            page-break-after: avoid;
        }
        
        /* Cover Page */
        .cover-page {
            display: block;
            text-align: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 60px 40px;
            min-height: 297mm;
            position: relative;
        }
        .cover-page h1 {
            font-size: 48px;
            margin: 60px 0 20px 0;
            font-weight: bold;
        }
        .cover-page .trade-section {
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 10px;
            margin: 50px 0;
        }
        .cover-page .trade-name {
            font-size: 36px;
            font-weight: bold;
            margin: 20px 0;
        }
        .cover-page .trade-code {
            font-size: 18px;
            opacity: 0.9;
        }
        .learner-info-cover {
            margin: 50px auto;
            background: rgba(255,255,255,0.15);
            padding: 20px;
            border-radius: 8px;
            max-width: 600px;
        }
        .learner-info-cover p {
            font-size: 14px;
            margin: 10px 0;
        }
        .cover-page .footer {
            position: absolute;
            bottom: 40px;
            left: 0;
            right: 0;
            font-size: 12px;
            opacity: 0.8;
        }
        
        /* Regular Pages */
        .page h2 {
            color: #667eea;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
            margin: 30px 0 20px 0;
            font-size: 24px;
        }
        .page h3 {
            color: #764ba2;
            margin: 20px 0 10px 0;
            font-size: 16px;
        }
        .page p {
            margin: 10px 0;
            font-size: 12px;
            text-align: justify;
        }
        
        .table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            font-size: 11px;
        }
        .table th {
            background: #667eea;
            color: white;
            padding: 10px;
            text-align: left;
            border: 1px solid #ddd;
        }
        .table td {
            padding: 8px;
            border: 1px solid #ddd;
        }
        .table tr:nth-child(even) {
            background: #f9f9f9;
        }
        
        .info-box {
            background: #f0f4ff;
            border-left: 4px solid #667eea;
            padding: 15px;
            margin: 15px 0;
            border-radius: 4px;
        }
        
        .checklist {
            list-style: none;
            margin: 10px 0;
        }
        .checklist li {
            padding: 8px 0;
            border-bottom: 1px solid #eee;
            font-size: 12px;
        }
        .checklist li:before {
            content: "☑ ";
            color: #667eea;
            font-weight: bold;
            margin-right: 10px;
        }
        
        .section-number {
            display: inline-block;
            background: #667eea;
            color: white;
            width: 30px;
            height: 30px;
            border-radius: 50%;
            text-align: center;
            line-height: 30px;
            font-weight: bold;
            margin-right: 10px;
        }
        
        .header-info {
            display: flex;
            justify-content: space-between;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
            margin-bottom: 20px;
            font-size: 11px;
        }
        .header-info span {
            font-weight: bold;
        }
        
        .page-number {
            text-align: right;
            font-size: 10px;
            color: #999;
            margin-top: 30px;
        }
        
        @media print {
            body {
                background: white;
            }
            .page {
                page-break-after: always;
                box-shadow: none;
            }
        }
    </style>
</head>
<body>

<!-- PAGE 1: COVER PAGE -->
<div class="page cover-page">
    <h1>ARPL PORTFOLIO</h1>
    <p style="font-size: 20px; opacity: 0.9; margin: 0 0 30px 0;">Recognition of Prior Learning</p>
    
    <div class="trade-section">
        <p style="font-size: 14px; opacity: 0.9; margin: 0 0 10px 0;">Qualification</p>
        <div class="trade-name">{$tradeName}</div>
        <p class="trade-code">NQF Level 4 | OFO Code: {$ofo_code}</p>
    </div>
    
    <div class="learner-info-cover">
        <p style="margin: 8px 0;"><strong>Learner Name:</strong> {$learner['name']} {$learner['surname']}</p>
        <p style="margin: 8px 0;"><strong>Learner ID:</strong> {$learnerID}</p>
        <p style="margin: 8px 0;"><strong>ID Number:</strong> {$learner['idNumber']}</p>
        <p style="margin: 8px 0;"><strong>Portfolio Generated:</strong> {$date}</p>
    </div>
    
    <div class="footer">
        <p style="margin: 0;">This portfolio documents evidence of learning and competency</p>
    </div>
</div>

<!-- PAGE 2: ARPL PORTFOLIO CHECKLIST -->
<div class="page">
    <div class="header-info">
        <span>ARPL Portfolio Checklist</span>
        <span>Page 2 of 24</span>
    </div>
    
    <h2><span class="section-number">1</span>ARPL Portfolio Checklist</h2>
    
    <div class="info-box">
        <strong>Portfolio Compliance Requirements</strong>
        <p>This checklist ensures that all mandatory components of the ARPL portfolio are included and meet regulatory standards.</p>
    </div>
    
    <h3>Mandatory Documents</h3>
    <ul class="checklist">
        <li>Cover page with learner and assessor information</li>
        <li>ARPL Portfolio Checklist (this document)</li>
        <li>Certified copy of ID document</li>
        <li>Curriculum Vitae (CV)</li>
        <li>Certified copies of relevant qualifications</li>
        <li>Service letter from employer (if applicable)</li>
        <li>Application form for recognition</li>
    </ul>
    
    <h3>Assessment Components</h3>
    <ul class="checklist">
        <li>Theory assessment papers (5 papers minimum)</li>
        <li>Practical skill assessment evidence</li>
        <li>Workplace experience documentation</li>
        <li>Competency ratings and evaluation</li>
        <li>Gap closure analysis (if required)</li>
        <li>Assessor recommendations</li>
        <li>Appeal documentation (if applicable)</li>
    </ul>
    
    <h3>Supporting Documentation</h3>
    <ul class="checklist">
        <li>Attendance registers</li>
        <li>Photographs of practical work</li>
        <li>Workplace supervisory reports</li>
        <li>Assessment rubrics and rating scales</li>
        <li>Feedback forms and comments</li>
    </ul>
    
    <div style="margin-top: 30px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;">
        <p><strong>Status:</strong> Portfolio under review</p>
        <p><strong>Generated:</strong> {$date}</p>
        <p><strong>Assessor Review Required:</strong> Yes</p>
    </div>
    
    <div class="page-number">Page 2 of 24</div>
</div>

<!-- PAGE 3: LEARNER INFORMATION -->
<div class="page">
    <div class="header-info">
        <span>Learner Information</span>
        <span>Page 3 of 24</span>
    </div>
    
    <h2><span class="section-number">2</span>Learner Information</h2>
    
    <div class="info-box">
        <strong>Personal Details</strong>
    </div>
    
    <table class="table">
        <tr>
            <th>Field</th>
            <th>Value</th>
        </tr>
        <tr>
            <td>Full Name</td>
            <td>{$learner['name']} {$learner['surname']}</td>
        </tr>
        <tr>
            <td>Learner ID</td>
            <td>{$learnerID}</td>
        </tr>
        <tr>
            <td>ID Number</td>
            <td>{$learner['idNumber']}</td>
        </tr>
        <tr>
            <td>Trade/Qualification</td>
            <td>{$tradeName} (OFO: {$ofo_code})</td>
        </tr>
        <tr>
            <td>NQF Level</td>
            <td>4</td>
        </tr>
        <tr>
            <td>Portfolio Generated</td>
            <td>{$date}</td>
        </tr>
    </table>
    
    <h3>Qualification Details</h3>
    <p><strong>Trade:</strong> {$tradeName}</p>
    <p><strong>OFO Code:</strong> {$ofo_code}</p>
    <p><strong>NQF Level:</strong> 4</p>
    <p><strong>Assessment Method:</strong> ARPL (Recognition of Prior Learning)</p>
    <p><strong>Portfolio Format:</strong> Compiled evidence of competency and learning</p>
    
    <h3>Assessment Timeline</h3>
    <p><strong>Portfolio Initiation Date:</strong> {$date}</p>
    <p><strong>Assessment Period:</strong> To be determined by assessor</p>
    <p><strong>Expected Completion:</strong> To be confirmed</p>
    
    <div class="page-number">Page 3 of 24</div>
</div>

HTML;

    // BUILD SUPPORTING DOCUMENTS SECTION DYNAMICALLY
    $html .= <<<HTML
<!-- PAGE 4-6: SUPPORTING DOCUMENTS -->
<div class="page">
    <div class="header-info">
        <span>Supporting Documents</span>
        <span>Pages 4-6 of 24</span>
    </div>
    
    <h2><span class="section-number">3</span>Supporting Documents</h2>
    
    <h3>Required Documents - From Database</h3>
    <p>The following supporting documents have been uploaded and are attached to this portfolio:</p>
    
    <div class="info-box">
        <strong>Document Status Summary</strong>
        <ul style="list-style: none; padding-left: 0; margin: 10px 0;">
            <li>✓ ID Document: HTML;
    
    if (count($idDocuments) > 0) {
        $html .= "Attached";
    } else {
        $html .= "Pending";
    }
    
    $html .= <<<HTML
</li>
            <li>✓ Curriculum Vitae (CV): HTML;
    
    if (count($cvDocuments) > 0) {
        $html .= "Attached";
    } else {
        $html .= "Pending";
    }
    
    $html .= <<<HTML
</li>
            <li>✓ Qualifications: HTML;
    
    if (count($qualificationDocuments) > 0) {
        $html .= "Attached";
    } else {
        $html .= "Pending";
    }
    
    $html .= <<<HTML
</li>
            <li>✓ Service Letters: Pending Upload</li>
        </ul>
    </div>
    
HTML;
    
    // Display ID Documents
    if (count($idDocuments) > 0) {
        $html .= "<h3>Identified Documents</h3>";
        foreach ($idDocuments as $doc) {
            $html .= "<div class='info-box'>";
            $html .= "<p><strong>Document Name:</strong> " . htmlspecialchars($doc['documentName']) . "</p>";
            $html .= "<p><strong>Status:</strong> <span style='color: green;'>✓ " . htmlspecialchars($doc['status']) . "</span></p>";
            $html .= "<p><strong>Uploaded:</strong> " . htmlspecialchars($doc['upload_date']) . "</p>";
            $html .= "<p><strong>File Path:</strong> <code>" . htmlspecialchars($doc['learner_document']) . "</code></p>";
            $html .= "</div>";
        }
    }
    
    // Display CV Documents
    if (count($cvDocuments) > 0) {
        $html .= "<h3>Curriculum Vitae</h3>";
        foreach ($cvDocuments as $doc) {
            $html .= "<div class='info-box'>";
            $html .= "<p><strong>Document Name:</strong> " . htmlspecialchars($doc['documentName']) . "</p>";
            $html .= "<p><strong>Status:</strong> <span style='color: green;'>✓ " . htmlspecialchars($doc['status']) . "</span></p>";
            $html .= "<p><strong>Uploaded:</strong> " . htmlspecialchars($doc['upload_date']) . "</p>";
            $html .= "<p><strong>File Path:</strong> <code>" . htmlspecialchars($doc['learner_document']) . "</code></p>";
            $html .= "</div>";
        }
    }
    
    // Display Qualification Documents
    if (count($qualificationDocuments) > 0) {
        $html .= "<h3>Qualifications & Certificates</h3>";
        foreach ($qualificationDocuments as $doc) {
            $html .= "<div class='info-box'>";
            $html .= "<p><strong>Document Name:</strong> " . htmlspecialchars($doc['documentName']) . "</p>";
            $html .= "<p><strong>Status:</strong> <span style='color: green;'>✓ " . htmlspecialchars($doc['status']) . "</span></p>";
            $html .= "<p><strong>Uploaded:</strong> " . htmlspecialchars($doc['upload_date']) . "</p>";
            $html .= "<p><strong>File Path:</strong> <code>" . htmlspecialchars($doc['learner_document']) . "</code></p>";
            $html .= "</div>";
        }
    }
    
    // Display Other Documents
    if (count($otherDocuments) > 0) {
        $html .= "<h3>Other Supporting Documents</h3>";
        foreach ($otherDocuments as $doc) {
            $html .= "<div class='info-box'>";
            $html .= "<p><strong>Document Name:</strong> " . htmlspecialchars($doc['documentName']) . "</p>";
            $html .= "<p><strong>Status:</strong> <span style='color: green;'>✓ " . htmlspecialchars($doc['status']) . "</span></p>";
            $html .= "<p><strong>Uploaded:</strong> " . htmlspecialchars($doc['upload_date']) . "</p>";
            $html .= "<p><strong>File Path:</strong> <code>" . htmlspecialchars($doc['learner_document']) . "</code></p>";
            $html .= "</div>";
        }
    }
    
    if (count($documents) === 0) {
        $html .= "<div class='info-box'><p><em>No supporting documents uploaded yet. Documents should be uploaded through the system.</em></p></div>";
    }
    
    $html .= <<<HTML
    
    <h3>Document Checklist</h3>
    <table class="table">
        <tr>
            <th>Document Type</th>
            <th>Required</th>
            <th>Status</th>
        </tr>
        <tr>
            <td>Certified ID Copy</td>
            <td>Yes</td>
            <td>HTML;
    
    $html .= (count($idDocuments) > 0) ? '<span style="color: green;">✓ Attached</span>' : 'Pending Upload';
    
    $html .= <<<HTML
</td>
        </tr>
        <tr>
            <td>Curriculum Vitae</td>
            <td>Yes</td>
            <td>HTML;
    
    $html .= (count($cvDocuments) > 0) ? '<span style="color: green;">✓ Attached</span>' : 'Pending Upload';
    
    $html .= <<<HTML
</td>
        </tr>
        <tr>
            <td>Qualifications/Certificates</td>
            <td>Yes</td>
            <td>HTML;
    
    $html .= (count($qualificationDocuments) > 0) ? '<span style="color: green;">✓ Attached</span>' : 'Pending Upload';
    
    $html .= <<<HTML
</td>
        </tr>
        <tr>
            <td>Service Letters</td>
            <td>Yes</td>
            <td>Pending Upload</td>
        </tr>
    </table>
    
    <div class="page-number">Pages 4-6 of 24</div>
</div>

HTML;

    // BUILD THEORY ACTIVITIES SECTION
    $html .= <<<HTML
<!-- PAGE 7-8: APPENDIX B (THEORY ACTIVITIES) - TRADE-SPECIFIC -->
<div class="page">
    <div class="header-info">
        <span>Appendix B: Theory Self-Evaluation</span>
        <span>Pages 7-8 of 24</span>
    </div>
    
    <h2><span class="section-number">A</span>Appendix B: Theory Assessment - Knowledge Self-Evaluation</h2>
    
    <div class="info-box">
        <strong>Competency Proficiency Scale for Self-Evaluation (Theory Knowledge)</strong>
        <p style="font-size: 10px;">Rate your level of knowledge in each area using the scale below:</p>
    </div>
    
    <table class="table" style="font-size: 9px; margin-bottom: 15px;">
        <tr>
            <th style="width: 8%; text-align: center; background: #667eea; color: white;">Score</th>
            <th style="width: 25%; background: #667eea; color: white;">Proficiency Level</th>
            <th style="background: #667eea; color: white;">Description</th>
        </tr>
        <tr>
            <td style="text-align: center; font-weight: bold;">1</td>
            <td><b>Fundamental Awareness</b></td>
            <td>You have basic knowledge but your understanding is minimal</td>
        </tr>
        <tr>
            <td style="text-align: center; font-weight: bold;">2</td>
            <td><b>Novice</b></td>
            <td>You have limited experience - not yet fully competent</td>
        </tr>
        <tr>
            <td style="text-align: center; font-weight: bold;">3</td>
            <td><b>Intermediate</b></td>
            <td>You meet minimum requirements but need more experience</td>
        </tr>
        <tr>
            <td style="text-align: center; font-weight: bold;">4</td>
            <td><b>Advanced</b></td>
            <td>You have all required knowledge and practical skills</td>
        </tr>
        <tr>
            <td style="text-align: center; font-weight: bold;">5</td>
            <td><b>Expert</b></td>
            <td>You have expert knowledge and can teach others</td>
        </tr>
    </table>
    
    <p style="font-size: 10px; font-weight: bold; margin: 10px 0;">Theory Knowledge & Practical Skills Assessment:</p>
    <table class="table" style="font-size: 9px;">
        <tr>
            <th style="width: 50%; background: #f0f4ff;">Knowledge/Skill Area</th>
            <th style="width: 10%; text-align: center; background: #f0f4ff;">1</th>
            <th style="width: 10%; text-align: center; background: #f0f4ff;">2</th>
            <th style="width: 10%; text-align: center; background: #f0f4ff;">3</th>
            <th style="width: 10%; text-align: center; background: #f0f4ff;">4</th>
            <th style="width: 10%; text-align: center; background: #f0f4ff;">5</th>
        </tr>
        <tr>
            <td>Safety and Health Regulations</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Hand and Workshop Tools</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Measuring and Testing Equipment</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Blueprint and Technical Drawings</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Materials and Specifications</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Trade-Specific Knowledge</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Workplace Standards & Compliance</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
    </table>
    
    <div style="margin: 15px 0; padding: 15px; border: 1px solid #ddd; background: #fafafa;">
        <table style="width: 100%; font-size: 10px;">
            <tr>
                <td style="width: 50%;"><b>Learner Signature:</b></td>
                <td style="border-bottom: 1px solid #999; height: 20px;"></td>
            </tr>
            <tr>
                <td><b>Date:</b></td>
                <td style="border-bottom: 1px solid #999; height: 20px;"></td>
            </tr>
        </table>
    </div>
    
    <div class="page-number">Pages 7-8 of 24</div>
</div>

<!-- PAGE 9-10: APPENDIX E (WORKPLACE ACTIVITIES) - TRADE-SPECIFIC -->
<div class="page">
    <div class="header-info">
        <span>Appendix E: Workplace Experience Evaluation</span>
        <span>Pages 9-10 of 24</span>
    </div>
    
    <h2><span class="section-number">B</span>Appendix E: Workplace Experience & Assessment</h2>
    
    <div class="info-box">
        <strong>Workplace Competency Evaluation</strong>
        <p style="font-size: 10px;">This section documents the learner's demonstration of competency in the workplace environment. Rate each activity using the 1-5 scale (see Appendix B for descriptions).</p>
    </div>
    
    <p style="font-size: 10px; font-weight: bold; margin: 10px 0;">Workplace Activities and Ratings:</p>
    <table class="table" style="font-size: 9px;">
        <tr>
            <th style="width: 50%; background: #f0f4ff;">Workplace Activity</th>
            <th style="width: 10%; text-align: center; background: #f0f4ff;">1</th>
            <th style="width: 10%; text-align: center; background: #f0f4ff;">2</th>
            <th style="width: 10%; text-align: center; background: #f0f4ff;">3</th>
            <th style="width: 10%; text-align: center; background: #f0f4ff;">4</th>
            <th style="width: 10%; text-align: center; background: #f0f4ff;">5</th>
        </tr>
        <tr>
            <td>Planning and Preparation</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Material Selection and Handling</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Tool Use and Equipment Operation</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Quality Standards Compliance</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Safety and Health Practice</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Communication and Teamwork</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Problem Solving and Adaptability</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
        <tr>
            <td>Work Completion and Reporting</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
            <td style="text-align: center;">☐</td>
        </tr>
    </table>
    
    <p style="font-size: 10px; font-weight: bold; margin: 10px 0;">Supervisor Comments:</p>
    <div style="height: 50px; border: 1px solid #ddd; padding: 8px; background: white; font-size: 9px; overflow: hidden;">
        (Space for supervisor/assessor comments on workplace performance)
    </div>
    
    <div style="margin: 15px 0; padding: 15px; border: 1px solid #ddd; background: #fafafa;">
        <table style="width: 100%; font-size: 10px;">
            <tr>
                <td style="width: 50%;"><b>Supervisor/Assessor Name:</b></td>
                <td style="border-bottom: 1px solid #999; height: 20px;"></td>
            </tr>
            <tr>
                <td><b>Signature:</b></td>
                <td style="border-bottom: 1px solid #999; height: 20px;"></td>
            </tr>
            <tr>
                <td><b>Date:</b></td>
                <td style="border-bottom: 1px solid #999; height: 20px;"></td>
            </tr>
        </table>
    </div>
    
    <div class="page-number">Pages 9-10 of 24</div>
</div>

<!-- PAGE 11: APPENDIX H (ACCESS CONFIRMATION RECOMMENDATION) - TRADE-SPECIFIC -->
<div class="page">
    <div class="header-info">
        <span>Appendix H: Access Confirmation Recommendation</span>
        <span>Page 11 of 24</span>
    </div>
    
    <h2><span class="section-number">C</span>Appendix H: Access Confirmation Recommendation (ACR)</h2>
    
    <div class="info-box">
        <strong>Assessor Recommendation for ARPL Access & Certification</strong>
        <p style="font-size: 10px;">Based on the evidence of prior learning and comprehensive assessment results, the following recommendation is made:</p>
    </div>
    
    <table class="table" style="font-size: 10px;">
        <tr>
            <th style="width: 40%; background: #f0f4ff;">Field</th>
            <th style="width: 60%; background: #f0f4ff;">Value</th>
        </tr>
        <tr>
            <td><b>Learner Name</b></td>
            <td>{$learner['name']} {$learner['surname']}</td>
        </tr>
        <tr>
            <td><b>Trade/Qualification</b></td>
            <td>{$tradeName}</td>
        </tr>
        <tr>
            <td><b>OFO Code</b></td>
            <td>{$ofo_code}</td>
        </tr>
        <tr>
            <td><b>NQF Level</b></td>
            <td>4</td>
        </tr>
        <tr>
            <td><b>ACR Reference Number</b></td>
            <td>_______________________</td>
        </tr>
        <tr>
            <td><b>Assessment Status</b></td>
            <td>☐ Complete &nbsp;&nbsp; ☐ Pending &nbsp;&nbsp; ☐ Under Review</td>
        </tr>
    </table>
    
    <p style="font-size: 10px; font-weight: bold; margin: 15px 0 10px 0;">Overall Assessment Recommendation:</p>
    <table class="table" style="font-size: 10px;">
        <tr>
            <td style="width: 50%;"><b>ACR Decision:</b></td>
            <td style="background: #f0f4ff;">
                ☐ <b>APPROVED</b> &nbsp;&nbsp; ☐ <b>CONDITIONALLY APPROVED</b> &nbsp;&nbsp; ☐ <b>NOT APPROVED</b>
            </td>
        </tr>
        <tr>
            <td><b>Competency Level (1-5):</b></td>
            <td style="background: #f0f4ff;">
                ☐ 1 &nbsp; ☐ 2 &nbsp; ☐ 3 &nbsp; ☐ 4 &nbsp; ☐ 5
            </td>
        </tr>
        <tr>
            <td><b>Recommendation:</b></td>
            <td style="background: #f0f4ff;">
                ☐ CERTIFICATION &nbsp;&nbsp; ☐ GAP CLOSURE &nbsp;&nbsp; ☐ REJECT
            </td>
        </tr>
    </table>
    
    <p style="font-size: 10px; font-weight: bold; margin: 10px 0 5px 0;">Assessor Remarks (if applicable):</p>
    <div style="height: 60px; border: 1px solid #ddd; padding: 8px; background: white; font-size: 10px; overflow: hidden;">
        (Assessor comments on ACR decision and recommendations)
    </div>
    
    <div style="margin: 15px 0; padding: 15px; border: 1px solid #ddd; background: #fafafa;">
        <p style="font-size: 10px; font-weight: bold; margin-bottom: 8px;">Assessor Certification:</p>
        <table style="width: 100%; font-size: 10px;">
            <tr>
                <td style="width: 50%;"><b>Assessor Name & Title:</b></td>
                <td style="border-bottom: 1px solid #999; height: 20px;"></td>
            </tr>
            <tr>
                <td><b>Assessor Signature:</b></td>
                <td style="border-bottom: 1px solid #999; height: 25px;"></td>
            </tr>
            <tr>
                <td><b>Date:</b></td>
                <td style="border-bottom: 1px solid #999; height: 20px;"></td>
            </tr>
        </table>
    </div>
    
    <p style="font-size: 9px; color: #666; text-align: center; margin-top: 10px;">
        <em>This recommendation is based on evidence gathered through the ARPL assessment process.</em>
    </p>
    
    <div class="page-number">Page 11 of 24</div>
</div>

<!-- PAGE 12-20: APPENDICES A, C, D, F, G, I -->
<div class="page">
    <div class="header-info">
        <span>Additional Appendices A, C, D, F, G, I</span>
        <span>Pages 12-20 of 24</span>
    </div>
    <h2><span class="section-number">4</span>Assessment Appendices (A, C, D, F, G, I)</h2>
    
    <!-- APPENDIX A: APPLICATION FORM -->
    <h3>Appendix A: Application Form</h3>
    <div class="info-box">
        <table class="table" style="font-size: 10px; width: 100%; margin: 10px 0;">
            <tr>
                <th style="width: 30%;">Document</th>
                <th style="width: 30%;">Trade</th>
                <th style="width: 40%;">Trade Test Centre</th>
            </tr>
            <tr>
                <td>ARPLTOOLKIT</td>
                <td>{$tradeName}</td>
                <td>Provider Details</td>
            </tr>
            <tr>
                <th style="width: 30%;">Version</th>
                <th style="width: 30%;">OFO Code</th>
                <th style="width: 40%;">Accreditation No</th>
            </tr>
            <tr>
                <td>1/2019</td>
                <td>{$ofo_code}</td>
                <td>To be entered</td>
            </tr>
        </table>
        
        <h4 style="margin: 15px 0 10px 0; font-size: 12px;">APPLICATION FOR RECOGNITION OF PRIOR LEARNING</h4>
        
        <p style="font-size: 11px; font-weight: bold; margin: 10px 0;">Applicant Details:</p>
        <table class="table" style="font-size: 10px;">
            <tr>
                <td style="width: 35%;"><b>Ref Number:</b></td>
                <td style="background: #f9f9f9; padding: 8px;">{$learnerID}</td>
            </tr>
            <tr>
                <td><b>Trade Title</b></td>
                <td style="background: #f9f9f9;">{$tradeName}</td>
            </tr>
            <tr>
                <td><b>OFO Code</b></td>
                <td style="background: #f9f9f9;">{$ofo_code}</td>
            </tr>
            <tr>
                <td><b>Name of Candidate</b></td>
                <td style="background: #f9f9f9;">{$learner['name']} {$learner['surname']}</td>
            </tr>
            <tr>
                <td><b>ID Number</b></td>
                <td style="background: #f9f9f9;">{$learner['idNumber']}</td>
            </tr>
        </table>
        
        <p style="font-size: 11px; font-weight: bold; margin: 15px 0 10px 0;">Address Details:</p>
        <table class="table" style="font-size: 10px;">
            <tr>
                <th style="width: 48%; background: #f0f4ff;">Physical Address</th>
                <th style="width: 48%; background: #f0f4ff;">Postal Address</th>
            </tr>
            <tr>
                <td>[Address Line 1]</td>
                <td>[Postal Line 1]</td>
            </tr>
            <tr>
                <td>[Address Line 2]</td>
                <td>[Postal Line 2]</td>
            </tr>
            <tr>
                <td>[City/Postal Code]</td>
                <td>[Postal Code]</td>
            </tr>
        </table>
        
        <p style="font-size: 11px; font-weight: bold; margin: 15px 0 10px 0;">Contact Details:</p>
        <table class="table" style="font-size: 10px;">
            <tr>
                <td style="width: 35%;"><b>Tel No</b></td>
                <td style="background: #f9f9f9;">[Phone]</td>
            </tr>
            <tr>
                <td><b>Cell No</b></td>
                <td style="background: #f9f9f9;">[Cell Phone]</td>
            </tr>
            <tr>
                <td><b>Email</b></td>
                <td style="background: #f9f9f9;">[Email Address]</td>
            </tr>
        </table>
        
        <p style="font-size: 11px; font-weight: bold; margin: 15px 0 10px 0;">Employment Status:</p>
        <table class="table" style="font-size: 10px;">
            <tr>
                <td style="width: 35%;"><b>Currently Employed</b></td>
                <td>☐ Yes &nbsp;&nbsp; ☐ No</td>
            </tr>
            <tr>
                <td><b>Self Employed</b></td>
                <td>☐ Yes &nbsp;&nbsp; ☐ No</td>
            </tr>
            <tr>
                <td><b>Current/Most Recent Employer</b></td>
                <td style="background: #f9f9f9;">[Employer Name]</td>
            </tr>
            <tr>
                <td><b>Position/Job Title</b></td>
                <td style="background: #f9f9f9;">[Job Title]</td>
            </tr>
            <tr>
                <td><b>Employer Contact</b></td>
                <td style="background: #f9f9f9;">[Phone/Email]</td>
            </tr>
        </table>
        
        <p style="font-size: 11px; font-weight: bold; margin: 15px 0 10px 0;">Employment History:</p>
        <table class="table" style="font-size: 9px;">
            <tr>
                <th>Company</th>
                <th>Position</th>
                <th>Period & Duration</th>
                <th>Contact</th>
            </tr>
            <tr>
                <td>[Company 1]</td>
                <td>[Job Title]</td>
                <td>[Dates]</td>
                <td>[Tel]</td>
            </tr>
            <tr>
                <td>[Company 2]</td>
                <td>[Job Title]</td>
                <td>[Dates]</td>
                <td>[Tel]</td>
            </tr>
            <tr>
                <td>[Company 3]</td>
                <td>[Job Title]</td>
                <td>[Dates]</td>
                <td>[Tel]</td>
            </tr>
        </table>
        
        <div style="margin: 15px 0; border-top: 1px solid #ddd; padding-top: 15px;">
            <table style="width: 100%; font-size: 10px;">
                <tr>
                    <td style="width: 40%;"><b>Candidate Signature:</b></td>
                    <td style="border-bottom: 1px solid #ddd; height: 20px;"></td>
                </tr>
                <tr>
                    <td style="padding-top: 10px;"><b>Date:</b></td>
                    <td style="border-bottom: 1px solid #ddd; height: 20px; padding-top: 10px;"></td>
                </tr>
            </table>
        </div>
    </div>
    
    <!-- APPENDIX C: CURRICULUM CONTENT -->
    <h3>Appendix C: Trade Curriculum Content</h3>
    <div class="info-box">
        <table class="table" style="font-size: 10px; margin-bottom: 15px;">
            <tr>
                <th style="width: 50%; background: #f0f4ff;">Knowledge Area</th>
                <th style="width: 50%; background: #f0f4ff;">Learning Outcomes</th>
            </tr>
            <tr>
                <td><b>Safety & Health</b></td>
                <td>Demonstrate knowledge of workplace safety and health regulations</td>
            </tr>
            <tr>
                <td><b>Tools & Equipment</b></td>
                <td>Identify and safely use trade-specific tools and equipment</td>
            </tr>
            <tr>
                <td><b>Practical Skills</b></td>
                <td>Execute trade activities according to industry standards</td>
            </tr>
            <tr>
                <td><b>Workplace Practice</b></td>
                <td>Apply best practices in workplace environment</td>
            </tr>
            <tr>
                <td><b>Quality Standards</b></td>
                <td>Ensure work meets required quality and specification standards</td>
            </tr>
        </table>
        
        <p style="font-size: 10px;"><b>Curriculum Overview:</b> The {$tradeName} curriculum is designed to develop practical competency in all aspects of the trade, including theoretical knowledge and hands-on skill application in workplace environments.</p>
        
        <p style="font-size: 10px; margin-top: 10px;"><b>Assessment Components:</b></p>
        <ul style="font-size: 10px; margin: 5px 0; padding-left: 20px;">
            <li>Theory Assessment (5 papers)</li>
            <li>Practical Skill Assessment (22 activities)</li>
            <li>Workplace Experience Evaluation</li>
            <li>Competency Rating Scale</li>
        </ul>
    </div>
    
    <!-- APPENDIX D: PRACTICAL SKILLS CHECKLIST -->
    <h3>Appendix D: Practical Skills Assessment (22 Activities)</h3>
    <div class="info-box">
        <p style="font-size: 10px; font-weight: bold; margin-bottom: 10px;">Competency Proficiency Scale:</p>
        <table class="table" style="font-size: 9px; margin-bottom: 15px;">
            <tr>
                <th style="width: 10%; background: #667eea; color: white;">Score</th>
                <th style="width: 30%; background: #667eea; color: white;">Proficiency Level</th>
                <th style="width: 60%; background: #667eea; color: white;">Description</th>
            </tr>
            <tr>
                <td>1</td>
                <td><b>Awareness</b></td>
                <td>Basic knowledge - exposure only</td>
            </tr>
            <tr>
                <td>2</td>
                <td><b>Novice</b></td>
                <td>Limited experience - not yet competent</td>
            </tr>
            <tr>
                <td>3</td>
                <td><b>Intermediate</b></td>
                <td>Meets minimum competency - needs more experience</td>
            </tr>
            <tr>
                <td>4</td>
                <td><b>Advanced</b></td>
                <td>All required knowledge and skills present</td>
            </tr>
            <tr>
                <td>5</td>
                <td><b>Expert</b></td>
                <td>Expert knowledge - can teach others</td>
            </tr>
        </table>
        
        <p style="font-size: 10px; font-weight: bold; margin: 10px 0;">Practical Skills Activities and Ratings:</p>
        <table class="table" style="font-size: 9px;">
            <tr>
                <th style="width: 8%; text-align: center;">No</th>
                <th style="width: 42%;">Activity</th>
                <th style="width: 12%; text-align: center;">Rating</th>
                <th style="width: 8%; text-align: center;">No</th>
                <th style="width: 12%;">Activity</th>
                <th style="width: 12%; text-align: center;">Rating</th>
            </tr>
HTML;

    // Display practical activities in two columns
    if (!empty($appendixD)) {
        $activities = formatActivityResponse($appendixD);
        for ($i = 1; $i <= 22; $i += 2) {
            $status1 = isset($activities[$i]) ? $activities[$i] : '-';
            $activity2 = $i+1;
            $status2 = isset($activities[$activity2]) ? $activities[$activity2] : '-';
            $html .= "<tr>";
            $html .= "<td style='text-align: center;'>$i</td>";
            $html .= "<td>Practical Skill $i</td>";
            $html .= "<td style='text-align: center;'>☐</td>";
            $html .= "<td style='text-align: center;'>$activity2</td>";
            $html .= "<td>Practical Skill $activity2</td>";
            $html .= "<td style='text-align: center;'>☐</td>";
            $html .= "</tr>";
        }
    } else {
        $html .= "<tr><td colspan='6' style='text-align: center;'><em>Practical skills to be assessed and rated</em></td></tr>";
    }
    
    $html .= <<<HTML
        </table>
    </div>
    
    <!-- APPENDIX F: ASSESSMENT EVALUATION AGREEMENT -->
    <h3>Appendix F: Assessment Evaluation Agreement</h3>
    <div class="info-box">
        <p style="font-size: 11px; font-weight: bold; margin: 10px 0;">Assessment Acknowledgements and Agreement:</p>
        
        <table class="table" style="font-size: 10px;">
            <tr>
                <th style="width: 50%;">Assessment Component</th>
                <th style="width: 25%; text-align: center;">Acknowledged</th>
                <th style="width: 25%; text-align: center;">Not Acknowledged</th>
            </tr>
            <tr>
                <td>Theoretical Knowledge Assessment (5 papers)</td>
                <td style="text-align: center;">☐</td>
                <td style="text-align: center;">☐</td>
            </tr>
            <tr>
                <td>Practical Skills Assessment (22 activities)</td>
                <td style="text-align: center;">☐</td>
                <td style="text-align: center;">☐</td>
            </tr>
            <tr>
                <td>Workplace Experience Evaluation</td>
                <td style="text-align: center;">☐</td>
                <td style="text-align: center;">☐</td>
            </tr>
            <tr>
                <td>Competency Rating & Feedback</td>
                <td style="text-align: center;">☐</td>
                <td style="text-align: center;">☐</td>
            </tr>
            <tr>
                <td>Assessor Acknowledgement</td>
                <td style="text-align: center;">☐</td>
                <td style="text-align: center;">☐</td>
            </tr>
        </table>
        
        <div style="margin: 15px 0; padding: 15px; border: 1px solid #ddd; background: #fafafa; border-radius: 4px;">
            <p style="font-size: 10px; font-weight: bold; margin-bottom: 8px;">Learner Declaration:</p>
            <p style="font-size: 10px; margin-bottom: 10px;">I confirm that I understand the assessment requirements and agree to the assessment plan as described above.</p>
            <table style="width: 100%; font-size: 10px;">
                <tr>
                    <td style="width: 50%; border-bottom: 1px solid #999; height: 25px;"></td>
                    <td style="width: 10%;"></td>
                    <td style="width: 40%; border-bottom: 1px solid #999; height: 25px;"></td>
                </tr>
                <tr>
                    <td style="font-size: 9px;">Learner Signature</td>
                    <td></td>
                    <td style="font-size: 9px;">Date</td>
                </tr>
            </table>
        </div>
        
        <div style="margin: 15px 0; padding: 15px; border: 1px solid #ddd; background: #fafafa; border-radius: 4px;">
            <p style="font-size: 10px; font-weight: bold; margin-bottom: 8px;">Assessor Acknowledgement:</p>
            <table style="width: 100%; font-size: 10px;">
                <tr>
                    <td style="width: 50%; border-bottom: 1px solid #999; height: 25px;"></td>
                    <td style="width: 10%;"></td>
                    <td style="width: 40%; border-bottom: 1px solid #999; height: 25px;"></td>
                </tr>
                <tr>
                    <td style="font-size: 9px;">Assessor Signature</td>
                    <td></td>
                    <td style="font-size: 9px;">Date</td>
                </tr>
            </table>
        </div>
    </div>
    
    <!-- APPENDIX G: APPEALS FORM -->
    <h3>Appendix G: Appeals & Feedback Form</h3>
    <div class="info-box">
        <p style="font-size: 11px; font-weight: bold; margin: 10px 0;">Appeals and Dispute Resolution:</p>
        
        <table class="table" style="font-size: 10px; margin-bottom: 10px;">
            <tr>
                <td style="width: 40%;"><b>Appeal Status:</b></td>
                <td style="background: #f9f9f9;">
                    ☐ No Appeal &nbsp;&nbsp; ☐ Appeal Submitted &nbsp;&nbsp; ☐ Appeal Under Review
                </td>
            </tr>
            <tr>
                <td><b>Date of Appeal:</b></td>
                <td style="background: #f9f9f9;">_________________</td>
            </tr>
        </table>
        
        <p style="font-size: 10px; font-weight: bold; margin: 10px 0 5px 0;">Grounds for Appeal (if applicable):</p>
        <div style="height: 60px; border: 1px solid #ddd; padding: 8px; background: white; font-size: 10px; overflow: hidden;">
            (Enter details if appeal is submitted)
        </div>
        
        <p style="font-size: 10px; font-weight: bold; margin: 10px 0 5px 0;">Assessor Response/Findings:</p>
        <div style="height: 60px; border: 1px solid #ddd; padding: 8px; background: white; font-size: 10px; overflow: hidden;">
            (Assessor comments on appeal)
        </div>
        
        <p style="font-size: 10px; font-weight: bold; margin: 10px 0 5px 0;">Learner Feedback:</p>
        <div style="height: 50px; border: 1px solid #ddd; padding: 8px; background: white; font-size: 10px; overflow: hidden;">
            (Optional feedback from learner)
        </div>
        
        <div style="margin: 15px 0; padding: 15px; border: 1px solid #ddd; background: #fafafa; border-radius: 4px;">
            <table style="width: 100%; font-size: 10px;">
                <tr>
                    <td style="width: 50%;"><b>Learner/Representative Signature:</b></td>
                    <td style="width: 50%; border-bottom: 1px solid #999; height: 25px;"></td>
                </tr>
                <tr>
                    <td><b>Date:</b></td>
                    <td style="border-bottom: 1px solid #999; height: 25px;"></td>
                </tr>
            </table>
        </div>
    </div>
    
    <!-- APPENDIX I: STATEMENT OF RESULTS -->
    <h3>Appendix I: Statement of Results</h3>
    <div class="info-box">
        <p style="font-size: 11px; font-weight: bold; margin: 10px 0;">Assessment Results Summary:</p>
        
        <table class="table" style="font-size: 10px; margin-bottom: 15px;">
            <tr>
                <th style="background: #667eea; color: white; width: 40%;">Assessment Component</th>
                <th style="background: #667eea; color: white; width: 30%;">Result</th>
                <th style="background: #667eea; color: white; width: 30%;">Mark / Rating</th>
            </tr>
            <tr>
                <td>Theoretical Knowledge (5 papers avg)</td>
                <td style="background: #f9f9f9;">☐ Pass &nbsp; ☐ Fail</td>
                <td style="background: #f9f9f9;"></td>
            </tr>
            <tr>
                <td>Practical Skills (22 activities avg)</td>
                <td style="background: #f9f9f9;">☐ Pass &nbsp; ☐ Fail</td>
                <td style="background: #f9f9f9;"></td>
            </tr>
            <tr>
                <td>Workplace Experience</td>
                <td style="background: #f9f9f9;">☐ Pass &nbsp; ☐ Fail</td>
                <td style="background: #f9f9f9;"></td>
            </tr>
            <tr>
                <td><b>Overall Result</b></td>
                <td style="background: #f0f4ff;"><b>☐ PASS &nbsp; ☐ FAIL</b></td>
                <td style="background: #f0f4ff;"><b>/100</b></td>
            </tr>
        </table>
        
        <p style="font-size: 10px; font-weight: bold; margin: 10px 0 5px 0;">Overall Competency Rating (1-5 Scale):</p>
        <table class="table" style="font-size: 10px; margin-bottom: 10px;">
            <tr>
                <td style="width: 50%;"><b>Competency Level:</b></td>
                <td style="background: #f9f9f9;">☐ 1 &nbsp; ☐ 2 &nbsp; ☐ 3 &nbsp; ☐ 4 &nbsp; ☐ 5</td>
            </tr>
            <tr>
                <td><b>Description:</b></td>
                <td style="background: #f9f9f9; font-size: 9px;">
                    1=Awareness, 2=Novice, 3=Intermediate, 4=Advanced, 5=Expert
                </td>
            </tr>
        </table>
        
        <div style="margin: 15px 0; padding: 15px; border: 1px solid #ddd; background: #fafafa; border-radius: 4px;">
            <p style="font-size: 10px; font-weight: bold; margin-bottom: 8px;">Assessor Certification:</p>
            <table style="width: 100%; font-size: 10px;">
                <tr>
                    <td style="width: 50%;"><b>Assessor Name:</b></td>
                    <td style="border-bottom: 1px solid #999; height: 20px;"></td>
                </tr>
                <tr>
                    <td><b>Assessor Signature:</b></td>
                    <td style="border-bottom: 1px solid #999; height: 25px;"></td>
                </tr>
                <tr>
                    <td><b>Date:</b></td>
                    <td style="border-bottom: 1px solid #999; height: 20px;"></td>
                </tr>
            </table>
        </div>
        
        <p style="font-size: 9px; color: #666; margin-top: 15px; text-align: center;">
            <em>This is an official statement of assessment results for the ARPL {$tradeName} qualification.</em>
        </p>
    </div>
    
    <div class="page-number">Pages 12-20 of 24</div>
</div>

<!-- PAGE 21-22: ASSESSMENT EVIDENCE PLACEHOLDER -->
<div class="page">
    <div class="header-info">
        <span>Assessment Evidence</span>
        <span>Pages 21-22 of 24</span>
    </div>
    
    <h2><span class="section-number">5</span>Assessment Evidence</h2>
    
    <h3>Theory Assessment (Pages 16-17)</h3>
    <p>This section should contain scanned copies of:</p>
    <ul style="margin: 10px 0; padding-left: 20px;">
        <li>Theory Paper 1 answers and marking</li>
        <li>Theory Paper 2 answers and marking</li>
        <li>Theory Paper 3 answers and marking</li>
        <li>Theory Paper 4 answers and marking</li>
        <li>Theory Paper 5 answers and marking</li>
        <li>Attendance registers for theory sessions</li>
    </ul>
    
    <h3>Practical Assessment (Pages 18-19)</h3>
    <p>Evidence of practical competency:</p>
    <ul style="margin: 10px 0; padding-left: 20px;">
        <li>Trade-specific practical task scripts</li>
        <li>Photographic evidence of work</li>
        <li>Practical assessment rubrics and ratings</li>
        <li>Attendance records</li>
    </ul>
    
    <h3>Workplace Experience (Pages 20-22)</h3>
    <p>Documentation of workplace learning:</p>
    <ul style="margin: 10px 0; padding-left: 20px;">
        <li>Workplace evaluation checklist</li>
        <li>Photographs of work completed</li>
        <li>Supervisor reports and comments</li>
        <li>Attendance register for workplace</li>
    </ul>
    
    <div class="page-number">Pages 21-22 of 24</div>
</div>

<!-- PAGE 23-24: CONCLUSION -->
<div class="page">
    <div class="header-info">
        <span>Assessment Conclusion</span>
        <span>Page 23-24 of 24</span>
    </div>
    
    <h2><span class="section-number">6</span>Portfolio Summary & Assessor Decision</h2>
    
    <h3>Portfolio Completeness</h3>
    <div class="info-box">
        <p><strong>Portfolio Status:</strong> Under Development</p>
        <p><strong>Required Documents:</strong> All appendices and evidence must be compiled</p>
        <p><strong>Next Steps:</strong> Continue uploading assessment evidence and supporting documents</p>
    </div>
    
    <h3>Assessor Verification</h3>
    <table class="table">
        <tr>
            <th>Component</th>
            <th>Status</th>
            <th>Comment</th>
        </tr>
        <tr>
            <td>All Appendices Complete</td>
            <td>Pending</td>
            <td>Awaiting completion</td>
        </tr>
        <tr>
            <td>Evidence Adequate</td>
            <td>Pending</td>
            <td>Assessment ongoing</td>
        </tr>
        <tr>
            <td>Competency Demonstrated</td>
            <td>Pending</td>
            <td>Under review</td>
        </tr>
        <tr>
            <td>Recommendation</td>
            <td>Pending</td>
            <td>Awaiting assessor decision</td>
        </tr>
    </table>
    
    <h3>Notes</h3>
    <p style="border: 1px solid #ddd; padding: 15px; height: 100px; vertical-align: top;">
        (Assessor notes and recommendations to be added)
    </p>
    
    <h3>Final Decision</h3>
    <div style="margin-top: 30px;">
        <p><strong>Decision:</strong> ___________________</p>
        <p><strong>Assessor Name:</strong> ___________________</p>
        <p><strong>Assessor Signature:</strong> ___________________</p>
        <p><strong>Date:</strong> ___________________</p>
    </div>
    
    <div class="page-number">Page 23-24 of 24</div>
</div>

<!-- PAGE 24: BACK PAGE -->
<div class="page" style="display: flex; flex-direction: column; justify-content: flex-end; align-items: center; text-align: center;">
    <h2 style="border: none; margin-bottom: 40px;">ARPL Portfolio Complete</h2>
    
    <p style="font-size: 14px; margin: 20px 0;">
        This portfolio represents the Recognition of Prior Learning assessment<br>
        for {$learner['name']} {$learner['surname']}<br>
        in {$tradeName}
    </p>
    
    <div style="background: #f0f4ff; padding: 20px; border-radius: 8px; margin: 30px 0; width: 80%;">
        <p style="font-size: 12px;">
            <strong>Portfolio Generated:</strong> {$date}<br>
            <strong>Total Pages:</strong> 24<br>
            <strong>Format:</strong> ARPL Assessment Portfolio
        </p>
    </div>
    
    <p style="font-size: 10px; color: #999; margin-top: 40px;">
        End of Portfolio | Page 24 of 24
    </p>
</div>

</body>
</html>
HTML;

    return $html;
}

/**
 * Generate PDF file from HTML content
 */
function generatePDFFile($htmlContent, $learner, $learnerID) {
    try {
        // Create output directory if it doesn't exist
        $outputDir = __DIR__ . '/../pdfs';
        if (!is_dir($outputDir)) {
            mkdir($outputDir, 0755, true);
        }
        
        // Generate filename
        $timestamp = date('Ymd_His');
        $filename = 'ARPL_Portfolio_' . $learnerID . '_' . $timestamp . '.pdf';
        $filepath = $outputDir . '/' . $filename;
        
        // Save HTML to file for conversion
        $htmlFile = $outputDir . '/' . 'temp_' . $learnerID . '_' . $timestamp . '.html';
        file_put_contents($htmlFile, $htmlContent);
        
        // Try to use wkhtmltopdf if available
        $wkhtmltopdf = 'C:\\Program Files\\wkhtmltopdf\\bin\\wkhtmltopdf.exe';
        if (file_exists($wkhtmltopdf)) {
            $command = escapeshellarg($wkhtmltopdf) . ' --quiet ' . escapeshellarg($htmlFile) . ' ' . escapeshellarg($filepath);
            $output = shell_exec($command);
            
            if (file_exists($filepath)) {
                unlink($htmlFile);
                return $filename;
            }
        }
        
        // Fallback: Use PHP to generate a simple PDF-like HTML (can be printed to PDF by browser)
        // Save the HTML file instead for browser-based PDF generation
        file_put_contents($filepath . '.html', $htmlContent);
        
        return $filename . '.html';
        
    } catch (Exception $e) {
        error_log('PDF Generation Error: ' . $e->getMessage());
        return null;
    }
}
?>
