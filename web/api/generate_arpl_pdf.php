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
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            text-align: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .cover-page h1 {
            font-size: 48px;
            margin: 20px 0;
            font-weight: bold;
        }
        .cover-page .trade-section {
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 10px;
            margin: 30px 0;
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
            margin-top: 40px;
            background: rgba(255,255,255,0.15);
            padding: 20px;
            border-radius: 8px;
        }
        .learner-info-cover p {
            font-size: 14px;
            margin: 10px 0;
        }
        .cover-page .footer {
            margin-top: auto;
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
    <div style="margin-bottom: auto;"></div>
    
    <h1>ARPL PORTFOLIO</h1>
    <p style="font-size: 20px; opacity: 0.9;">Recognition of Prior Learning</p>
    
    <div class="trade-section">
        <p style="font-size: 14px; opacity: 0.9; margin: 0;">Qualification</p>
        <div class="trade-name">{$tradeName}</div>
        <p class="trade-code">NQF Level 4 | OFO Code: {$ofo_code}</p>
    </div>
    
    <div class="learner-info-cover">
        <p><strong>Learner Name:</strong> {$learner['name']} {$learner['surname']}</p>
        <p><strong>Learner ID:</strong> {$learnerID}</p>
        <p><strong>ID Number:</strong> {$learner['idNumber']}</p>
        <p><strong>Portfolio Generated:</strong> {$date}</p>
    </div>
    
    <div style="margin-top: auto;"></div>
    <div class="footer">
        <p>This portfolio documents evidence of learning and competency</p>
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
        <span>Appendix B: Theory Assessment Activities</span>
        <span>Pages 7-8 of 24</span>
    </div>
    
    <h2><span class="section-number">A</span>Appendix B: Theory Assessment Activities</h2>
    
    <div class="info-box">
        <strong>Theory Competency Assessment</strong>
        <p>The following theory assessment activities have been completed for the {$tradeName} qualification:</p>
    </div>
    
HTML;

    if (count($theoryActivities) > 0) {
        $html .= "<table class='table' style='font-size: 10px;'>";
        $html .= "<tr><th>Activity #</th><th>Activity Name</th><th>Competency Scale</th><th>Assessment Date</th></tr>";
        foreach ($theoryActivities as $activity) {
            $actNum = isset($activity['activity_number']) ? $activity['activity_number'] : '';
            $actName = isset($activity['activity_name']) ? htmlspecialchars($activity['activity_name']) : 'N/A';
            $rating = isset($activity['competency_scale_id']) && $activity['competency_scale_id'] ? $activity['competency_scale_id'] : 'Pending';
            $date = isset($activity['rating_date']) && $activity['rating_date'] ? $activity['rating_date'] : 'Not Assessed';
            $html .= "<tr>";
            $html .= "<td>$actNum</td>";
            $html .= "<td>$actName</td>";
            $html .= "<td>$rating</td>";
            $html .= "<td>$date</td>";
            $html .= "</tr>";
        }
        $html .= "</table>";
    } else {
        $html .= "<div class='info-box'><p><em>No theory assessment activities have been recorded yet.</em></p></div>";
    }

    $html .= <<<HTML
    
    <div class="page-number">Pages 7-8 of 24</div>
</div>

<!-- PAGE 9-10: APPENDIX E (WORKPLACE ACTIVITIES) - TRADE-SPECIFIC -->
<div class="page">
    <div class="header-info">
        <span>Appendix E: Workplace Assessment Activities</span>
        <span>Pages 9-10 of 24</span>
    </div>
    
    <h2><span class="section-number">B</span>Appendix E: Workplace Assessment Activities</h2>
    
    <div class="info-box">
        <strong>Workplace Experience & Assessment</strong>
        <p>The following workplace assessment activities document the learner's competency in the work environment:</p>
    </div>
    
HTML;

    if (count($workplaceActivities) > 0) {
        $html .= "<table class='table' style='font-size: 10px;'>";
        $html .= "<tr><th>Activity #</th><th>Activity Name</th><th>Competency Scale</th><th>Assessment Date</th></tr>";
        foreach ($workplaceActivities as $activity) {
            $actNum = isset($activity['activity_number']) ? $activity['activity_number'] : '';
            $actName = isset($activity['activity_name']) ? htmlspecialchars($activity['activity_name']) : 'N/A';
            $rating = isset($activity['competency_scale_id']) && $activity['competency_scale_id'] ? $activity['competency_scale_id'] : 'Pending';
            $date = isset($activity['rating_date']) && $activity['rating_date'] ? $activity['rating_date'] : 'Not Assessed';
            $html .= "<tr>";
            $html .= "<td>$actNum</td>";
            $html .= "<td>$actName</td>";
            $html .= "<td>$rating</td>";
            $html .= "<td>$date</td>";
            $html .= "</tr>";
        }
        $html .= "</table>";
    } else {
        $html .= "<div class='info-box'><p><em>No workplace assessment activities have been recorded yet.</em></p></div>";
    }

    $html .= <<<HTML
    
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
        <strong>Assessor Recommendation for ARPL Access</strong>
        <p>Based on the evidence of prior learning and assessment results, the following recommendation is made:</p>
    </div>
    
HTML;

    if ($accessRecommendation) {
        $html .= "<table class='table'>";
        $html .= "<tr><th>Field</th><th>Value</th></tr>";
        $html .= "<tr><td>Trade</td><td>" . htmlspecialchars($accessRecommendation['Trade'] ?? 'N/A') . "</td></tr>";
        $html .= "<tr><td>OFO Code</td><td>" . htmlspecialchars($accessRecommendation['OFOCode'] ?? 'N/A') . "</td></tr>";
        $html .= "<tr><td>ACR ID</td><td>" . htmlspecialchars($accessRecommendation['ACRID'] ?? 'N/A') . "</td></tr>";
        $html .= "<tr><td>Status</td><td><strong>" . htmlspecialchars($accessRecommendation['Status'] ?? 'Not Set') . "</strong></td></tr>";
        if (isset($accessRecommendation['Remarks']) && !empty($accessRecommendation['Remarks'])) {
            $html .= "<tr><td>Remarks</td><td>" . nl2br(htmlspecialchars($accessRecommendation['Remarks'])) . "</td></tr>";
        }
        $html .= "</table>";
    } else {
        $html .= "<div class='info-box'><p><em>No access recommendation has been recorded yet.</em></p></div>";
    }

    $html .= <<<HTML
    
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
HTML;

    if (!empty($appendixA)) {
        $html .= "<p><strong>Applicant Details:</strong></p>";
        if (isset($appendixA['postal_address1'])) {
            $html .= "<p>Address: " . htmlspecialchars($appendixA['postal_address1']) . "</p>";
        }
        if (isset($appendixA['current_employer'])) {
            $html .= "<p><strong>Current Employment:</strong> " . htmlspecialchars($appendixA['current_employer']) . "</p>";
        }
        if (isset($appendixA['position_job_title'])) {
            $html .= "<p><strong>Position:</strong> " . htmlspecialchars($appendixA['position_job_title']) . "</p>";
        }
        if (isset($appendixA['employment_history'])) {
            $html .= "<p><strong>Employment History:</strong> " . htmlspecialchars($appendixA['employment_history']) . "</p>";
        }
    } else {
        $html .= "<p><em>No application form data found. Please complete in system.</em></p>";
    }
    
    $html .= <<<HTML
    </div>
    
    <!-- APPENDIX C: CURRICULUM CONTENT -->
    <h3>Appendix C: Trade Curriculum Content</h3>
    <div class="info-box">
HTML;

    if (!empty($appendixC)) {
        if (isset($appendixC['curriculum_overview'])) {
            $html .= "<p><strong>Curriculum Overview:</strong></p>";
            $html .= "<p>" . nl2br(htmlspecialchars($appendixC['curriculum_overview'])) . "</p>";
        }
        if (isset($appendixC['learning_outcomes'])) {
            $html .= "<p><strong>Learning Outcomes:</strong></p>";
            $html .= "<p>" . nl2br(htmlspecialchars($appendixC['learning_outcomes'])) . "</p>";
        }
    } else {
        $html .= "<p><em>Curriculum content to be entered in system.</em></p>";
    }
    
    $html .= <<<HTML
    </div>
    
    <!-- APPENDIX D: PRACTICAL SKILLS CHECKLIST -->
    <h3>Appendix D: Practical Skills Assessment (22 Activities)</h3>
    <div class="info-box">
        <table class="table" style="font-size: 10px;">
            <tr>
                <th>Activity</th>
                <th>Status</th>
                <th>Activity</th>
                <th>Status</th>
            </tr>
HTML;

    if (!empty($appendixD)) {
        $activities = formatActivityResponse($appendixD);
        for ($i = 1; $i <= 22; $i += 2) {
            $status1 = isset($activities[$i]) ? $activities[$i] : 'Pending';
            $status2 = isset($activities[$i+1]) ? $activities[$i+1] : 'Pending';
            $html .= "<tr>";
            $html .= "<td>Activity $i</td>";
            $html .= "<td>" . $status1 . "</td>";
            if ($i + 1 <= 22) {
                $html .= "<td>Activity " . ($i+1) . "</td>";
                $html .= "<td>" . $status2 . "</td>";
            }
            $html .= "</tr>";
        }
    } else {
        $html .= "<tr><td colspan='4'><em>Practical skills assessment to be completed.</em></td></tr>";
    }
    
    $html .= <<<HTML
        </table>
    </div>
    
    <!-- APPENDIX F: ASSESSMENT EVALUATION AGREEMENT -->
    <h3>Appendix F: Assessment Evaluation Agreement</h3>
    <div class="info-box">
HTML;

    if (!empty($appendixF)) {
        $html .= "<p><strong>Assessment Acknowledgements:</strong></p>";
        $html .= "<ul>";
        $html .= "<li>Knowledge Assessment: " . (isset($appendixF['knowledge_acknowledged']) ? ucfirst($appendixF['knowledge_acknowledged']) : 'Not Set') . "</li>";
        $html .= "<li>Practical Assessment: " . (isset($appendixF['practical_acknowledged']) ? ucfirst($appendixF['practical_acknowledged']) : 'Not Set') . "</li>";
        $html .= "<li>Workplace Experience: " . (isset($appendixF['workplace_acknowledged']) ? ucfirst($appendixF['workplace_acknowledged']) : 'Not Set') . "</li>";
        $html .= "<li>Assessor Acknowledged: " . (isset($appendixF['assessor_acknowledged']) ? ucfirst($appendixF['assessor_acknowledged']) : 'Not Set') . "</li>";
        $html .= "</ul>";
        if (isset($appendixF['agreement_date'])) {
            $html .= "<p><strong>Agreement Date:</strong> " . htmlspecialchars($appendixF['agreement_date']) . "</p>";
        }
    } else {
        $html .= "<p><em>Assessment agreement to be completed and signed.</em></p>";
    }
    
    $html .= <<<HTML
    </div>
    
    <!-- APPENDIX G: APPEALS FORM -->
    <h3>Appendix G: Appeals & Feedback</h3>
    <div class="info-box">
HTML;

    if (!empty($appendixG)) {
        $html .= "<p><strong>Appeal Status:</strong> " . (isset($appendixG['appeal_status']) ? htmlspecialchars($appendixG['appeal_status']) : 'None') . "</p>";
        if (isset($appendixG['grounds_for_appeal']) && !empty($appendixG['grounds_for_appeal'])) {
            $html .= "<p><strong>Grounds for Appeal:</strong></p>";
            $html .= "<p>" . nl2br(htmlspecialchars($appendixG['grounds_for_appeal'])) . "</p>";
        }
        if (isset($appendixG['assessor_findings']) && !empty($appendixG['assessor_findings'])) {
            $html .= "<p><strong>Assessor Findings:</strong></p>";
            $html .= "<p>" . nl2br(htmlspecialchars($appendixG['assessor_findings'])) . "</p>";
        }
    } else {
        $html .= "<p><em>No appeals submitted. Learner feedback to be recorded here if applicable.</em></p>";
    }
    
    $html .= <<<HTML
    </div>
    
    <!-- APPENDIX I: STATEMENT OF RESULTS -->
    <h3>Appendix I: Statement of Results</h3>
    <div class="info-box">
HTML;

    if (!empty($appendixI)) {
        $html .= "<table class='table'>";
        $html .= "<tr><th>Assessment Component</th><th>Result</th></tr>";
        $html .= "<tr><td>Knowledge Assessment</td><td>" . (isset($appendixI['knowledge_result']) ? htmlspecialchars($appendixI['knowledge_result']) : 'Pending') . "</td></tr>";
        $html .= "<tr><td>Practical Assessment</td><td>" . (isset($appendixI['practical_result']) ? htmlspecialchars($appendixI['practical_result']) : 'Pending') . "</td></tr>";
        $html .= "<tr><td>Workplace Experience</td><td>" . (isset($appendixI['workplace_result']) ? htmlspecialchars($appendixI['workplace_result']) : 'Pending') . "</td></tr>";
        $html .= "</table>";
        
        if (isset($appendixI['overall_competency_rating'])) {
            $html .= "<p><strong>Overall Competency Rating:</strong> " . htmlspecialchars($appendixI['overall_competency_rating']) . "/5</p>";
        }
        if (isset($appendixI['assessor_name'])) {
            $html .= "<p><strong>Assessor:</strong> " . htmlspecialchars($appendixI['assessor_name']) . "</p>";
        }
        if (isset($appendixI['certification_date'])) {
            $html .= "<p><strong>Certification Date:</strong> " . htmlspecialchars($appendixI['certification_date']) . "</p>";
        }
    } else {
        $html .= "<p><em>Results to be entered upon assessment completion.</em></p>";
    }
    
    $html .= <<<HTML
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
