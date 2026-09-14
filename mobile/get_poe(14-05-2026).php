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

    $host = $_SERVER['HTTP_HOST'] ?? 'www.rlms.rlms.co.za';
    $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $baseUrl = "$protocol://$host/";

    // SQL Query to fetch POE data with file paths and multiple unit standards
    // Updated LEFT JOIN to assessments to handle both numeric and string IDs in JSON
    // Updated LEFT JOIN to poe to extract unit_standard_id from p.exercise format "All Questions - {ID} - {Name}..." 
    // and match on unit_standard_id + type instead of exact exercise match
   $query = "
 SELECT DISTINCT 
            pr.project_id,
            JSON_EXTRACT(pr.Project_pathway, '$[0].name') AS pathway_name,
            JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.name') AS qualification_name,
            JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards') AS unit_standards,
            a.unit_standard_id,
            CASE 
                WHEN a.question_type = 'Practical' THEN 'LogBook'
                WHEN a.assessment_type = 'FormativeRemedial' THEN 'FormativeRemedial'
                WHEN a.assessment_type = 'SummativeRemedial' THEN 'SummativeRemedial'
                ELSE a.assessment_type 
            END AS assessment_type,
            a.question_number,
            a.specific_outcome,
            a.assessment_criteria,
            a.exercise,
            a.marks,
            p.filePath,
            CASE 
                WHEN p.filePath IS NULL OR p.filePath = '' THEN NULL
                WHEN p.filePath LIKE 'http%' THEN p.filePath
                WHEN p.filePath LIKE 'mobile/%' THEN CONCAT('$baseUrl', p.filePath)
                ELSE CONCAT('{$baseUrl}mobile/', p.filePath)
            END AS fileUrl,
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
                a.project_id = pr.project_id
                AND (
                    JSON_CONTAINS(
                        JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards'),
                        JSON_OBJECT('id', a.unit_standard_id)
                    ) OR
                    JSON_CONTAINS(
                        JSON_EXTRACT(pr.Project_pathway, '$[0].qual_types[0].qualification.unitStandards'),
                        JSON_OBJECT('id', CAST(a.unit_standard_id AS CHAR))
                    )
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
                        WHEN a.assessment_type = 'FormativeRemedial' THEN 'FormativeRemedial'
                        WHEN a.assessment_type = 'SummativeRemedial' THEN 'SummativeRemedial'
                        ELSE a.assessment_type 
                     END) = p.type 
                AND p.learnerID = ld.LearnerID
        LEFT JOIN 
            marks m ON ld.LearnerID = m.learnerID 
                AND a.exercise = m.exercise
                AND m.type = CASE 
                    WHEN a.question_type = 'Practical' THEN 'Logbook'
                    WHEN a.assessment_type = 'FormativeRemedial' THEN 'FormativeRemedial'
                    WHEN a.assessment_type = 'SummativeRemedial' THEN 'SummativeRemedial'
                    ELSE a.assessment_type 
                END
        WHERE 
            ld.LearnerID = ?
        GROUP BY 
            a.project_id, a.unit_standard_id, a.assessment_type, a.question_number, a.question_type, 
            a.specific_outcome, a.assessment_criteria, a.exercise, a.marks, 
            p.filePath, m.marks_scored, m.a_comment, m.comment, m.approval_status, 
            m.moderator_status, m.moderator_comment
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
            $unitStandardBaseName = $unitStandard['name'] ? trim($unitStandard['name'], '"') : 'Unknown Unit Standard';
            // Show the unit standard id in the UI heading, e.g. "9964 - Apply health and safety..."
            // Some datasets already include the id inside the name (e.g. "9964 - Apply ..."),
            // so strip it first to avoid "9964 - 9964 - ...".
            $cleanBaseName = $unitStandardBaseName;
            if ($unitStandardId) {
                $idPrefixPattern = '/^' . preg_quote((string)$unitStandardId, '/') . '\s*[-–—]\s*/';
                $cleanBaseName = preg_replace($idPrefixPattern, '', $cleanBaseName);
            }
            $unitStandardName = ($unitStandardId ? ($unitStandardId . ' - ') : '') . $cleanBaseName;
            
            if (!isset($data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$unitStandardName])) {
                $data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$unitStandardName] = [
                    'formative' => [],
                    'summative' => [],
                    'logbook' => [],
                    'formativeremedial' => [],
                    'summativeremedial' => []
                ];
            }

            // Add assessment data if it exists for this unit standard
            if ($row['unit_standard_id'] && (string)$row['unit_standard_id'] === (string)$unitStandardId) {
                $assessmentType = strtolower(trim($row['assessment_type'] ?? 'unknown'));
                // Normalize assessment_type so we can match values like:
                // - "Formative Remedial"
                // - "Formative-Remedial"
                // - "formative_remedial"
                // as well as "formativeremedial".
                $assessmentType = str_replace([' ', '_', '-'], '', $assessmentType);

                $exerciseText = (string)($row['exercise'] ?? '');

                // If the DB doesn't reliably store remedial in assessment_type, infer it from the exercise prefix.
                // Example exercise values:
                // "FormativeRemedial - 9964 - Apply health and safety..."
                // "SummativeRemedial - 9964 - Apply health and safety..."
                $exerciseTextNorm = strtolower(trim($exerciseText));
                $exerciseTextNorm = str_replace([' ', '_', '-'], '', $exerciseTextNorm);

                if (stripos($exerciseTextNorm, 'formativeremedial') === 0) {
                    $assessmentType = 'formativeremedial';
                } elseif (stripos($exerciseTextNorm, 'summativeremedial') === 0) {
                    $assessmentType = 'summativeremedial';
                }

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

                if (in_array($assessmentType, ['formative', 'summative', 'logbook', 'formativeremedial', 'summativeremedial'])) {
                    // Normalize type for consistency with save_marks.php
                    $displayType = ucfirst($assessmentType);
                    if ($assessmentType === 'formativeremedial') $displayType = 'FormativeRemedial';
                    if ($assessmentType === 'summativeremedial') $displayType = 'SummativeRemedial';
                    if ($assessmentType === 'logbook') $displayType = 'Logbook';

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
                        'question_type' => $row['question_type'] ?? null,
                        'type' => $displayType // Add type for the app to use
                    ];
                    file_put_contents('debug.log', "Assessment data: " . print_r($assessment, true) . "\n", FILE_APPEND);
                    $data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'][$unitStandardName][$assessmentType][] = $assessment;
                } else {
                    file_put_contents('debug.log', "Invalid assessment_type: $assessmentType\n", FILE_APPEND);
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // DYNAMIC REMEDIAL DETECTION (NYC - Not Yet Competent)
    // If a learner gets less than full marks (e.g. half marks) on a question,
    // that question should automatically appear in the remedial section
    // so the facilitator/assessor knows it needs attention.
    // ------------------------------------------------------------------
    foreach ($data['pathways'] as &$pathway) {
        foreach ($pathway['qualifications'] as &$qualification) {
            foreach ($qualification['unitstandards'] as &$unitStandard) {
                // Check Formative for NYC (Not Yet Competent)
                if (!empty($unitStandard['formative'])) {
                    foreach ($unitStandard['formative'] as $assessment) {
                        $totalMarks = floatval($assessment['marks'] ?? 0);
                        // Check if marked (marks_scored is not null)
                        $isMarked = $assessment['marks_scored'] !== null;
                        $scoredMarks = floatval($assessment['marks_scored'] ?? 0);
                        
                        // ONLY show as remedial if it HAS been marked AND scored marks < total marks
                        if ($isMarked && $totalMarks > 0 && $scoredMarks < $totalMarks) {
                            $remedialItem = $assessment;
                            $remedialItem['type'] = 'FormativeRemedial';
                            // Prefix exercise to indicate it's a remedial requirement due to NYC status
                            $remedialItem['exercise'] = 'NYC Remedial: ' . ($assessment['exercise'] ?? 'Question');
                            $unitStandard['formativeremedial'][] = $remedialItem;
                        }
                    }
                }
                
                // Check Summative for NYC (Not Yet Competent)
                if (!empty($unitStandard['summative'])) {
                    foreach ($unitStandard['summative'] as $assessment) {
                        $totalMarks = floatval($assessment['marks'] ?? 0);
                        // Check if marked (marks_scored is not null)
                        $isMarked = $assessment['marks_scored'] !== null;
                        $scoredMarks = floatval($assessment['marks_scored'] ?? 0);
                        
                        // ONLY show as remedial if it HAS been marked AND scored marks < total marks
                        if ($isMarked && $totalMarks > 0 && $scoredMarks < $totalMarks) {
                            $remedialItem = $assessment;
                            $remedialItem['type'] = 'SummativeRemedial';
                            // Prefix exercise to indicate it's a remedial requirement due to NYC status
                            $remedialItem['exercise'] = 'NYC Remedial: ' . ($assessment['exercise'] ?? 'Question');
                            $unitStandard['summativeremedial'][] = $remedialItem;
                        }
                    }
                }
            }
        }
    }
    unset($pathway, $qualification, $unitStandard);

    // Sort assessments within each assessment type by question_number
    foreach ($data['pathways'] as &$pathway) {
        foreach ($pathway['qualifications'] as &$qualification) {
            foreach ($qualification['unitstandards'] as &$unitStandard) {
                foreach (['formative', 'summative', 'logbook', 'formativeremedial', 'summativeremedial'] as $type) {
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

    // ------------------------------------------------------------------
    // REMEDIAL FALLBACK
    // Some environments store remedial exercises in the `marks` table
    // (type = FormativeRemedial / SummativeRemedial) even when the
    // `assessments` table doesn't have matching remedial assessment rows.
    // In that case, we still want the assessor app to SEE and MARK them.
    // We attach these remedial items under the correct unit standard based
    // on the unit standard id embedded in the exercise text:
    // "FormativeRemedial - 9964 - <question>"
    // "SummativeRemedial - 9964 - <question>"
    // ------------------------------------------------------------------
    try {
        $rmStmt = $conn->prepare("
            SELECT
                m.exercise,
                m.so,
                m.marks_scored,
                m.a_comment,
                m.comment,
                m.approval_status,
                m.moderator_status,
                m.moderator_comment,
                m.type
            FROM marks m
            WHERE m.learnerID = ?
              AND LOWER(
                    REPLACE(
                      REPLACE(
                        REPLACE(TRIM(m.type), ' ', ''),
                      '-', ''),
                    '_', ''
                    )
                  ) IN ('formativeremedial', 'summativeremedial')
        ");
        if ($rmStmt) {
            $rmStmt->bind_param('i', $learnerID);
            $rmStmt->execute();
            $rmResult = $rmStmt->get_result();

            $seenRemedial = [];
            while ($rm = $rmResult->fetch_assoc()) {
                $exerciseText = (string)($rm['exercise'] ?? '');
                $typeText = (string)($rm['type'] ?? '');

                // Extract unit standard id from: "... - 9964 - ..."
                $unitId = null;
                if (preg_match('/[-–—]\s*(\d+)\s*[-–—]/', $exerciseText, $m)) {
                    $unitId = $m[1];
                }
                if (!$unitId) {
                    continue;
                }

                $bucket = null;
                $typeTextNorm = strtolower(trim($typeText));
                $typeTextNorm = str_replace([' ', '_', '-'], '', $typeTextNorm);

                if ($typeTextNorm === 'formativeremedial') {
                    $bucket = 'formativeremedial';
                } elseif ($typeTextNorm === 'summativeremedial') {
                    $bucket = 'summativeremedial';
                } else {
                    continue;
                }

                $dedupeKey = md5($typeText . '|' . $unitId . '|' . ($rm['so'] ?? '') . '|' . $exerciseText);
                if (isset($seenRemedial[$dedupeKey])) {
                    continue;
                }
                $seenRemedial[$dedupeKey] = true;

                // Attach to any unit standard key that starts with "<unitId> -"
                foreach ($data['pathways'] as &$pathway) {
                    foreach ($pathway['qualifications'] as &$qualification) {
                        foreach ($qualification['unitstandards'] as $usKey => &$usVal) {
                            if (strpos($usKey, $unitId . ' - ') !== 0) {
                                continue;
                            }

                            $usVal[$bucket][] = [
                                'question_number' => null,
                                'specific_outcome' => $rm['so'] ?? null,
                                'assessment_criteria' => null,
                                'exercise' => $exerciseText,
                                'marks' => null,
                                'filePath' => null,
                                'fileUrl' => null,
                                'marks_scored' => $rm['marks_scored'] ?? null,
                                'a_comment' => $rm['a_comment'] ?? null,
                                'comment' => $rm['comment'] ?? null,
                                'approval_status' => $rm['approval_status'] ?? null,
                                'moderator_status' => $rm['moderator_status'] ?? null,
                                'moderator_comment' => $rm['moderator_comment'] ?? null,
                                'question_type' => null,
                                'type' => ($bucket === 'formativeremedial' ? 'FormativeRemedial' : 'SummativeRemedial'),
                            ];
                        }
                        unset($usVal);
                    }
                    unset($qualification);
                }
                unset($pathway);
            }

            $rmStmt->close();
        } else {
            file_put_contents(
                'debug.log',
                "Remedial marks query prepare failed: " . $conn->error . "\n",
                FILE_APPEND
            );
        }
    } catch (Exception $e) {
        file_put_contents(
            'debug.log',
            "Remedial fallback error: {$e->getMessage()}\n",
            FILE_APPEND
        );
    }

    // ------------------------------------------------------------------
    // REMEDIAL POE UPLOADS (uploaded by learner)
    // Remedial uploads can exist in the `poe` table with:
    //   type = FormativeRemedial / SummativeRemedial
    // and an exercise string like:
    //   "FormativeRemedial - 9964 - Apply health and safety..."
    // These often won't join via `assessments`, so we attach them here.
    // ------------------------------------------------------------------
    try {
        // Build the public base URL for POE PDFs from the current request.
        $baseMobileUrl = $baseUrl . 'mobile/';

        $rpoeStmt = $conn->prepare("
            SELECT
                p.exercise,
                p.filePath,
                p.type
            FROM poe p
            WHERE p.learnerID = ?
              AND (
                LOWER(TRIM(p.type)) IN ('formativeremedial', 'summativeremedial')
                OR LOWER(TRIM(p.type)) LIKE 'formativeremedial%'
                OR LOWER(TRIM(p.type)) LIKE 'summativeremedial%'
                OR LOWER(
                    REPLACE(
                      REPLACE(
                        REPLACE(TRIM(p.type), ' ', ''),
                      '-', ''),
                    '_', ''
                    )
                  ) IN ('formativeremedial', 'summativeremedial')
                OR LOWER(
                    REPLACE(
                      REPLACE(
                        REPLACE(TRIM(p.type), ' ', ''),
                      '-', ''),
                    '_', ''
                    )
                  ) LIKE 'formativeremedial%'
                OR LOWER(
                    REPLACE(
                      REPLACE(
                        REPLACE(TRIM(p.type), ' ', ''),
                      '-', ''),
                    '_', ''
                    )
                  ) LIKE 'summativeremedial%'
              )
        ");

        if ($rpoeStmt) {
            $rpoeStmt->bind_param('i', $learnerID);
            $rpoeStmt->execute();
            $rpoeResult = $rpoeStmt->get_result();

            $seenRemedialPoe = [];
            while ($rp = $rpoeResult->fetch_assoc()) {
                $exerciseText = (string)($rp['exercise'] ?? '');
                $typeText = (string)($rp['type'] ?? '');
                $filePath = (string)($rp['filePath'] ?? '');

                // Extract unit standard id from: "... - 9964 - ..."
                $unitId = null;
                if (preg_match('/[-–—]\\s*(\\d+)\\s*[-–—]/', $exerciseText, $m)) {
                    $unitId = $m[1];
                }
                if (!$unitId) {
                    continue;
                }

                $bucket = null;
                $typeTextNorm = strtolower(trim($typeText));
                $typeTextNorm = str_replace([' ', '_', '-'], '', $typeTextNorm);

                if ($typeTextNorm === 'formativeremedial') {
                    $bucket = 'formativeremedial';
                } elseif ($typeTextNorm === 'summativeremedial') {
                    $bucket = 'summativeremedial';
                } else {
                    continue;
                }

                $dedupeKey = md5($typeText . '|' . $unitId . '|' . $exerciseText . '|' . $filePath);
                if (isset($seenRemedialPoe[$dedupeKey])) {
                    continue;
                }
                $seenRemedialPoe[$dedupeKey] = true;

                // Attach to any unit standard key that starts with "<unitId> -"
                foreach ($data['pathways'] as &$pathway) {
                    foreach ($pathway['qualifications'] as &$qualification) {
                        foreach ($qualification['unitstandards'] as $usKey => &$usVal) {
                            if (strpos($usKey, $unitId . ' - ') !== 0) {
                                continue;
                            }

                            $usVal[$bucket][] = [
                                'question_number' => null,
                                'specific_outcome' => null,
                                'assessment_criteria' => null,
                                'exercise' => $exerciseText,
                                'marks' => null,
                                'filePath' => $filePath !== '' ? $filePath : null,
                                // Use the same base path as the rest of the app.
                                'fileUrl' => $filePath !== ''
                                    ? ($baseMobileUrl . ltrim($filePath, '/'))
                                    : null,
                                'marks_scored' => null,
                                'a_comment' => null,
                                'comment' => null,
                                'approval_status' => null,
                                'moderator_status' => null,
                                'moderator_comment' => null,
                                'question_type' => null,
                                'type' => ($bucket === 'formativeremedial' ? 'FormativeRemedial' : 'SummativeRemedial'),
                            ];
                        }
                        unset($usVal);
                    }
                    unset($qualification);
                }
                unset($pathway);
            }

            $rpoeStmt->close();
        } else {
            file_put_contents(
                'debug.log',
                "Remedial POE query prepare failed: " . $conn->error . "\n",
                FILE_APPEND
            );
        }
    } catch (Exception $e) {
        file_put_contents(
            'debug.log',
            "Remedial POE fallback error: {$e->getMessage()}\n",
            FILE_APPEND
        );
    }

    // Close statement and connection
    $stmt->close();
    $conn->close();

    echo json_encode($data, JSON_PRETTY_PRINT);
} else {
    echo json_encode(['error' => 'Invalid request method. Please use POST or GET.']);
}