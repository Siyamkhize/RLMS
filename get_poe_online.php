<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");
include('connection.php');

// Handle GET or POST request
if ($_SERVER['REQUEST_METHOD'] == 'POST' || $_SERVER['REQUEST_METHOD'] == 'GET') {
    $learnerID = ($_SERVER['REQUEST_METHOD'] == 'POST') ? 
                 (isset($_POST['learnerID']) ? intval($_POST['learnerID']) : 0) : 
                 (isset($_GET['learnerId']) ? intval($_GET['learnerId']) : 0);

    if ($learnerID <= 0) {
        echo json_encode(['error' => 'Invalid learnerID provided.']);
        exit;
    }

    // ONLINE CONFIGURATION: Fixed to live server domain
    $host = 'rlms.rlms.co.za';
    $protocol = 'https';
    $baseUrl = "$protocol://$host/"; // Live server root

    // 1. Fetch learner pathway and project ID
    $learnerQuery = "
        SELECT ld.LearnerID, pr.project_id, pr.Project_pathway
        FROM learnerdetails ld 
        LEFT JOIN class c ON ld.classID = c.classID 
        LEFT JOIN sites s ON c.siteID = s.siteID 
        LEFT JOIN project pr ON s.project_id = pr.project_id
        WHERE ld.LearnerID = ?
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
    
    // 2. Extract allowed Unit Standards for this learner
    $data = ['pathways' => []];
    $allowedUnitStandards = [];
    $allowedIds = [];

    foreach ($pathwayJson as $pathway) {
        $pName = $pathway['name'] ?? "Unknown Pathway";
        if (!isset($data['pathways'][$pName])) {
            $data['pathways'][$pName] = ['qualifications' => []];
        }

        if (!empty($pathway['qual_types'])) {
            foreach ($pathway['qual_types'] as $qualType) {
                if (!empty($qualType['qualification'])) {
                    $qual = $qualType['qualification'];
                    $qName = $qual['name'] ?? "Unknown Qualification";
                    
                    if (!isset($data['pathways'][$pName]['qualifications'][$qName])) {
                        $data['pathways'][$pName]['qualifications'][$qName] = ['unitstandards' => []];
                    }

                    if (!empty($qual['unitStandards'])) {
                        foreach ($qual['unitStandards'] as $us) {
                            $usId = (string)$us['id'];
                            $usRawName = trim($us['name'] ?? 'Unknown');
                            
                            $usCleanName = preg_replace('/^' . preg_quote($usId, '/') . '\s*[:\-–—\s]*/', '', $usRawName);
                            $usName = $usId . " - " . $usCleanName;

                            $allowedUnitStandards[$usId] = [
                                'name' => $usCleanName,
                                'pathway' => $pName,
                                'qualification' => $qName
                            ];
                            $allowedIds[] = $usId;
                            
                            $data['pathways'][$pName]['qualifications'][$qName]['unitstandards'][$usName] = [
                                'formative' => [],
                                'summative' => [],
                                'logbook' => [],
                                'formativeremedial' => [],
                                'summativeremedial' => []
                            ];
                        }
                    }
                }
            }
        }
    }

    if (empty($allowedIds)) {
        echo json_encode(['error' => 'No unit standards found in pathway.']);
        exit;
    }

    // 3. Fetch ALL assessments for this project and ALL POE/Marks for this learner
    $idList = implode(',', array_map('intval', $allowedIds));
    $query = "
        SELECT 
            a.unit_standard_id, a.assessment_type, a.question_number, a.specific_outcome, a.assessment_criteria, a.exercise, a.marks, a.question_type,
            p.filePath, m.marks_scored, m.a_comment, m.comment, m.approval_status, m.moderator_status, m.moderator_comment, m.type as mark_type
        FROM assessments a
        LEFT JOIN poe p ON p.learnerID = ? 
            AND (TRIM(REPLACE(REPLACE(REPLACE(p.exercise, '\r', ''), '\n', ''), ' ', '')) = TRIM(REPLACE(REPLACE(REPLACE(a.exercise, '\r', ''), '\n', ''), ' ', '')) OR p.exercise = a.exercise)
            AND (
                LOWER(p.type) = LOWER(CASE WHEN a.question_type = 'Practical' THEN 'LogBook' ELSE a.assessment_type END)
                OR LOWER(p.type) = LOWER(CONCAT(CASE WHEN a.question_type = 'Practical' THEN 'LogBook' ELSE a.assessment_type END, 'Remedial'))
            )
        LEFT JOIN marks m ON m.learnerID = ? 
            AND (TRIM(REPLACE(REPLACE(REPLACE(m.exercise, '\r', ''), '\n', ''), ' ', '')) = TRIM(REPLACE(REPLACE(REPLACE(a.exercise, '\r', ''), '\n', ''), ' ', '')) OR m.exercise = a.exercise)
            AND (
                LOWER(m.type) = LOWER(CASE WHEN a.question_type = 'Practical' THEN 'LogBook' ELSE a.assessment_type END)
                OR LOWER(m.type) = LOWER(CONCAT(CASE WHEN a.question_type = 'Practical' THEN 'LogBook' ELSE a.assessment_type END, 'Remedial'))
            )
        WHERE a.project_id = ? AND a.unit_standard_id IN ($idList)
        ORDER BY a.unit_standard_id, a.question_number ASC, m.type DESC
    ";

    $stmt = $conn->prepare($query);
    $stmt->bind_param('iii', $learnerID, $learnerID, $projectId);
    $stmt->execute();
    $result = $stmt->get_result();

    $processedAssessments = [];

    while ($row = $result->fetch_assoc()) {
        $usId = (string)$row['unit_standard_id'];
        if (!isset($allowedUnitStandards[$usId])) continue;

        $pName = $allowedUnitStandards[$usId]['pathway'];
        $qName = $allowedUnitStandards[$usId]['qualification'];
        $usName = $usId . " - " . $allowedUnitStandards[$usId]['name'];

        $type = strtolower($row['assessment_type']);
        if ($row['question_type'] == 'Practical') $type = 'logbook';
        
        $key = md5($usId . $type . $row['question_number'] . $row['exercise']);
        
        // If we already saw this question, check if we should update it
        if (isset($processedAssessments[$key])) {
            // Update filePath if this row has one and the previous didn't
            if (empty($processedAssessments[$key]['filePath']) && !empty($row['filePath'])) {
                foreach ($data['pathways'][$pName]['qualifications'][$qName]['unitstandards'][$usName][$type] as &$existing) {
                    if ($existing['question_number'] == $row['question_number'] && $existing['exercise'] == $row['exercise']) {
                        $existing['filePath'] = $row['filePath'];
                        $existing['fileUrl'] = $baseUrl . 'mobile/' . ltrim($row['filePath'], '/');
                        break;
                    }
                }
                $processedAssessments[$key]['filePath'] = $row['filePath'];
            }
            
            // Update marks if this row has a mark and the previous didn't, or if this is a remedial mark
            $isRemedial = (stripos($row['mark_type'] ?? '', 'remedial') !== false);
            if ((isset($row['marks_scored']) && $row['marks_scored'] !== '') || $isRemedial) {
                 foreach ($data['pathways'][$pName]['qualifications'][$qName]['unitstandards'][$usName][$type] as &$existing) {
                    if ($existing['question_number'] == $row['question_number'] && $existing['exercise'] == $row['exercise']) {
                        // Prefer remedial mark if available, or if existing mark is empty
                        if ($isRemedial || !isset($existing['marks_scored']) || $existing['marks_scored'] === '') {
                            $existing['marks_scored'] = $row['marks_scored'];
                            $existing['a_comment'] = $row['a_comment'];
                            $existing['comment'] = $row['comment'];
                            $existing['approval_status'] = $row['approval_status'];
                            $existing['moderator_status'] = $row['moderator_status'];
                            $existing['moderator_comment'] = $row['moderator_comment'];
                            $existing['mark_type'] = $row['mark_type'];
                        }
                        break;
                    }
                }
            }
            continue;
        }

        $assessment = [
            'question_number' => $row['question_number'], 'specific_outcome' => $row['specific_outcome'], 'assessment_criteria' => $row['assessment_criteria'],
            'exercise' => $row['exercise'], 'marks' => $row['marks'], 'filePath' => !empty($row['filePath']) ? $row['filePath'] : null,
            'fileUrl' => !empty($row['filePath']) ? $baseUrl . 'mobile/' . ltrim($row['filePath'], '/') : null,
            'marks_scored' => $row['marks_scored'], 'a_comment' => $row['a_comment'], 'comment' => $row['comment'],
            'approval_status' => $row['approval_status'], 'moderator_status' => $row['moderator_status'], 'moderator_comment' => $row['moderator_comment'], 
            'question_type' => $row['question_type'], 'mark_type' => $row['mark_type'], 'type' => $row['assessment_type']
        ];
        $data['pathways'][$pName]['qualifications'][$qName]['unitstandards'][$usName][$type][] = $assessment;
        $processedAssessments[$key] = $assessment;
    }

    // 4. BULK UPLOAD FALLBACK (Optimized)
    $bulkRes = $conn->query("SELECT exercise, filePath, type FROM poe WHERE learnerID = $learnerID AND (exercise LIKE '%All%' OR exercise LIKE '%Bulk%' OR exercise LIKE '%Entries%')");
    
    $unitLookup = [];
    foreach ($data['pathways'] as $pName => &$pData) {
        foreach ($pData['qualifications'] as $qName => &$qData) {
            foreach ($qData['unitstandards'] as $name => &$sections) {
                if (preg_match('/^(\d+)/', $name, $m)) {
                    $unitLookup[$m[1]][] = &$sections;
                }
            }
        }
    }

    while ($bp = $bulkRes->fetch_assoc()) {
        if (empty($bp['filePath']) || !preg_match('/(\d{4,10})/', $bp['exercise'], $matches)) continue;
        $unitId = $matches[1];
        $type = strtolower($bp['type']);
        if (strpos($type, 'log') !== false) $type = 'logbook';
        
        if (isset($unitLookup[$unitId])) {
            foreach ($unitLookup[$unitId] as &$sections) {
                if (isset($sections[$type])) {
                    if (!empty($sections[$type])) {
                        foreach ($sections[$type] as &$q) {
                            if (empty($q['filePath'])) {
                                $q['filePath'] = $bp['filePath'];
                                $q['fileUrl'] = $baseUrl . 'mobile/' . ltrim($bp['filePath'], '/');
                            }
                        }
                    } else {
                        $sections[$type][] = [
                            'question_number' => 'Bulk',
                            'exercise' => $bp['exercise'],
                            'filePath' => $bp['filePath'],
                            'fileUrl' => $baseUrl . 'mobile/' . ltrim($bp['filePath'], '/'),
                            'question_type' => 'Bulk'
                        ];
                    }
                }
            }
        }
    }

    $conn->close();
    echo json_encode($data, JSON_PRETTY_PRINT);
} else {
    echo json_encode(['error' => 'Invalid request method.']);
}
?>