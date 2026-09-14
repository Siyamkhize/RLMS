<?php
// Ensure no output before headers
ob_start();

// Enable error reporting
error_reporting(E_ALL);
ini_set('display_errors', 0); // Set to 1 for debugging
ini_set('log_errors', 1);
ini_set('error_log', $_SERVER['DOCUMENT_ROOT'] . '/logs/php_error_log');

use Dompdf\Dompdf;
use Dompdf\Options;

try {
    // Verify connection.php
    $connection_path = 'connection.php';
    if (!file_exists($connection_path)) {
        throw new Exception('connection.php not found at ' . (realpath($connection_path) ?: $connection_path));
    }
    require_once $connection_path;

    // Verify autoloader
    $autoload_path = 'vendor/autoload.php';
    if (!file_exists($autoload_path)) {
        throw new Exception('vendor/autoload.php not found at ' . (realpath($autoload_path) ?: $autoload_path) . '. Run "composer install"');
    }
    require_once $autoload_path;

    // Set default content type
    header('Content-Type: application/json; charset=UTF-8');

    // Database connection
    if (!isset($servername, $username, $password, $dbname)) {
        throw new Exception('Database configuration missing in connection.php');
    }
    $conn = new mysqli($servername, $username, $password, $dbname);
    if ($conn->connect_error) {
        throw new Exception('Connection failed: ' . $conn->connect_error);
    }

    // Get facilitator_id
    $facilitator_id = $_GET['facilitator_id'] ?? null;
    if (!$facilitator_id) {
        throw new Exception('Facilitator ID not provided');
    }

    // Function to get user details
    function getUserDetails($facilitator_id, $conn) {
        $stmt = $conn->prepare('SELECT firstName, lastName, assessorNo, f_signature FROM facilitator WHERE facilitator_id = ?');
        if (!$stmt) {
            throw new Exception('Prepare failed for user details: ' . $conn->error);
        }
        $stmt->bind_param('s', $facilitator_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();
        $stmt->close();
        return $user ?: ['firstName' => 'Unknown', 'lastName' => 'Assessor', 'assessorNo' => 'Unknown', 'f_signature' => ''];
    }

    $userDetails = getUserDetails($facilitator_id, $conn);
    $assessorNo = $userDetails['assessorNo'];
    error_log('f_signature value: ' . ($userDetails['f_signature'] ?? 'NULL'));

    // SQL query to fetch learner details and project pathway
    $sql = '
        SELECT 
            ld.LearnerID,
            ld.name,
            ld.surname,
            ld.IDNumber,
            c.classID,
            p.Project_pathway
        FROM learnerdetails ld
        LEFT JOIN class c ON ld.classID = c.classID
        LEFT JOIN sites s ON c.siteID = s.siteID
        LEFT JOIN project p ON s.project_id = p.project_id
        LEFT JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID)
        WHERE f.facilitator_id = ?
        GROUP BY ld.LearnerID, ld.name, ld.surname, ld.IDNumber, c.classID, p.Project_pathway
        ORDER BY ld.LearnerID';

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }
    $stmt->bind_param('s', $facilitator_id);
    if (!$stmt->execute()) {
        throw new Exception('Query execution failed: ' . $stmt->error);
    }
    $result = $stmt->get_result();

    // Log query results for debugging
    error_log("Query executed for facilitator_id=$facilitator_id, rows returned: " . $result->num_rows);

    if ($result->num_rows === 0) {
        // Additional debugging: Check facilitator and classID
        $check_facilitator = $conn->prepare('SELECT classID FROM facilitator WHERE facilitator_id = ?');
        $check_facilitator->bind_param('s', $facilitator_id);
        $check_facilitator->execute();
        $fac_result = $check_facilitator->get_result();
        $fac_data = $fac_result->fetch_assoc();
        error_log("Facilitator check: " . json_encode($fac_data));
        $check_facilitator->close();
        throw new Exception('No data found for Facilitator ID: ' . htmlspecialchars($facilitator_id));
    }

    $learners = [];
    $qualificationName = 'Unknown Qualification';

    // Process results and parse JSON
    while ($row = $result->fetch_assoc()) {
        $learnerKey = $row['LearnerID'];
        $pathwayData = !empty($row['Project_pathway']) ? json_decode($row['Project_pathway'], true) : [];
        if (json_last_error() !== JSON_ERROR_NONE) {
            error_log('Invalid JSON in Project_pathway for classID ' . ($row['classID'] ?? 'unknown') . ': ' . json_last_error_msg());
            continue;
        }

        // Extract qualification name
        if ($qualificationName === 'Unknown Qualification') {
            foreach ($pathwayData as $pathway) {
                if (isset($pathway['qual_types']) && is_array($pathway['qual_types'])) {
                    foreach ($pathway['qual_types'] as $qualType) {
                        if (isset($qualType['qualification']['name'])) {
                            $qualificationName = $qualType['qualification']['name'];
                            break 2;
                        }
                    }
                }
            }
        }

        // Initialize learner
        if (!isset($learners[$learnerKey])) {
            $learners[$learnerKey] = [
                'surname' => $row['surname'] ?? 'Unknown',
                'name' => $row['name'] ?? 'Unknown',
                'IDNumber' => $row['IDNumber'] ?? 'Unknown',
                'unitStandards' => []
            ];
        }

        // Extract unit standards and calculate competency status
        $unitStandards = [];
        foreach ($pathwayData as $pathway) {
            if (isset($pathway['qual_types']) && is_array($pathway['qual_types'])) {
                foreach ($pathway['qual_types'] as $qualType) {
                    if (isset($qualType['qualification']['unitStandards']) && is_array($qualType['qualification']['unitStandards'])) {
                        foreach ($qualType['qualification']['unitStandards'] as $unitStandard) {
                            if (isset($unitStandard['id'], $unitStandard['name'])) {
                                // Fetch marks for this unit standard
                                $us_id = $unitStandard['id'];
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
                                    error_log('Prepare failed for unit standard query: ' . $conn->error);
                                    continue;
                                }
                                $us_stmt->bind_param("ss", $learnerKey, $us_id);
                                $us_stmt->execute();
                                $us_result = $us_stmt->get_result();
                                $total_summative_marks_scored = 0;
                                $total_summative_possible_marks = 0;
                                while ($row = $us_result->fetch_assoc()) {
                                    if ($row['marks'] !== null) {
                                        $total_summative_possible_marks += $row['marks'];
                                        $total_summative_marks_scored += $row['marks_scored'] ?? 0;
                                    }
                                    // Log for debugging
                                    error_log("Unit standard $us_id, learner $learnerKey: assessment_exercise=" . ($row['assessment_exercise'] ?? 'NULL') . ", marks_exercise=" . ($row['marks_exercise'] ?? 'NULL') . ", marks=" . ($row['marks'] ?? 'NULL') . ", marks_scored=" . ($row['marks_scored'] ?? 'NULL'));
                                }
                                $competency_status = 'NYC';
                                if ($total_summative_possible_marks > 0) {
                                    $summative_percentage = ($total_summative_marks_scored / $total_summative_possible_marks) * 100;
                                    $competency_status = ($summative_percentage >= 50) ? 'C' : 'NYC';
                                }
                                // Log marks for debugging
                                error_log("Unit standard $us_id for learner $learnerKey: scored=$total_summative_marks_scored, possible=$total_summative_possible_marks, status=$competency_status");
                                $us_stmt->close();

                                $unitStandards[$unitStandard['id']] = [
                                    'unitstandard_id' => $unitStandard['id'],
                                    'unitstandard_name' => $unitStandard['name'],
                                    'competency_status' => $competency_status,
                                    'date' => date('Y-m-d')
                                ];
                            }
                        }
                    }
                }
            }
        }

        // Merge unit standards
        foreach ($unitStandards as $us) {
            $learners[$learnerKey]['unitStandards'][$us['unitstandard_id']] = $us;
        }
    }

    // Convert unitStandards to indexed array
    foreach ($learners as &$learner) {
        $learner['unitStandards'] = array_values($learner['unitStandards']);
    }
    unset($learner);

    if (empty($learners)) {
        throw new Exception('No valid learner data found after processing');
    }

    // Handle assessor signature
    $signature_base_dir = 'https://rlms.rlms.co.za/mobile/';
    $assessor_signature_base64 = '';
    $mime_type = 'image/png'; // Default MIME type
    if (!empty($userDetails['f_signature'])) {
        $signature_url = $signature_base_dir . $userDetails['f_signature'];
        error_log('Attempting to fetch signature from: ' . $signature_url);
        
        // Use curl to fetch the signature
        $ch = curl_init($signature_url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_HEADER, false);
        // Add authentication headers if required (uncomment and adjust as needed)
        // curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer your_token_here']);
        $signature_data = curl_exec($ch);
        $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $content_type = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
        curl_close($ch);

        if ($http_code === 200 && $signature_data !== false) {
            $assessor_signature_base64 = base64_encode($signature_data);
            $mime_type = $content_type ?: 'image/png'; // Fallback to PNG if MIME type not detected
            error_log('Signature fetched successfully, MIME type: ' . $mime_type);
        } else {
            error_log('Failed to fetch signature from: ' . $signature_url . ', HTTP code: ' . $http_code);
            $assessor_signature_error = 'Assessor signature could not be fetched (HTTP ' . $http_code . ')';
        }
    } else {
        error_log('No signature filename provided in userDetails');
        $assessor_signature_error = 'No assessor signature filename provided';
    }

    // Handle logo (unchanged but with absolute path and debugging)
    $logo_path = 'uploads/MTL.jpeg';
    $logo_base64 = '';
    error_log('Logo path: ' . $logo_path);
    error_log('Logo file exists: ' . (file_exists($logo_path) ? 'Yes' : 'No'));
    error_log('Logo file readable: ' . (is_readable($logo_path) ? 'Yes' : 'No'));
    if (file_exists($logo_path) && is_readable($logo_path)) {
        $logo_data = file_get_contents($logo_path);
        $logo_base64 = base64_encode($logo_data);
    } else {
        error_log('Logo file not found or not readable at: ' . $logo_path);
        $logo_error = 'Logo file not found or not readable';
    }

    // Generate HTML for PDF
    $html = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Assessor Report</title>';
    $html .= '<style>
        body { font-family: laz, sans-serif; font-size: 12pt; margin: 20px; }
        h1 { text-align: center; margin-top: 20px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid black; padding: 5px; text-align: left; }
        th { background-color: #f2f2f2; }
        .signature { max-width: 150px; }
        .error { color: red; font-size: 10pt; }
        header { text-align: center; padding-bottom: 20px; border-bottom: 2px solid #000; margin-bottom: 20px; }
        .logo { max-width: 200px; display: block; margin: 0 auto; }
    </style></head><body>';

    $html .= '<header>';
    if (!empty($logo_base64)) {
        $html .= "<img src=\"data:image/jpeg;base64,$logo_base64\" alt=\"Company Logo\" class=\"logo\">";
    } else {
        $html .= "<p class=\"error\">" . ($logo_error ?? 'Logo not available') . "</p>";
    }
    $html .= '</header>';

    $html .= '<h1>ASSESSOR REPORT</h1>';
    $html .= "<p>Programme Name: " . htmlspecialchars($qualificationName) . "</p>";
    $html .= "<p>Assessor Name: " . htmlspecialchars($userDetails['firstName'] . ' ' . $userDetails['lastName']) . "</p>";
    $html .= "<p>Assessor No.: " . htmlspecialchars($assessorNo) . "</p>";
    $html .= '<table border="1" cellpadding="5" cellspacing="0">';
    $html .= '<tr><th>NO</th><th>SURNAME</th><th>NAME</th><th>ID NO</th>';

    // Dynamically add unit standard columns
    $maxUnitStandards = 0;
    foreach ($learners as $learner) {
        $unitCount = count($learner['unitStandards']);
        $maxUnitStandards = max($maxUnitStandards, $unitCount);
    }

    for ($i = 1; $i <= $maxUnitStandards; $i++) {
        $html .= "<th>U/S ID $i</th><th>DATE $i</th><th>C/NYC $i</th>";
    }
    $html .= '</tr>';

    $counter = 1;
    foreach ($learners as $learnerID => $learner) {
        if ($counter > 15) break;

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
    $html .= "<p><strong>Assessor Signature: Assessor No. " . htmlspecialchars($assessorNo) . "</strong></p>";
    if (!empty($assessor_signature_base64)) {
        $html .= "<img src=\"data:$mime_type;base64,$assessor_signature_base64\" alt=\"Assessor Signature\" class=\"signature\">";
    } else {
        $html .= "<p class=\"error\">No assessor signature available" . (isset($assessor_signature_error) ? " - " . htmlspecialchars($assessor_signature_error) . " at $signature_url" : "") . "</p>";
    }
    $html .= "<p>DATE: " . date('Y-m-d') . "</p>";
    $html .= '</body></html>';

    // Initialize Dompdf with options
    $options = new Options();
    $options->set('isHtml5ParserEnabled', true);
    $options->set('isRemoteEnabled', true);
    $options->set('defaultMediaType', 'print');
    $options->set('chroot', $_SERVER['DOCUMENT_ROOT']);

    $dompdf = new Dompdf($options);
    $dompdf->loadHtml($html);
    $dompdf->setPaper('A4', 'landscape');
    $dompdf->render();

    // Output PDF
    ob_end_clean();
    header('Content-Type: application/pdf');
    header('Content-Disposition: attachment; filename="Assessor_' . preg_replace('/[^A-Za-z0-9_-]/', '_', $assessorNo) . '_Report.pdf"');
    echo $dompdf->output();

    // Clean up
    $stmt->close();
    $conn->close();
    exit;

} catch (Exception $e) {
    ob_end_clean();
    error_log('Error in assessor_report.php: ' . $e->getMessage() . ' in ' . $e->getFile() . ' on line ' . $e->getLine());
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