<?php
ob_start();

// Enable error reporting (disable in production)
error_reporting(E_ALL);
ini_set('display_errors', 0); // Set to 1 for debugging
ini_set('log_errors', 1);
ini_set('error_log', 'C:/xampp/php/logs/php_error_log');
use Dompdf\Dompdf;
use Dompdf\Options;

try {
    // Include database connection and Dompdf
    $connection_path = 'connection.php';
    if (!file_exists($connection_path)) {
        throw new Exception('connection.php not found at ' . (realpath($connection_path) ?: $connection_path));
    }
    include $connection_path;

    $autoload_path = 'vendor/autoload.php';
    if (!file_exists($autoload_path)) {
        throw new Exception('vendor/autoload.php not found at ' . (realpath($autoload_path) ?: $autoload_path) . '. Run "composer install"');
    }
    require_once $autoload_path;

    // Database connection
    if (!isset($servername, $username, $password, $dbname)) {
        throw new Exception('Database configuration missing in connection.php');
    }
    $conn = new mysqli($servername, $username, $password, $dbname);
    if ($conn->connect_error) {
        throw new Exception('Connection failed: ' . $conn->connect_error);
    }

    // Validate learner_id
    if (!isset($_GET['learner_id']) || empty(trim($_GET['learner_id']))) {
        throw new Exception('learner_id is required');
    }

    // Sanitize learner_id
    $learner_id = htmlspecialchars($_GET['learner_id'], ENT_QUOTES, 'UTF-8');

    // SQL query to fetch learner and facilitator details
    $sql = "
    SELECT 
        ld.LearnerID,
        ld.name,
        ld.surname,
        ld.IDNumber,
        f.firstName AS facilitator_firstName,
        f.lastName AS facilitator_lastName,
        f.assessorNo,
        f.f_signature,
        f.role AS facilitator_role,
        MAX(m.approval_status) AS approval_status,
        GROUP_CONCAT(DISTINCT CASE WHEN f.role = 'Moderator' THEN m.comment END SEPARATOR '; ') AS moderator_comments,
        GROUP_CONCAT(DISTINCT CASE WHEN f.role = 'Assessor' THEN m.comment END SEPARATOR '; ') AS assessor_comments,
        p.Project_pathway
    FROM learnerdetails ld
    LEFT JOIN facilitator f 
        ON ld.classID = f.classID 
        AND f.role IN ('Assessor', 'Moderator')
    LEFT JOIN class c 
        ON ld.classID = c.classID  
    LEFT JOIN sites s 
        ON c.siteID = s.siteID
    LEFT JOIN project p 
        ON s.project_id = p.project_id
    LEFT JOIN marks m 
        ON m.learnerID = ld.LearnerID
    WHERE ld.LearnerID = ?
    GROUP BY 
        ld.LearnerID,
        ld.name,
        ld.surname,
        ld.IDNumber,
        f.firstName,
        f.lastName,
        f.assessorNo,
        f.f_signature,
        f.role,
        p.Project_pathway
    ORDER BY 
        f.role DESC; -- Prioritize Assessor over Moderator
    ";

    // Prepare and execute statement
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Failed to prepare statement: ' . $conn->error);
    }

    $stmt->bind_param("s", $learner_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result === false) {
        throw new Exception('Error executing query: ' . $stmt->error);
    }

    // Initialize variables
    $learner_name = '';
    $learner_id_display = '';
    $moderator_name = '';
    $moderator_no = '';
    $assessor_name = '';
    $assessor_no = '';
    $qualification = 'Unknown Qualification';
    $unit_standards = [];
    $processed_unit_standards = []; // Track processed us_id
    $date = date('Y-m-d'); // Current date
    $moderator_signature_base64 = '';
    $assessor_signature_base64 = '';
    $assessor_comments = '';
    $moderator_comments = '';

    // Process results
    if ($result->num_rows > 0) {
        $unit_standards_json = null;
        while ($row = $result->fetch_assoc()) {
            // Learner details (take from first row)
            if (empty($learner_name)) {
                $learner_name = htmlspecialchars($row['name'] . ' ' . $row['surname']);
                $learner_id_display = htmlspecialchars($row['IDNumber']);
                $assessor_comments = htmlspecialchars($row['assessor_comments'] ?? '');
                $moderator_comments = htmlspecialchars($row['moderator_comments'] ?? '');
            }

            // Moderator/Assessor details
            if ($row['facilitator_role'] === 'Moderator' && empty($moderator_name)) {
                $moderator_name = htmlspecialchars($row['facilitator_firstName'] . ' ' . $row['facilitator_lastName']);
                $moderator_no = htmlspecialchars($row['assessorNo'] ?? '');
                $moderator_signature = $row['f_signature'];
            } elseif ($row['facilitator_role'] === 'Assessor' && empty($assessor_name)) {
                $assessor_name = htmlspecialchars($row['facilitator_firstName'] . ' ' . $row['facilitator_lastName']);
                $assessor_no = htmlspecialchars($row['assessorNo'] ?? '');
                $assessor_signature = $row['f_signature'];
            }

            // Store Project_pathway (process only once)
            if ($unit_standards_json === null) {
                $unit_standards_json = json_decode($row['Project_pathway'], true);
                if (json_last_error() !== JSON_ERROR_NONE) {
                    error_log("Invalid JSON in Project_pathway for learner $learner_id: " . json_last_error_msg());
                }
            }
        }

        // Extract qualification and unit standards
        if (isset($unit_standards_json[0]['qual_types'][0]['qualification'])) {
            $qualification = htmlspecialchars($unit_standards_json[0]['qual_types'][0]['qualification']['name'] ?? 'Unknown Qualification');
            $unitStandards = $unit_standards_json[0]['qual_types'][0]['qualification']['unitStandards'] ?? [];
        } else {
            error_log("No qualification data found in Project_pathway for learner $learner_id");
        }

        // Process unit standards
        foreach ($unitStandards as $us) {
            if (!isset($us['id'], $us['name'])) {
                error_log("Invalid unit standard data for learner $learner_id: " . json_encode($us));
                continue;
            }
            $us_id = $us['id'];

            // Skip duplicates
            if (in_array($us_id, $processed_unit_standards)) {
                error_log("Skipping duplicate unit standard $us_id for learner $learner_id");
                continue;
            }
            $processed_unit_standards[] = $us_id;

            // Fetch marks for this unit standard
            $us_sql = "
                SELECT 
                    a.exercise AS assessment_exercise,
                    m.exercise AS marks_exercise,
                    a.marks,
                    m.marks_scored,
                    a.assessment_id
                FROM assessments a
                LEFT JOIN marks m 
                    ON TRIM(a.exercise) = TRIM(m.exercise)
                    AND m.learnerID = ?
                WHERE a.unit_standard_id = ?
                    AND a.assessment_type = 'Summative'
            ";
            $us_stmt = $conn->prepare($us_sql);
            if (!$us_stmt) {
                error_log("Prepare failed for unit standard query: " . $conn->error);
                continue;
            }
            $us_stmt->bind_param("ss", $learner_id, $us_id);
            $us_stmt->execute();
            $us_result = $us_stmt->get_result();

            $total_summative_marks_scored = 0;
            $total_summative_possible_marks = 0;
            $assessment_details = [];
            while ($us_row = $us_result->fetch_assoc()) {
                $assessment_details[] = [
                    'assessment_id' => $us_row['assessment_id'],
                    'assessment_exercise' => $us_row['assessment_exercise'],
                    'marks_exercise' => $us_row['marks_exercise'],
                    'marks' => $us_row['marks'],
                    'marks_scored' => $us_row['marks_scored']
                ];
                if ($us_row['marks'] !== null) {
                    $total_summative_possible_marks += (float)$us_row['marks'];
                    $total_summative_marks_scored += (float)($us_row['marks_scored'] ?? 0);
                }
                // Log detailed join info
                error_log("Unit standard $us_id, learner $learner_id: assessment_id=" . ($us_row['assessment_id'] ?? 'NULL') . ", assessment_exercise=" . ($us_row['assessment_exercise'] ?? 'NULL') . ", marks_exercise=" . ($us_row['marks_exercise'] ?? 'NULL') . ", marks=" . ($us_row['marks'] ?? 'NULL') . ", marks_scored=" . ($us_row['marks_scored'] ?? 'NULL'));
            }

            // Log all assessment details for this unit standard
            error_log("Unit standard $us_id, learner $learner_id: assessment_details=" . json_encode($assessment_details));

            $assessor_decision = 'NYC';
            $percentage = 0;
            if ($total_summative_possible_marks > 0) {
                $percentage = ($total_summative_marks_scored / $total_summative_possible_marks) * 100;
                $assessor_decision = ($percentage >= 50) ? 'C' : 'NYC';
            }
            $moderator_decision = $assessor_decision === 'C' ? 'UPHOLD' : 'WITHDRAWN';

            // Log final calculation
            error_log("Unit standard $us_id for learner $learner_id: summative_scored=$total_summative_marks_scored, summative_possible=$total_summative_possible_marks, percentage=$percentage, assessor_decision=$assessor_decision, moderator_decision=$moderator_decision");

            $unit_standards[] = [
                'us_id' => htmlspecialchars($us['id']),
                'us_name' => htmlspecialchars($us['name']),
                'assessor_decision' => $assessor_decision,
                'assessor_comment' => $assessor_comments,
                'moderator_comment' => $moderator_comments,
                'moderator_decision' => $moderator_decision
            ];

            $us_stmt->close();
        }
    } else {
        throw new Exception("No results found for Learner ID $learner_id.");
    }

    // Close statement and connection
    $stmt->close();
    $conn->close();

    // Handle logo with dynamic path
    $base_path = $_SERVER['DOCUMENT_ROOT']; // Gets the root directory of the server (e.g., /public_html/rlms.rlms.co.za)
    $logo_path = $base_path . '/mobile/uploads/MTL.jpeg';
    $logo_base64 = '';
    if (file_exists($logo_path) && is_readable($logo_path)) {
        $logo_data = file_get_contents($logo_path);
        $logo_base64 = base64_encode($logo_data);
    } else {
        error_log("Logo file not found or not readable at: $logo_path");
        $logo_error = "Logo file not found or not readable at: $logo_path";
    }

    // Handle signatures
    $signature_base_dir = 'C:/xampp/htdocs/New/Lito/dist/';
    if (!empty($moderator_signature)) {
        $signature_path = $signature_base_dir . $moderator_signature;
        if (file_exists($signature_path) && is_readable($signature_path)) {
            $signature_data = file_get_contents($signature_path);
            $moderator_signature_base64 = base64_encode($signature_data);
        } else {
            error_log("Moderator signature file not found or not readable at: $signature_path");
            $moderator_signature_error = "Moderator signature file not found or not readable at: $signature_path";
        }
    }

    if (!empty($assessor_signature)) {
        $signature_path = $signature_base_dir . $assessor_signature;
        if (file_exists($signature_path) && is_readable($signature_path)) {
            $signature_data = file_get_contents($signature_path);
            $assessor_signature_base64 = base64_encode($signature_data);
        } else {
            error_log("Assessor signature file not found or not readable at: $signature_path");
            $assessor_signature_error = "Assessor signature file not found or not readable at: $signature_path";
        }
    }

    // Build HTML for PDF
    $html = <<<EOD
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>MODERATION REPORT</title>
        <style>
            body { font-family: Arial, sans-serif; font-size: 9pt; margin: 10px; }
            .header { text-align: center; margin-bottom: 10px; }
            .logo { max-width: 100px; display: block; margin: 0 auto; }
            h1 { text-align: center; font-size: 12pt; margin: 0; }
            h2 { font-size: 10pt; margin-top: 10px; }
            .section { margin-bottom: 10px; }
            .label { font-weight: bold; }
            table { width: 100%; border-collapse: collapse; margin-top: 5px; }
            th, td { border: 1px solid black; padding: 4px; text-align: left; font-size: 8pt; }
            th { background-color: #f2f2f2; }
            .details-table th { width: 25%; }
            .details-table td { width: 75%; }
            .decision-table th:nth-child(1), .decision-table td:nth-child(1) { width: 10%; white-space: nowrap; }
            .decision-table th:nth-child(2), .decision-table td:nth-child(2) { width: 25%; }
            .decision-table th:nth-child(3), .decision-table td:nth-child(3) { width: 10%; white-space: nowrap; }
            .decision-table th:nth-child(4), .decision-table td:nth-child(4) { width: 25%; }
            .decision-table th:nth-child(5), .decision-table td:nth-child(5) { width: 25%; }
            .decision-table th:nth-child(6), .decision-table td:nth-child(6) { width: 10%; white-space: nowrap; }
            .signature { max-width: 100px; margin-top: 5px; }
            .error { color: red; font-size: 7pt; }
        </style>
    </head>
    <body>
        <div class="header">
    EOD;

    if (!empty($logo_base64)) {
        $html .= "<img src=\"data:image/jpeg;base64,$logo_base64\" alt=\"Company Logo\" class=\"logo\">";
    } else {
        $html .= "<p class=\"error\">" . ($logo_error ?? "Logo not available") . "</p>";
    }

    $html .= <<<EOD
        </div>

        <h1>MODERATION REPORT</h1>

        <div class="section">
            <table class="details-table">
                <tr><th>Qualification</th><td>$qualification</td></tr>
                <tr><th>Moderator Name</th><td>$moderator_name</td></tr>
                <tr><th>Moderator No.</th><td>$moderator_no</td></tr>
                <tr><th>Learner Name</th><td>$learner_name</td></tr>
                <tr><th>Learner ID No.</th><td>$learner_id_display</td></tr>
                <tr><th>Assessor Name</th><td>$assessor_name</td></tr>
                <tr><th>Assessor No.</th><td>$assessor_no</td></tr>
            </table>
        </div>

        <div class="section">
            <h2>Moderator Decision</h2>
            <table class="decision-table">
                <tr>
                    <th>US ID</th>
                    <th>UNIT STANDARD/MODULE TITLE</th>
                    <th>ASSESSOR DECISION (C/NYC)</th>
                    <th>ASSESSOR COMMENT</th>
                    <th>MODERATOR COMMENT</th>
                    <th>MODERATOR DECISION</th>
                </tr>
    EOD;

    foreach ($unit_standards as $us) {
        $html .= "<tr>";
        $html .= "<td>" . $us['us_id'] . "</td>";
        $html .= "<td>" . $us['us_name'] . "</td>";
        $html .= "<td>" . $us['assessor_decision'] . "</td>";
        $html .= "<td>" . $us['assessor_comment'] . "</td>";
        $html .= "<td>" . $us['moderator_comment'] . "</td>";
        $html .= "<td>" . $us['moderator_decision'] . "</td>";
        $html .= "</tr>";
    }

    $html .= <<<EOD
            </table>
        </div>

        <div class="section">
            <p><span class="label">Moderator Signature: Moderator No. $moderator_no</span></p>
    EOD;

    if (!empty($moderator_signature_base64)) {
        $html .= "<img src=\"data:image/png;base64,$moderator_signature_base64\" alt=\"Moderator Signature\" class=\"signature\">";
    } else {
        $html .= "<p class=\"error\">No moderator signature available" . (isset($moderator_signature_error) ? " - " . htmlspecialchars($moderator_signature_error) : "") . "</p>";
    }

    $html .= <<<EOD
            <p><span class="label">Date:</span> $date</p>
        </div>

        <div class="section">
            <p><span class="label">Assessor Signature: Assessor No. $assessor_no</span></p>
    EOD;

    if (!empty($assessor_signature_base64)) {
        $html .= "<img src=\"data:image/png;base64,$assessor_signature_base64\" alt=\"Assessor Signature\" class=\"signature\">";
    } else {
        $html .= "<p class=\"error\">No assessor signature available" . (isset($assessor_signature_error) ? " - " . htmlspecialchars($assessor_signature_error) : "") . "</p>";
    }

    $html .= <<<EOD
            <p><span class="label">Date:</span> $date</p>
        </div>
    </body>
    </html>
    EOD;

    // Generate PDF
    $options = new Options();
    $options->set('isHtml5ParserEnabled', true);
    $options->set('isRemoteEnabled', false);
    $options->set('defaultMediaType', 'print');
    $options->set('chroot', $_SERVER['DOCUMENT_ROOT']);

    $dompdf = new Dompdf($options);
    $dompdf->loadHtml($html);
    $dompdf->setPaper('A4', 'landscape');
    $dompdf->render();

    ob_end_clean();
    header('Content-Type: application/pdf');
    header('Content-Disposition: inline; filename="Moderation_of_Assessment_' . preg_replace('/[^A-Za-z0-9_-]/', '_', $learner_id) . '.pdf"');
    echo $dompdf->output();
    exit;

} catch (Exception $e) {
    ob_end_clean();
    error_log('Error in moderation_report.php: ' . $e->getMessage() . ' in ' . $e->getFile() . ' on line ' . $e->getLine());
    header('Content-Type: application/json');
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Server error: ' . htmlspecialchars($e->getMessage())
    ]);
    if (isset($stmt)) {
        $stmt->close();
    }
    if (isset($conn) && $conn->ping()) {
        $conn->close();
    }
    exit;
}
?>