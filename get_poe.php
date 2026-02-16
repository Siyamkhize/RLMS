<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");
include('connection.php');

// Debug: Log $_GET and $_POST to inspect parameters
file_put_contents('debug.log', "GET: " . print_r($_GET, true) . "\nPOST: " . print_r($_POST, true) . "\n", FILE_APPEND);

// Handle GET or POST request
if ($_SERVER['REQUEST_METHOD'] == 'POST' || $_SERVER['REQUEST_METHOD'] == 'GET') {
    $learnerID = ($_SERVER['REQUEST_METHOD'] == 'POST') ? 
                 (isset($_POST['learnerID']) ? intval($_POST['learnerID']) : 0) : 
                 (isset($_GET['learnerId']) ? intval($_GET['learnerId']) : 0);

    // Debug: Log the parsed learnerID
    file_put_contents('debug.log', "Parsed learnerID: $learnerID\n", FILE_APPEND);

    if ($learnerID <= 0) {
        echo json_encode(['error' => 'Invalid learnerID provided.', 'get_params' => $_GET, 'post_params' => $_POST]);
        exit;
    }

    // SQL Query to fetch POE data with file paths and multiple unit standards
    // Updated LEFT JOIN to assessments to handle both numeric and string IDs in JSON
    // Updated LEFT JOIN to poe to extract unit_standard_id from p.exercise format "All Questions - {ID} - {Name}..." 
    // and match on unit_standard_id + type instead of exact exercise match
    $query = "
        SELECT DISTINCT 
            JSON_EXTRACT(pr.Project_pathway, '$[0].name') AS pathway_name,
            JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.name') AS qualification_name,
            JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards') AS unit_standards,
            a.unit_standard_id,
            CASE 
                WHEN a.question_type = 'Practical' THEN 'LogBook'
                ELSE a.assessment_type 
            END AS assessment_type,
            a.question_number,
            a.specific_outcome,
            a.assessment_criteria,
            a.exercise,
            a.marks,
            p.filePath,
            CONCAT('https://www.rlms.rlms.co.za/mobile/', p.filePath) AS fileUrl,
            m.marks_scored,
            m.a_comment,
            m.comment,
            m.approval_status,
            m.moderator_status,
            m.moderator_comment,
            a.question_type,
            p.exercise AS poe_exercise
        FROM 
            learnerdetails ld 
        LEFT JOIN 
            class c ON ld.classID = c.classID 
        LEFT JOIN 
            sites s ON c.siteID = s.siteID 
        LEFT JOIN 
            project pr ON s.project_id = pr.project_id
        LEFT JOIN 
            assessments a ON (
                JSON_CONTAINS(
                    JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards'),
                    JSON_OBJECT('id', a.unit_standard_id)
                ) OR
                JSON_CONTAINS(
                    JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards'),
                    JSON_OBJECT('id', CAST(a.unit_standard_id AS CHAR))
                )
            )
        LEFT JOIN 
            poe p ON a.unit_standard_id = CAST(
                TRIM(
                    SUBSTRING_INDEX(
                        SUBSTRING_INDEX(TRIM(p.exercise), '-', 2), 
                        '-', 
                        -1
                    )
                ) AS UNSIGNED
            )
                AND (CASE 
                        WHEN a.question_type = 'Practical' THEN 'LogBook'
                        ELSE a.assessment_type 
                     END) = p.type 
                AND p.learnerID = ld.LearnerID
        LEFT JOIN 
            marks m ON ld.LearnerID = m.learnerID 
                AND a.exercise = m.exercise 
        WHERE 
            ld.LearnerID = ?
        GROUP BY 
            a.unit_standard_id, a.assessment_type, a.question_number, a.question_type, 
            a.specific_outcome, a.assessment_criteria, a.exercise, a.marks, 
            p.filePath, m.marks_scored, m.a_comment, m.comment, m.approval_status
        ORDER BY 
            a.question_number ASC
    ";

    $stmt = $conn->prepare($query);
    if (!$stmt) {
        echo json_encode(['error' => 'Failed to prepare query: ' . $conn->error]);
        exit;
    }

    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();

    // Debug: Log raw query results
    $rawData = [];
    while ($row = $result->fetch_assoc()) {
        $rawData[] = $row;
    }
    file_put_contents('debug.log', "Raw query results: " . print_r($rawData, true) . "\n", FILE_APPEND);

    if (!$result->num_rows) {
        echo json_encode(['error' => 'No data found for the provided learnerID.']);
        exit;
    }

    // Reset result pointer to process again
    $result->data_seek(0);

    $data = [];
    $processedAssessments = [];
    while ($row = $result->fetch_assoc()) {
        $pathwayName = $row['pathway_name'] ? trim($row['pathway_name'], '"') : 'Unknown Pathway';
        $qualificationName = $row['qualification_name'] ? trim($row['qualification_name'], '"') : 'Unknown Qualification';

        // Decode unit standards JSON with error handling
        try {
            $unitStandards = json_decode($row['unit_standards'], true) ?? [];
        } catch (Exception $e) {
            file_put_contents('debug.log', "JSON decode error: {$e->getMessage()}\n", FILE_APPEND);
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
        file_put_contents('debug.log', "Unique unitStandards: " . print_r($uniqueUnitStandards, true) . "\n", FILE_APPEND);

        // Initialize pathway and qualification if not already set
        if (!isset($data['pathways'][$pathwayName])) {
            $data['pathways'][$pathwayName] = ['qualifications' => []];
        }
        if (!isset($data['pathways'][$pathwayName]['qualifications'][$qualificationName])) {
            $data['pathways'][$pathwayName]['qualifications'][$qualificationName] = ['unitstandards' => []];
        }

        // Process unique unit standards
        foreach ($uniqueUnitStandards as $unitStandard) {
            $unitStandardId = $unitStandard['id'] ?? null;
            $unitStandardName = $unitStandard['name'] ? trim($unitStandard['name'], '"') : 'Unknown Unit Standard';
            
            if (!isset($data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$unitStandardName])) {
                $data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$unitStandardName] = [
                    'formative' => [],
                    'summative' => [],
                    'logbook' => []
                ];
            }

            // Add assessment data if it exists for this unit standard
            if ($row['unit_standard_id'] && (string)$row['unit_standard_id'] === (string)$unitStandardId) {
                $assessmentType = strtolower(trim($row['assessment_type'] ?? 'unknown'));

                // Create a unique key for the assessment
                $assessmentKey = md5(serialize([
                    'unit_standard_id' => $row['unit_standard_id'],
                    'assessment_type' => $assessmentType,
                    'question_number' => $row['question_number'],
                    'question_type' => $row['question_type'],
                    'exercise' => $row['exercise']
                ]));

                // Skip if assessment was already processed
                if (isset($processedAssessments[$assessmentKey])) {
                    file_put_contents('debug.log', "Skipping duplicate assessment: $assessmentKey\n", FILE_APPEND);
                    continue;
                }
                $processedAssessments[$assessmentKey] = true;

                if (in_array($assessmentType, ['formative', 'summative', 'logbook'])) {
                    $assessment = [
                        'question_number' => $row['question_number'] ?? null,
                        'specific_outcome' => $row['specific_outcome'] ?? null,
                        'assessment_criteria' => $row['assessment_criteria'] ?? null,
                        'exercise' => $row['exercise'] ?? null,
                        'marks' => $row['marks'] ?? null,
                        'filePath' => !empty($row['filePath']) ? $row['filePath'] : null,
                        'fileUrl' => !empty($row['fileUrl']) ? $row['fileUrl'] : null,
                        'marks_scored' => $row['marks_scored'] ?? null,
                        'a_comment' => $row['a_comment'] ?? null,
                        'comment' => $row['comment'] ?? null,
                        'approval_status' => $row['approval_status'] ?? null,
                        'moderator_status' => $row['moderator_status'] ?? null,
                        'moderator_comment' => $row['moderator_comment'] ?? null,
                        'question_type' => $row['question_type'] ?? null
                    ];
                    file_put_contents('debug.log', "Assessment data: " . print_r($assessment, true) . "\n", FILE_APPEND);
                    $data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$unitStandardName][$assessmentType][] = $assessment;
                } else {
                    file_put_contents('debug.log', "Invalid assessment_type: $assessmentType\n", FILE_APPEND);
                }
            }
        }
    }

    // Sort assessments within each assessment type by question_number
    foreach ($data['pathways'] as &$pathway) {
        foreach ($pathway['qualifications'] as &$qualification) {
            foreach ($qualification['unitstandards'] as &$unitStandard) {
                foreach (['formative', 'summative', 'logbook'] as $type) {
                    if (!empty($unitStandard[$type])) {
                        usort($unitStandard[$type], function ($a, $b) {
                            return ($a['question_number'] ?? 0) <=> ($b['question_number'] ?? 0);
                        });
                    }
                }
            }
        }
    }
    unset($pathway, $qualification, $unitStandard); // Clean up references

    // Debug: Log final structured data
    file_put_contents('debug.log', "Final structured data: " . print_r($data, true) . "\n", FILE_APPEND);

    // Close statement and connection
    $stmt->close();
    $conn->close();

    echo json_encode($data, JSON_PRETTY_PRINT);
} else {
    echo json_encode(['error' => 'Invalid request method. Please use POST or GET.']);
}
?>