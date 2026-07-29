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

    // SQL Query to fetch POE data with file paths and multiple unit standards
    // Updated LEFT JOIN to assessments to handle both numeric and string IDs in JSON
    // Updated LEFT JOIN to poe to extract unit_standard_id from p.exercise format "All Questions - {ID} - {Name}..." 
    // and match on unit_standard_id + type instead of exact exercise match
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

    // Also get ALL known unit standard IDs from the system to prevent cross-matching shared questions
    $allUsIds = [];
    $allUsRes = $conn->query("SELECT DISTINCT unit_standard_id FROM assessments");
    while($usRow = $allUsRes->fetch_assoc()) {
        $allUsIds[] = (string)$usRow['unit_standard_id'];
    }
    $allUsList = "'" . implode("','", $allUsIds) . "'";

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
                            
                            // Aggressively remove ID from the start if it exists (e.g., "259604 - ...")
                            // Matches ID followed by hyphen, colon, or space
                            $usCleanName = preg_replace('/^' . preg_quote($usId, '/') . '\s*[:\-–—\s]*/', '', $usRawName);
                            $usName = $usId . " - " . $usCleanName;

                            $allowedUnitStandards[$usId] = [
                                'name' => $usCleanName,
                                'pathway' => $pName,
                                'qualification' => $qName
                            ];
                            $allowedIds[] = $usId;
                            
                            // Pre-populate every unit standard from the pathway
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
            p.filePath, m.marks_scored, m.a_comment, m.comment, m.approval_status, m.moderator_status, m.moderator_comment
        FROM assessments a
        LEFT JOIN poe p ON p.learnerID = ? 
            AND (TRIM(REPLACE(REPLACE(REPLACE(p.exercise, '\r', ''), '\n', ''), ' ', '')) = TRIM(REPLACE(REPLACE(REPLACE(a.exercise, '\r', ''), '\n', ''), ' ', '')) OR p.exercise = a.exercise OR p.exercise LIKE CONCAT('%', a.exercise, '%'))
            AND (
                LOWER(p.type) = LOWER(CASE WHEN a.question_type = 'Practical' THEN 'LogBook' ELSE a.assessment_type END)
                OR (a.assessment_type = 'Formative' AND LOWER(p.type) = 'formativeremedial')
                OR (a.assessment_type = 'Summative' AND LOWER(p.type) = 'summativeremedial')
            )
        LEFT JOIN marks m ON m.learnerID = ? 
            AND (TRIM(REPLACE(REPLACE(REPLACE(m.exercise, '\r', ''), '\n', ''), ' ', '')) = TRIM(REPLACE(REPLACE(REPLACE(a.exercise, '\r', ''), '\n', ''), ' ', '')) OR m.exercise = a.exercise)
            AND (
                LOWER(m.type) = LOWER(CASE WHEN a.question_type = 'Practical' THEN 'LogBook' ELSE a.assessment_type END)
                OR (a.assessment_type = 'Formative' AND LOWER(m.type) = 'formativeremedial')
                OR (a.assessment_type = 'Summative' AND LOWER(m.type) = 'summativeremedial')
            )
        WHERE a.project_id = ? AND a.unit_standard_id IN ($idList)
        ORDER BY a.unit_standard_id, a.question_number ASC
    ";

    $stmt = $conn->prepare($query);
    $stmt->bind_param('iii', $learnerID, $learnerID, $projectId);
    $stmt->execute();
    $result = $stmt->get_result();

    $processedAssessments = [];

    while ($row = $result->fetch_assoc()) {
        $usId = (string)$row['unit_standard_id'];
        if (!isset($allowedUnitStandards[$usId])) continue;
        
        // Check if this POE file belongs to a different unit standard - if yes, skip it
        $skipThisPoeFile = false;
        if (!empty($row['filePath'])) {
            // Extract all 4-10 digit numbers from filePath and exercise
            $unitIdsInFile = [];
            if (preg_match_all('/(^|[^0-9])([0-9]{4,10})([^0-9]|$)/', $row['filePath'], $matches)) {
                $unitIdsInFile = array_merge($unitIdsInFile, $matches[2]);
            }
            if (!empty($row['exercise'])) {
                if (preg_match_all('/(^|[^0-9])([0-9]{4,10})([^0-9]|$)/', $row['exercise'], $matches)) {
                    $unitIdsInFile = array_merge($unitIdsInFile, $matches[2]);
                }
            }
            $unitIdsInFile = array_unique($unitIdsInFile);
            // If there are any unit IDs in the file/exercise and none of them match the current assessment's unit ID, skip this file
            if (!empty($unitIdsInFile) && !in_array($usId, $unitIdsInFile)) {
                $skipThisPoeFile = true;
            }
        }

        $pName = $allowedUnitStandards[$usId]['pathway'];
        $qName = $allowedUnitStandards[$usId]['qualification'];
        $usName = $usId . " - " . $allowedUnitStandards[$usId]['name'];

        $type = strtolower($row['assessment_type']);
        if ($row['question_type'] == 'Practical') $type = 'logbook';
        
        $key = md5($usId . $type . $row['question_number'] . $row['exercise']);
        if (isset($processedAssessments[$key])) {
            if (empty($processedAssessments[$key]['filePath']) && !empty($row['filePath']) && !$skipThisPoeFile) {
                foreach ($data['pathways'][$pName]['qualifications'][$qName]['unitstandards'][$usName][$type] as &$existing) {
                    if ($existing['question_number'] == $row['question_number'] && $existing['exercise'] == $row['exercise']) {
                        $existing['filePath'] = $row['filePath'];
                        $existing['fileUrl'] = $baseUrl . 'mobile/' . ltrim($row['filePath'], '/');
                        break;
                    }
                }
            }
            continue;
        }

        $assessment = [
            'question_number' => $row['question_number'], 'specific_outcome' => $row['specific_outcome'], 'assessment_criteria' => $row['assessment_criteria'],
            'exercise' => $row['exercise'], 'marks' => $row['marks'], 
            'filePath' => (!$skipThisPoeFile && !empty($row['filePath'])) ? $row['filePath'] : null,
            'fileUrl' => (!$skipThisPoeFile && !empty($row['filePath'])) ? $baseUrl . 'mobile/' . ltrim($row['filePath'], '/') : null,
            'marks_scored' => $row['marks_scored'], 'a_comment' => $row['a_comment'], 'comment' => $row['comment'],
            'approval_status' => $row['approval_status'], 'moderator_status' => $row['moderator_status'], 'moderator_comment' => $row['moderator_comment'], 'question_type' => $row['question_type']
        ];
        $data['pathways'][$pName]['qualifications'][$qName]['unitstandards'][$usName][$type][] = $assessment;
        $processedAssessments[$key] = $assessment;
    }

    // 4. BULK UPLOAD FALLBACK (Optimized & More Inclusive)
    $bulkRes = $conn->query("SELECT exercise, filePath, type FROM poe WHERE learnerID = $learnerID");
    
    // Create a lookup map for faster unit standard access: unitId -> [references to sections]
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
        if (empty($bp['filePath'])) continue;
        
        // Extract ALL unit IDs from either exercise name or filePath
        $foundUnitIds = [];
        
        // Match any 4-6 digit numbers in exercise or path
        if (preg_match_all('/(^|[^0-9])([0-9]{4,6})([^0-9]|$)/', $bp['exercise'], $matches)) {
            foreach ($matches[2] as $id) if (isset($unitLookup[$id])) $foundUnitIds[] = $id;
        }
        if (preg_match_all('/(^|[^0-9])([0-9]{4,6})([^0-9]|$)/', $bp['filePath'], $matches)) {
            foreach ($matches[2] as $id) if (isset($unitLookup[$id])) $foundUnitIds[] = $id;
        }
        
        // Also check if it's a generic "All Questions" record that doesn't have an ID
        // (but this is risky, so we only do it if no ID found)
        if (empty($foundUnitIds) && (stripos($bp['exercise'], 'All') !== false || stripos($bp['exercise'], 'Bulk') !== false)) {
            // If it's a generic bulk record, we might want to apply it to ALL unit standards?
            // Actually, let's stick to tagged records for now to be safe.
        }
        
        $foundUnitIds = array_unique($foundUnitIds);
        if (empty($foundUnitIds)) continue;
        
        $type = strtolower($bp['type']);
        if (strpos($type, 'log') !== false) $type = 'logbook';
        
        // If it's a remedial type, we might want to fall back to the main type if needed
        $altType = null;
        if ($type == 'formativeremedial') $altType = 'formative';
        if ($type == 'summativeremedial') $altType = 'summative';

        foreach ($foundUnitIds as $unitId) {
            if (isset($unitLookup[$unitId])) {
                foreach ($unitLookup[$unitId] as &$sections) {
                    // Try the primary type
                    if (isset($sections[$type])) {
                        foreach ($sections[$type] as &$q) {
                            if (empty($q['filePath'])) {
                                $q['filePath'] = $bp['filePath'];
                                $q['fileUrl'] = $baseUrl . 'mobile/' . ltrim($bp['filePath'], '/');
                            }
                        }
                    }
                    // If no main file found and we have an alternative type (Remedial -> Main)
                    if ($altType && isset($sections[$altType])) {
                        foreach ($sections[$altType] as &$q) {
                            if (empty($q['filePath'])) {
                                $q['filePath'] = $bp['filePath'];
                                $q['fileUrl'] = $baseUrl . 'mobile/' . ltrim($bp['filePath'], '/');
                            }
                        }
                    }
                }
            }
        }
    }

    // Close statement and connection
    $conn->close();

    echo json_encode($data, JSON_PRETTY_PRINT);
} else {
    echo json_encode(['error' => 'Invalid request method. Please use POST or GET.']);
}
?>