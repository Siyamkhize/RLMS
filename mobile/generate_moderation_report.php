<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json'); // Default to JSON for debugging
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

    // Get class_id from GET parameter
    $class_id = $_GET['class_id'] ?? null;
    if (!$class_id || !is_numeric($class_id)) {
        throw new Exception('Invalid or missing Class ID.');
    }
    error_log("Received class_id: $class_id");

    // Function to get class details
    function getClassDetails($class_id, $conn) {
        $stmt = $conn->prepare("SELECT className FROM class WHERE classID = ?");
        if (!$stmt) {
            error_log("Prepare failed in getClassDetails: " . $conn->error);
            return ['className' => 'Unknown Class'];
        }
        $stmt->bind_param("i", $class_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $classData = $result->fetch_assoc();
        $stmt->close();
        return $classData ?: ['className' => 'Unknown Class'];
    }

    // Function to get moderator details
    function getModeratorDetails($class_id, $conn) {
        error_log("Fetching moderator details for classID: $class_id");
        $stmt = $conn->prepare("
            SELECT f.firstName, f.lastName, f.assessorNo, f.f_signature 
            FROM facilitator f 
            WHERE f.classID = ? AND f.role = 'Moderator'
            LIMIT 1
        ");
        if (!$stmt) {
            error_log("Prepare failed in getModeratorDetails: " . $conn->error);
            return ['firstName' => 'Unknown', 'lastName' => 'Moderator', 'assessorNo' => 'Unknown', 'f_signature' => ''];
        }
        $stmt->bind_param("i", $class_id);
        if (!$stmt->execute()) {
            error_log("Execution failed in getModeratorDetails: " . $stmt->error);
            $stmt->close();
            return ['firstName' => 'Unknown', 'lastName' => 'Moderator', 'assessorNo' => 'Unknown', 'f_signature' => ''];
        }
        $result = $stmt->get_result();
        $moderatorData = $result->fetch_assoc();
        $stmt->close();
        if (!$moderatorData) {
            error_log("No moderator found for classID: $class_id");
            return ['firstName' => 'Unknown', 'lastName' => 'Moderator', 'assessorNo' => 'Unknown', 'f_signature' => ''];
        }
        error_log("Moderator data retrieved: " . json_encode($moderatorData));
        return $moderatorData;
    }

    // Get class and moderator details
    $classDetails = getClassDetails($class_id, $conn);
    $moderatorDetails = getModeratorDetails($class_id, $conn);

    // SQL query to fetch learner details and Project_pathway
    $sql = "
    SELECT 
        ld.LearnerID,
        ld.name,
        ld.surname,
        ld.IDNumber,
        p.Project_pathway
    FROM learnerdetails ld
    LEFT JOIN class c ON ld.classID = c.classID
    LEFT JOIN sites s ON c.siteID = s.siteID
    LEFT JOIN project p ON s.project_id = p.project_id
    WHERE c.classID = ?
    GROUP BY ld.LearnerID, ld.name, ld.surname, ld.IDNumber, p.Project_pathway
    ORDER BY ld.LearnerID
    ";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }
    $stmt->bind_param('i', $class_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        throw new Exception("No data found for Class ID: $class_id");
    }

    $learners = [];
    $qualificationName = 'Unknown Qualification';
    $unitStandards = [];

    // Process JSON data to extract qualification and unit standards
    $firstRow = $result->fetch_assoc();
    if (!empty($firstRow['Project_pathway'])) {
        $projectPathway = json_decode($firstRow['Project_pathway'], true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            error_log("Invalid JSON in Project_pathway for classID $class_id: " . json_last_error_msg());
        } elseif (isset($projectPathway[0]['qual_types'][0]['qualification'])) {
            $qualificationName = $projectPathway[0]['qual_types'][0]['qualification']['name'] ?? 'Unknown Qualification';
            $unitStandards = $projectPathway[0]['qual_types'][0]['qualification']['unitStandards'] ?? [];
        }
    }

    // Reset result pointer to process all rows
    $result->data_seek(0);

    while ($row = $result->fetch_assoc()) {
        $learnerKey = $row['LearnerID'];
        if (!isset($learners[$learnerKey])) {
            $learners[$learnerKey] = [
                'surname' => $row['surname'],
                'name' => $row['name'],
                'IDNumber' => $row['IDNumber'],
                'unitStandards' => []
            ];
        }

        // Calculate competency status for each unit standard
        foreach ($unitStandards as $unitStandard) {
            if (!isset($unitStandard['id'])) {
                error_log("Invalid unit standard data for learner $learnerKey: " . json_encode($unitStandard));
                continue;
            }
            $us_id = $unitStandard['id'];

            // Fetch marks for this unit standard and learner
            $us_sql = "
                SELECT 
                    a.exercise AS assessment_exercise,
                    m.exercise AS marks_exercise,
                    a.marks,
                    m.marks_scored
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
            $us_stmt->bind_param("ss", $learnerKey, $us_id);
            $us_stmt->execute();
            $us_result = $us_stmt->get_result();

            $total_marks_scored = 0;
            $total_marks_possible = 0;
            while ($us_row = $us_result->fetch_assoc()) {
                if ($us_row['marks'] !== null) {
                    $total_marks_possible += $us_row['marks'];
                    $total_marks_scored += $us_row['marks_scored'] ?? 0;
                }
                // Log for debugging
                error_log("Unit standard $us_id, learner $learnerKey: assessment_exercise=" . ($us_row['assessment_exercise'] ?? 'NULL') . ", marks_exercise=" . ($us_row['marks_exercise'] ?? 'NULL') . ", marks=" . ($us_row['marks'] ?? 'NULL') . ", marks_scored=" . ($us_row['marks_scored'] ?? 'NULL'));
            }

            $competency_status = 'WITHDRAWN';
            if ($total_marks_possible > 0) {
                $percentage = ($total_marks_scored / $total_marks_possible) * 100;
                $competency_status = ($percentage >= 50) ? 'APPROVED' : 'WITHDRAWN';
            }

            // Log competency calculation
            error_log("Unit standard $us_id for learner $learnerKey: scored=$total_marks_scored, possible=$total_marks_possible, status=$competency_status");

            $learners[$learnerKey]['unitStandards'][] = [
                'unitstandard_id' => $us_id,
                'competency_status' => $competency_status,
                'date' => date('Y-m-d')
            ];

            $us_stmt->close();
        }
    }

    // Close statement
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
        $logo_error = "Logo file not found or not readable at: $logo_path";
        error_log($logo_error);
    }

    // Handle moderator signature
    $signature_base_dir = 'C:/xampp/htdocs/New/Lito/dist/';
    $moderator_signature_base64 = '';
    if (!empty($moderatorDetails['f_signature'])) {
        $signature_path = $signature_base_dir . $moderatorDetails['f_signature'];
        error_log("Checking signature path: $signature_path");
        if (file_exists($signature_path) && is_readable($signature_path)) {
            $signature_data = file_get_contents($signature_path);
            $moderator_signature_base64 = base64_encode($signature_data);
        } else {
            $moderator_signature_error = "Moderator signature file not found or not readable at: $signature_path";
            error_log($moderator_signature_error);
        }
    }

    // Generate HTML content for the PDF
    $html = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Class Report</title>';
    $html .= '<style>
        body { font-family: Arial, sans-serif; font-size: 12pt; margin: 20px; }
        h1 { text-align: center; margin-top: 20px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid black; padding: 5px; text-align: left; }
        th { background-color: #f2f2f2; }
        .signature { max-width: 150px; }
        .error { color: red; font-size: 10pt; }
        header { text-align: center; padding-bottom: 20px; border-bottom: 2px solid #000; margin-bottom: 20px; }
        .logo { max-width: 200px; display: block; margin: 0 auto; }
    </style></head><body>';

    // Add logo as header
    $html .= '<header>';
    if (!empty($logo_base64)) {
        $html .= "<img src=\"data:image/jpeg;base64,$logo_base64\" alt=\"Company Logo\" class=\"logo\">";
    } else {
        $html .= "<p class=\"error\">" . ($logo_error ?? "Logo not available") . "</p>";
    }
    $html .= '</header>';

    $html .= '<h1>CLASS REPORT</h1>';
    $html .= "<p>Class Name: " . htmlspecialchars($classDetails['className']) . "</p>";
    $html .= "<p>Qualification Name: " . htmlspecialchars($qualificationName) . "</p>";
    $html .= "<p>Moderator Name: " . htmlspecialchars($moderatorDetails['firstName'] . ' ' . $moderatorDetails['lastName']) . "</p>";
    $html .= "<p>Moderator No.: " . htmlspecialchars($moderatorDetails['assessorNo']) . "</p>";
    $html .= '<table border="1" cellpadding="5" cellspacing="0">';
    $html .= '<tr><th>NO</th><th>SURNAME</th><th>NAME</th><th>ID NO</th>';

    // Dynamically add unit standard columns
    $maxUnitStandards = count($unitStandards);
    for ($i = 1; $i <= $maxUnitStandards; $i++) {
        $html .= "<th>U/S ID $i</th><th>DATE $i</th><th>C/NYC $i</th>";
    }
    $html .= '</tr>';

    $counter = 1;
    foreach ($learners as $learnerID => $learner) {
        if ($counter > 15) break; // Limit to 15 learners per page

        $html .= '<tr>';
        $html .= "<td>$counter</td>";
        $html .= "<td>" . htmlspecialchars($learner['surname']) . "</td>";
        $html .= "<td>" . htmlspecialchars($learner['name']) . "</td>";
        $html .= "<td>" . htmlspecialchars($learner['IDNumber']) . "</td>";

        $unitCount = count($learner['unitStandards']);
        for ($i = 0; $i < $maxUnitStandards; $i++) {
            if ($i < $unitCount) {
                $html .= "<td>" . htmlspecialchars($learner['unitStandards'][$i]['unitstandard_id']) . "</td>";
                $html .= "<td>" . htmlspecialchars($learner['unitStandards'][$i]['date']) . "</td>";
                $html .= "<td>" . htmlspecialchars($learner['unitStandards'][$i]['competency_status']) . "</td>";
            } else {
                $html .= '<td></td><td></td><td></td>';
            }
        }
        $html .= '</tr>';
        $counter++;
    }
    $html .= '</table>';
    $html .= "<p><strong>Moderator Signature: Moderator No. " . htmlspecialchars($moderatorDetails['assessorNo']) . "</strong></p>";
    if (!empty($moderator_signature_base64)) {
        $html .= "<img src=\"data:image/png;base64,$moderator_signature_base64\" alt=\"Moderator Signature\" class=\"signature\">";
    } else {
        $html .= "<p class=\"error\">No moderator signature available" . (isset($moderator_signature_error) ? " - " . htmlspecialchars($moderator_signature_error) : "") . "</p>";
    }
    $html .= "<p>DATE: " . date('Y-m-d') . "</p>";
    $html .= '</body></html>';

    // Save HTML for debugging
    file_put_contents('debug.html', $html);

    // Generate PDF using dompdf
    $options = new Options();
    $options->set('isHtml5ParserEnabled', true);
    $options->set('isRemoteEnabled', false);
    $options->set('defaultMediaType', 'print');
    $options->set('chroot', $_SERVER['DOCUMENT_ROOT']);

    $dompdf = new Dompdf($options);
    $dompdf->loadHtml($html);
    $dompdf->setPaper('A4', 'landscape');
    $dompdf->render();

    // Output the PDF
    ob_end_clean();
    header('Content-Type: application/pdf');
    header('Content-Disposition: attachment; filename="Class_' . preg_replace('/[^A-Za-z0-9_-]/', '_', $class_id) . '_Report.pdf"');
    echo $dompdf->output();
    exit;

} catch (Exception $e) {
    ob_end_clean();
    error_log('Error in class_report.php: ' . $e->getMessage() . ' in ' . $e->getFile() . ' on line ' . $e->getLine());
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