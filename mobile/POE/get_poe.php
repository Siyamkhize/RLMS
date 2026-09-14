<?php
include '../connection.php';

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'GET') {
    echo json_encode(['error' => 'Invalid request method. Use POST or GET.']);
    exit;
}

$learnerID = ($_SERVER['REQUEST_METHOD'] == 'POST') ? 
             (isset($_POST['learnerID']) ? intval($_POST['learnerID']) : 0) : 
             (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0);

if ($learnerID <= 0) {
    echo json_encode([
        'error' => 'Invalid or missing learnerID.',
        'debug' => ['post_params' => $_POST, 'get_params' => $_GET]
    ]);
    exit;
}

// Debug: Log learnerID
file_put_contents('../debug.log', "Processing learnerID: $learnerID\n", FILE_APPEND);

$query = "
   SELECT 
    ld.classID, 
    s.project_id, 
    JSON_UNQUOTE(JSON_EXTRACT(pr.Project_pathway, '$[0].name')) AS pathway_name,
    JSON_UNQUOTE(JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.name')) AS qualification_name,
    JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards') AS unit_standards,
    a.unit_standard_id,
    a.assessment_type,
    a.question_type,
    a.question_number,
    a.specific_outcome,
    a.assessment_criteria,
    a.exercise,
    a.marks
FROM learnerdetails ld
LEFT JOIN class   c  ON ld.classID = c.classID
LEFT JOIN sites   s  ON c.siteID   = s.siteID
LEFT JOIN project pr ON s.project_id = pr.project_id
LEFT JOIN assessments a ON JSON_CONTAINS(
    JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards'),
    JSON_OBJECT('id', a.unit_standard_id)
)
WHERE ld.LearnerID = ?
GROUP BY 
    ld.classID, 
    s.project_id, 
    pathway_name, 
    qualification_name, 
    unit_standards,
    a.unit_standard_id, 
    a.assessment_type, 
    a.question_type, 
    a.question_number, 
    a.specific_outcome, 
    a.assessment_criteria, 
    a.exercise, 
    a.marks
ORDER BY a.assessment_id ASC;
";

$stmt = $conn->prepare($query);
if (!$stmt) {
    echo json_encode(['error' => 'Failed to prepare query: ' . $conn->error]);
    exit;
}

$stmt->bind_param('i', $learnerID);
$stmt->execute();
$result = $stmt->get_result();

// Debug: Log query results
file_put_contents('../debug.log', "Query executed with learnerID: $learnerID, Rows: {$result->num_rows}\n", FILE_APPEND);
$rawData = [];
while ($row = $result->fetch_assoc()) {
    $rawData[] = $row;
}
file_put_contents('../debug.log', "Raw data: " . print_r($rawData, true) . "\n", FILE_APPEND);

if (!$result->num_rows) {
    $checkStmt = $conn->prepare("SELECT COUNT(*) as count FROM learnerdetails WHERE LearnerID = ?");
    $checkStmt->bind_param('i', $learnerID);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();
    $learnerCount = $checkResult->fetch_assoc()['count'];
    file_put_contents('../debug.log', "LearnerID $learnerID exists: " . ($learnerCount > 0 ? 'Yes' : 'No') . "\n", FILE_APPEND);
    $checkStmt->close();

    echo json_encode([
        'error' => 'No data found for learnerID.',
        'debug' => [
            'learnerID_exists' => $learnerCount > 0,
            'query' => $query,
            'raw_data' => $rawData
        ]
    ]);
    exit;
}

$result->data_seek(0);
$data = [];
$processedAssessments = [];
while ($row = $result->fetch_assoc()) {
    $pathwayName = $row['pathway_name'] ? trim($row['pathway_name'], '"') : 'Unknown Pathway';
    $qualificationName = $row['qualification_name'] ? trim($row['qualification_name'], '"') : 'Unknown Qualification';

    $unitStandards = json_decode($row['unit_standards'], true) ?? [];
    if (json_last_error() !== JSON_ERROR_NONE) {
        file_put_contents('../debug.log', "JSON decode error: " . json_last_error_msg() . "\n", FILE_APPEND);
        $unitStandards = [];
    }

    // Deduplicate unit standards
    $uniqueUnitStandards = [];
    foreach ($unitStandards as $unitStandard) {
        $unitStandardId = $unitStandard['id'] ?? null;
        if ($unitStandardId && !isset($uniqueUnitStandards[$unitStandardId])) {
            $uniqueUnitStandards[$unitStandardId] = $unitStandard;
        }
    }
    file_put_contents('../debug.log', "Unique unit standards: " . print_r($uniqueUnitStandards, true) . "\n", FILE_APPEND);

    if (!isset($data['pathways'][$pathwayName])) {
        $data['pathways'][$pathwayName] = ['qualifications' => []];
    }
    if (!isset($data['pathways'][$pathwayName]['qualifications'][$qualificationName])) {
        $data['pathways'][$pathwayName]['qualifications'][$qualificationName] = ['unitstandards' => []];
    }

    foreach ($uniqueUnitStandards as $unitStandard) {
        $unitStandardId = $unitStandard['id'] ?? null;
        $unitStandardName = $unitStandard['name'] ? trim($unitStandard['name'], '"') : 'Unknown Unit Standard';

        // Strip any leading ID (numbers followed by separator) from name to avoid duplication
        $cleanedName = preg_replace('/^\d+\s*[:\-–—\s]+/', '', $unitStandardName);
        $formattedUsName = $unitStandardId . " - " . $cleanedName;

        if (!isset($data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$formattedUsName])) {
            $data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$formattedUsName] = [
                'formative' => [],
                'summative' => [],
                'logbook' => [],
                'formativeremedial' => [],
                'summativeremedial' => []
            ];
        }

        if ($row['unit_standard_id'] && (string)$row['unit_standard_id'] === (string)$unitStandardId) {
            $assessmentType = strtolower(trim($row['assessment_type'] ?? ''));
            $questionType = $row['question_type'] ?? 'Knowledge';

            // Create a unique key for the assessment
            $assessmentKey = md5(serialize([
                'unit_standard_id' => $row['unit_standard_id'],
                'assessment_type' => $assessmentType,
                'question_number' => $row['question_number'],
                'question_type' => $questionType
            ]));

            // Skip if assessment was already processed
            if (isset($processedAssessments[$assessmentKey])) {
                file_put_contents('../debug.log', "Skipping duplicate assessment: $assessmentKey\n", FILE_APPEND);
                continue;
            }
            $processedAssessments[$assessmentKey] = true;

            if (in_array($assessmentType, ['formative', 'summative'])) {
                $assessment = [
                    'question_number' => $row['question_number'] ?? null,
                    'specific_outcome' => $row['specific_outcome'] ?? null,
                    'assessment_criteria' => $row['assessment_criteria'] ?? null,
                    'exercise' => $row['exercise'] ?? null,
                    'marks' => $row['marks'] ?? null,
                    'question_type' => $questionType
                ];

                file_put_contents('../debug.log', "Assessment data: " . print_r($assessment, true) . "\n", FILE_APPEND);

                if ($assessmentType == 'formative') {
                    $data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$formattedUsName]['formative'][] = $assessment;
                } elseif ($assessmentType == 'summative') {
                    $data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$formattedUsName]['summative'][] = $assessment;
                    if ($questionType == 'Practical') {
                        $data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$formattedUsName]['logbook'][] = $assessment;
                    }
                }
            } else {
                file_put_contents('../debug.log', "Invalid assessment type: $assessmentType\n", FILE_APPEND);
            }
        }
    }
}

$stmt->close();
echo json_encode($data, JSON_PRETTY_PRINT);
$conn->close();
?>