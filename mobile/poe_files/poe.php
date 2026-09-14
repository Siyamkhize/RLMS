<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");
include('connection.php');

// Timeout protection
set_time_limit(60);
ini_set('max_execution_time', 60);

// Debug: Log $_GET and $_POST to inspect parameters
file_put_contents('debug.log', "GET: " . print_r($_GET, true) . "\nPOST: " . print_r($_POST, true) . "\n", FILE_APPEND);

// Handle GET or POST request
if ($_SERVER['REQUEST_METHOD'] == 'POST' || $_SERVER['REQUEST_METHOD'] == 'GET') {
    $learnerID = ($_SERVER['REQUEST_METHOD'] == 'POST') ? 
                 (isset($_POST['learnerID']) ? intval($_POST['learnerID']) : 0) : 
                 (isset($_GET['learnerId']) ? intval($_GET['learnerId']) : (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0));

    // Debug: Log the parsed learnerID
    file_put_contents('debug.log', "Parsed learnerID: $learnerID\n", FILE_APPEND);

    if ($learnerID <= 0) {
        echo json_encode(['error' => 'Invalid learnerID provided.', 'get_params' => $_GET, 'post_params' => $_POST]);
        exit;
    }

    $host = $_SERVER['HTTP_HOST'] ?? '192.168.68.105:8080';
    if ($host === 'localhost' || $host === 'localhost:8080' || $host === '127.0.0.1' || $host === '127.0.0.1:8080') {
        $host = '192.168.68.105:8080';
    }
    $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $baseUrl = "$protocol://$host/assessorReport2/";

    // 1. Fetch learner pathway and project ID
    $learnerQuery = "
        SELECT 
            ld.LearnerID,
            pr.project_id,
            pr.Project_pathway
        FROM 
            learnerdetails ld 
        LEFT JOIN 
            class c ON ld.classID = c.classID 
        LEFT JOIN 
            sites s ON c.siteID = s.siteID 
        LEFT JOIN 
            project pr ON s.project_id = pr.project_id
        WHERE 
            ld.LearnerID = ?
    ";
    $stmt = $conn->prepare($learnerQuery);
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $learnerInfo = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$learnerInfo || !$learnerInfo['project_id']) {
        echo json_encode(['error' => 'Learner or Project not found.']);
        exit;
    }

    $projectId = $learnerInfo['project_id'];
    $pathwayJson = json_decode($learnerInfo['Project_pathway'], true) ?? [];
    
    // 2. Extract allowed Unit Standards for this learner from their pathway
    $allowedUnitStandards = [];
    $pathwayName = "Unknown Pathway";
    $qualificationName = "Unknown Qualification";

    if (!empty($pathwayJson[0])) {
        $pathwayName = $pathwayJson[0]['name'] ?? $pathwayName;
        if (!empty($pathwayJson[0]['qual_types'][0]['qualification'])) {
            $qual = $pathwayJson[0]['qual_types'][0]['qualification'];
            $qualificationName = $qual['name'] ?? $qualificationName;
            foreach ($qual['unitStandards'] as $us) {
                $allowedUnitStandards[(string)$us['id']] = $us['name'];
            }
        }
    }

    // 3. Fetch ALL assessments for this project and ALL POE/Marks for this learner
    $query = "
        SELECT 
            a.unit_standard_id,
            a.assessment_type,
            a.question_number,
            a.specific_outcome,
            a.assessment_criteria,
            a.exercise,
            a.marks,
            a.question_type,
            p.filePath,
            m.marks_scored,
            m.a_comment,
            m.comment,
            m.approval_status,
            m.moderator_status,
            m.moderator_comment,
            p.exercise AS poe_exercise,
            p.type AS poe_type
        FROM 
            assessments a
        LEFT JOIN 
            poe p ON p.learnerID = ? 
            AND (
                TRIM(REPLACE(REPLACE(REPLACE(p.exercise, '\r', ''), '\n', ''), ' ', '')) = TRIM(REPLACE(REPLACE(REPLACE(a.exercise, '\r', ''), '\n', ''), ' ', ''))
                OR p.exercise = a.exercise
            )
            AND LOWER(p.type) = LOWER(CASE WHEN a.question_type = 'Practical' THEN 'LogBook' ELSE a.assessment_type END)
        LEFT JOIN 
            marks m ON m.learnerID = ? 
            AND (
                TRIM(REPLACE(REPLACE(REPLACE(m.exercise, '\r', ''), '\n', ''), ' ', '')) = TRIM(REPLACE(REPLACE(REPLACE(a.exercise, '\r', ''), '\n', ''), ' ', ''))
                OR m.exercise = a.exercise
            )
            AND LOWER(m.type) = LOWER(CASE WHEN a.question_type = 'Practical' THEN 'LogBook' ELSE a.assessment_type END)
        WHERE 
            a.project_id = ?
        ORDER BY 
            a.unit_standard_id, a.question_number ASC
    ";

    $stmt = $conn->prepare($query);
    $stmt->bind_param('iii', $learnerID, $learnerID, $projectId);
    $stmt->execute();
    $result = $stmt->get_result();

    $data = [
        'pathways' => [
            $pathwayName => [
                'qualifications' => [
                    $qualificationName => [
                        'unitstandards' => []
                    ]
                ]
            ]
        ]
    ];

    $unitStandardsList = &$data['pathways'][$pathwayName]['qualifications'][$qualificationName]['unitstandards'];
    $processedAssessments = [];

    while ($row = $result->fetch_assoc()) {
        $usId = (string)$row['unit_standard_id'];
        
        // Filter: Only include assessments that belong to the learner's pathway
        if (!isset($allowedUnitStandards[$usId])) continue;

        $usName = $usId . " - " . $allowedUnitStandards[$usId];
        if (!isset($unitStandardsList[$usName])) {
            $unitStandardsList[$usName] = [
                'formative' => [], 'summative' => [], 'logbook' => [], 'formativeremedial' => [], 'summativeremedial' => []
            ];
        }

        $type = strtolower($row['assessment_type']);
        if ($row['question_type'] == 'Practical') $type = 'logbook';
        
        $exercise = $row['exercise'];
        $qNum = $row['question_number'];
        $key = md5($usId . $type . $qNum . $exercise);

        if (isset($processedAssessments[$key])) {
            // Prioritize record with file if we have duplicates
            if (empty($processedAssessments[$key]['filePath']) && !empty($row['filePath'])) {
                // Find and update existing record
                foreach ($unitStandardsList[$usName][$type] as &$existing) {
                    if ($existing['question_number'] == $qNum && $existing['exercise'] == $exercise) {
                        $existing['filePath'] = $row['filePath'];
                        $existing['fileUrl'] = $baseUrl . 'mobile/' . ltrim($row['filePath'], '/');
                        break;
                    }
                }
            }
            continue;
        }

        $assessment = [
            'question_number' => $row['question_number'],
            'specific_outcome' => $row['specific_outcome'],
            'assessment_criteria' => $row['assessment_criteria'],
            'exercise' => $row['exercise'],
            'marks' => $row['marks'],
            'filePath' => !empty($row['filePath']) ? $row['filePath'] : null,
            'fileUrl' => !empty($row['filePath']) ? $baseUrl . 'mobile/' . ltrim($row['filePath'], '/') : null,
            'marks_scored' => $row['marks_scored'],
            'a_comment' => $row['a_comment'],
            'comment' => $row['comment'],
            'approval_status' => $row['approval_status'],
            'moderator_status' => $row['moderator_status'],
            'moderator_comment' => $row['moderator_comment'],
            'question_type' => $row['question_type']
        ];

        $unitStandardsList[$usName][$type][] = $assessment;
        $processedAssessments[$key] = $assessment;
    }

    // 4. BULK UPLOAD FALLBACK (Manual pass to ensure "All Questions" files are linked)
    $bulkQuery = "SELECT exercise, filePath, type FROM poe WHERE learnerID = ? AND (exercise LIKE '%All%' OR exercise LIKE '%Bulk%' OR exercise LIKE '%Entries%')";
    $stmt = $conn->prepare($bulkQuery);
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $bulkRes = $stmt->get_result();
    while ($bp = $bulkRes->fetch_assoc()) {
        if (empty($bp['filePath'])) continue;
        
        $ex = $bp['exercise'];
        $type = strtolower($bp['type']);
        if (strpos($type, 'log') !== false) $type = 'logbook';

        // Extract unit ID from bulk file name
        if (preg_match('/(\d{4,10})/', $ex, $matches)) {
            $unitId = $matches[1];
            foreach ($unitStandardsList as $name => &$sections) {
                if (strpos($name, $unitId) !== false && isset($sections[$type])) {
                    foreach ($sections[$type] as &$q) {
                        if (empty($q['filePath'])) {
                            $q['filePath'] = $bp['filePath'];
                            $q['fileUrl'] = $baseUrl . 'mobile/' . ltrim($bp['filePath'], '/');
                        }
                    }
                }
            }
        }
    }
    $stmt->close();

    $conn->close();
    echo json_encode($data, JSON_PRETTY_PRINT);
}
?>