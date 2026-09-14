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

    // Validate learner_id from GET parameter
    if (!isset($_GET['learner_id']) || empty(trim($_GET['learner_id']))) {
        throw new Exception('learner_id is required');
    }

    // Sanitize learner_id
    $learner_id = filter_var($_GET['learner_id'], FILTER_SANITIZE_SPECIAL_CHARS);

    // Prepare SQL query with JSON extraction
    $sql = "
    SELECT 
        ld.LearnerID,
        ld.name,
        ld.surname,
        ld.IDNumber,
        ld.signature,
        f.firstName AS facilitator_firstName,
        f.lastName AS facilitator_lastName,
        f.assessorNo,
        f.f_signature,
        f.facilitator_id,
        f.role AS facilitator_role,
        MAX(m.approval_status) AS approval_status,
        JSON_UNQUOTE(JSON_EXTRACT(p.Project_pathway, '$[0].qual_types[0].qualification.name')) AS qualification_name,
        JSON_EXTRACT(p.Project_pathway, '$[0].qual_types[0].qualification.unitStandards') AS unit_standards_json,
        GROUP_CONCAT(DISTINCT m.a_comment SEPARATOR '; ') AS combined_comments
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
        ld.signature,
        f.firstName,
        f.lastName,
        f.assessorNo,
        f.f_signature,
        f.facilitator_id,
        f.role,
        p.Project_pathway
    ORDER BY 
        f.role DESC; -- Prioritize Assessor over Moderator
    ";

    // Prepare and bind the statement
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

    // Initialize variables for the document
    $learner_name = '';
    $learner_id_display = '';
    $moderator_name = '';
    $moderator_id = '';
    $assessor_name = '';
    $assessor_no = '';
    $qualification = '';
    $unit_standards = [];
    $processed_unit_standards = []; // Track processed us_id
    $date = date('d F Y'); // Dynamic date
    $signature_base64 = '';
    $assessor_signature_base64 = '';

    // Base directories for signatures
    $learner_signature_base_dir = 'mobile/facilitatorSignatures/';
    $assessor_signature_base_dir = '';

    // Process the result
    if ($result->num_rows > 0) {
        $unit_standards_json = null;
        while ($row = $result->fetch_assoc()) {
            // Learner details (take from first row)
            if (empty($learner_name)) {
                $learner_name = htmlspecialchars($row['name'] . ' ' . $row['surname']);
                $learner_id_display = htmlspecialchars($row['IDNumber']);
            }

            // Store learner signature
            if (empty($signature_base64) && !empty($row['signature'])) {
                $signature_path = $learner_signature_base_dir . $row['signature'];
                if (file_exists($signature_path) && is_readable($signature_path)) {
                    $signature_data = file_get_contents($signature_path);
                    $signature_base64 = base64_encode($signature_data);
                } else {
                    error_log("Learner signature file not found or not readable at: $signature_path");
                    $signature_error = "Learner signature file not found or not readable at: $signature_path";
                }
            }

            // Moderator/Assessor details
            if ($row['facilitator_role'] === 'Moderator' && empty($moderator_name)) {
                $moderator_name = htmlspecialchars($row['facilitator_firstName'] . ' ' . $row['facilitator_lastName']);
                $moderator_id = htmlspecialchars($row['facilitator_id']);
            } elseif ($row['facilitator_role'] === 'Assessor' && empty($assessor_name)) {
                $assessor_name = htmlspecialchars($row['facilitator_firstName'] . ' ' . $row['facilitator_lastName']);
                $assessor_no = htmlspecialchars($row['assessorNo'] ?? '');
                if (empty($assessor_signature_base64) && !empty($row['f_signature'])) {
                    $assessor_signature_path = $assessor_signature_base_dir . $row['f_signature'];
                    if (file_exists($assessor_signature_path) && is_readable($assessor_signature_path)) {
                        $assessor_signature_data = file_get_contents($assessor_signature_path);
                        $assessor_signature_base64 = base64_encode($assessor_signature_data);
                    } else {
                        error_log("Assessor signature file not found or not readable at: $assessor_signature_path");
                        $assessor_signature_error = "Assessor signature file not found or not readable at: $assessor_signature_path";
                    }
                }
            }

            // Qualification (take from first row)
            if (empty($qualification)) {
                $qualification = htmlspecialchars($row['qualification_name'] ?? 'Unknown Qualification');
            }

            // Store unit_standards_json (process only once)
            if ($unit_standards_json === null) {
                $unit_standards_json = json_decode($row['unit_standards_json'], true);
            }
        }

        // Process unit standards
        if (is_array($unit_standards_json)) {
            foreach ($unit_standards_json as $us) {
                if (!isset($us['id'], $us['name'])) {
                    error_log("Invalid unit standard data for learner $learner_id: " . json_encode($us));
                    continue;
                }
                $us_id = $us['id'];
                // Skip if already processed
                if (in_array($us_id, $processed_unit_standards)) {
                    error_log("Skipping duplicate unit standard $us_id for learner $learner_id");
                    continue;
                }
                $processed_unit_standards[] = $us_id;

                // Fetch assessment data for this unit standard
                $us_sql = "
                    SELECT 
                        a.exercise AS assessment_exercise,
                        m.exercise AS marks_exercise,
                        a.marks,
                        m.marks_scored,
                        a.assessment_type,
                        m.a_comment
                    FROM assessments a
                    LEFT JOIN marks m 
                        ON TRIM(a.exercise) = TRIM(m.exercise)
                        AND m.learnerID = ?
                    WHERE a.unit_standard_id = ?
                ";
                $us_stmt = $conn->prepare($us_sql);
                if (!$us_stmt) {
                    error_log('Prepare failed for unit standard query: ' . $conn->error);
                    continue;
                }
                $us_stmt->bind_param("ss", $learner_id, $us_id);
                $us_stmt->execute();
                $us_result = $us_stmt->get_result();
                $total_summative_marks_scored = 0;
                $total_summative_possible_marks = 0;
                $total_formative_marks_scored = 0;
                $total_formative_possible_marks = 0;
                $comments = [];
                while ($row = $us_result->fetch_assoc()) {
                    if ($row['marks'] !== null && $row['assessment_type'] === 'Summative') {
                        $total_summative_possible_marks += $row['marks'];
                        $total_summative_marks_scored += $row['marks_scored'] ?? 0;
                    } elseif ($row['marks'] !== null && $row['assessment_type'] === 'Formative') {
                        $total_formative_possible_marks += $row['marks'];
                        $total_formative_marks_scored += $row['marks_scored'] ?? 0;
                    }
                    if (!empty($row['a_comment'])) {
                        $comments[] = $row['a_comment'];
                    }
                    // Log for debugging
                    error_log("Unit standard $us_id, learner $learner_id: assessment_exercise=" . ($row['assessment_exercise'] ?? 'NULL') . ", marks_exercise=" . ($row['marks_exercise'] ?? 'NULL') . ", marks=" . ($row['marks'] ?? 'NULL') . ", marks_scored=" . ($row['marks_scored'] ?? 'NULL') . ", type=" . ($row['assessment_type'] ?? 'NULL'));
                }
                $summative_decision = 'NYC';
                if ($total_summative_possible_marks > 0) {
                    $summative_percentage = ($total_summative_marks_scored / $total_summative_possible_marks) * 100;
                    $summative_decision = ($summative_percentage >= 50) ? 'C' : 'NYC';
                }
                $formative_decision = 'NYC';
                if ($total_formative_possible_marks > 0) {
                    $formative_percentage = ($total_formative_marks_scored / $total_formative_possible_marks) * 100;
                    $formative_decision = ($formative_percentage >= 50) ? 'C' : 'NYC';
                }
                $combined_comments = htmlspecialchars(implode('; ', array_unique($comments)));
                // Log marks for debugging
                error_log("Unit standard $us_id for learner $learner_id: summative_scored=$total_summative_marks_scored, summative_possible=$total_summative_possible_marks, formative_scored=$total_formative_marks_scored, formative_possible=$total_formative_possible_marks, summative_status=$summative_decision, formative_status=$formative_decision");
                $us_stmt->close();

                $unit_standards[] = [
                    'us_id' => htmlspecialchars($us['id']),
                    'us_name' => htmlspecialchars($us['name']),
                    'summative_decision' => $summative_decision,
                    'formative_decision' => $formative_decision,
                    'combined_comments' => $combined_comments
                ];
            }
        } else {
            error_log("Invalid unit standards JSON for learner $learner_id: " . $row['unit_standards_json']);
        }
    } else {
        throw new Exception("No results found for Learner ID $learner_id.");
    }

    // Close the statement and connection
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

    // Start building the HTML for the PDF
    $html = <<<EOD
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Assessor Feedback</title>
    <style>
        body { font-family: Arial, sans-serif; font-size: 12pt; margin: 20px; }
        .header { text-align: center; margin-bottom: 20px; }
        .logo { max-width: 150px; display: block; margin: 0 auto; }
        h1 { text-align: center; font-size: 16pt; margin: 0; }
        h2 { font-size: 14pt; margin-top: 20px; }
        .section { margin-bottom: 20px; }
        .label { font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .details-table th { width: 30%; }
        .details-table td { width: 70%; }
        .error { color: red; font-size: 10pt; }
        .signature { max-width: 150px; }
    </style>
</head>
<body>
    <div class="header">
EOD;

    // Add logo or error message
    if (!empty($logo_base64)) {
        $html .= "<img src=\"data:image/jpeg;base64,$logo_base64\" alt=\"Company Logo\" class=\"logo\">";
    } else {
        $html .= "<p class=\"error\">" . ($logo_error ?? "Logo not available") . "</p>";
    }

    $html .= <<<EOD
    </div>
    <h1>ASSESSOR FEEDBACK</h1>
    <div class="section">
        <table class="details-table">
            <tr><th>Qualification</th><td>$qualification</td></tr>
            <tr><th>Learner Name</th><td>$learner_name</td></tr>
            <tr><th>Learner ID No.</th><td>$learner_id_display</td></tr>
            <tr><th>Assessor Name</th><td>$assessor_name : Assessor No. $assessor_no</td></tr>
        </table>
    </div>
    <div class="section">
        <h2>ASSESSOR DECISION</h2>
        <table>
            <tr>
                <th>US ID</th>
                <th>UNIT STANDARD/MODULE TITLE</th>
                <th>FORMATIVE ASSESSMENT(C/NYC)</th>
                <th>SUMMATIVE ASSESSMENT(C/NYC)</th>
                <th>COMMENT</th>
                <th>ASSESSOR DECISION</th>
            </tr>
EOD;

    // Add unit standards to the table
    foreach ($unit_standards as $us) {
        $assessor_decision = $us['summative_decision']; // Assessor decision mirrors summative decision
        $html .= "<tr>";
        $html .= "<td>" . $us['us_id'] . "</td>";
        $html .= "<td>" . $us['us_name'] . "</td>";
        $html .= "<td>" . $us['formative_decision'] . "</td>";
        $html .= "<td>" . $us['summative_decision'] . "</td>";
        $html .= "<td>" . $us['combined_comments'] . "</td>";
        $html .= "<td>" . $assessor_decision . "</td>";
        $html .= "</tr>";
    }

    $html .= <<<EOD
        </table>
    </div>
    <div class="section">
        <table style="width: 100%;">
            <tr>
                <td style="width: 50%;">
                    <p><span class="label">Assessor Signature: Assessor No. $assessor_no</span></p>
EOD;

    // Add assessor signature if available
    if (!empty($assessor_signature_base64)) {
        $html .= "<img src=\"data:image/png;base64,$assessor_signature_base64\" alt=\"Assessor Signature\" class=\"signature\">";
    } else {
        $html .= "<p class=\"error\">No assessor signature available" . (isset($assessor_signature_error) ? " - " . htmlspecialchars($assessor_signature_error) : "") . "</p>";
    }

    $html .= <<<EOD
                    <p><span class="label">Date:</span> $date</p>
                </td>
                <td style="width: 50%;">
                    <p><span class="label">Learner Signature:</span></p>
EOD;

    // Add learner signature if available
    if (!empty($signature_base64)) {
        $html .= "<img src=\"data:image/png;base64,$signature_base64\" alt=\"Learner Signature\" class=\"signature\">";
    } else {
        $html .= "<p class=\"error\">No learner signature available" . (isset($signature_error) ? " - " . htmlspecialchars($signature_error) : "") . "</p>";
    }

    $html .= <<<EOD
                </td>
            </tr>
        </table>
    </div>
</body>
</html>
EOD;

    // Initialize Dompdf
    $options = new Options();
    $options->set('isHtml5ParserEnabled', true);
    $options->set('isRemoteEnabled', false);
    $options->set('defaultMediaType', 'print');
    $options->set('chroot', $_SERVER['DOCUMENT_ROOT']);

    $dompdf = new Dompdf($options);
    $dompdf->loadHtml($html);
    $dompdf->setPaper('A4', 'landscape');
    $dompdf->render();

    // Output PDF
    ob_end_clean();
    header('Content-Type: application/pdf');
    header('Content-Disposition: inline; filename="Assessor_Feedback_' . preg_replace('/[^A-Za-z0-9_-]/', '_', $learner_id) . '.pdf"');
    echo $dompdf->output();
    exit;

} catch (Exception $e) {
    ob_end_clean();
    error_log('Error in assessor_feedback.php: ' . $e->getMessage() . ' in ' . $e->getFile() . ' on line ' . $e->getLine());
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