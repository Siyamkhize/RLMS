<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Include connection from same directory (mobile folder)
require_once 'connection.php';

set_time_limit(60);
ini_set('max_execution_time', 60);

if ($_SERVER['REQUEST_METHOD'] == 'POST' || $_SERVER['REQUEST_METHOD'] == 'GET') {
    $learnerIdPost = isset($_POST['learner_id']) ? intval($_POST['learner_id']) : 0;
    $learnerIdGet = isset($_GET['learner_id']) ? intval($_GET['learner_id']) : 0;
    $learner_id = ($_SERVER['REQUEST_METHOD'] == 'POST') ? $learnerIdPost : $learnerIdGet;

    if ($learner_id <= 0) {
        echo json_encode(['error' => 'Invalid learner_id provided.']);
        exit;
    }

    // Get base URL from connection configuration
    // This will be set properly on the production server
    $baseUrl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://" . $_SERVER['HTTP_HOST'] . "/mobile/";

    $data = [
        'pathways' => [
            'ARPL' => [
                'qualifications' => []
            ]
        ],
        '_debug' => []
    ];

    // Helper function to get table columns
    function getTableColumns($conn, $tableName) {
        $columns = [];
        $result = $conn->query("DESCRIBE $tableName");
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                $columns[] = $row['Field'];
            }
        }
        return $columns;
    }

    // Helper function to convert empty arrays to objects for JSON encoding
    // This ensures empty arrays become {} instead of [] in JSON
    function convertEmptyArraysToObjects(&$data) {
        if (is_array($data)) {
            // If array is empty and associative (should be object in JSON)
            if (empty($data)) {
                return new stdClass();
            }
            // Recursively process all values
            foreach ($data as $key => &$value) {
                $data[$key] = convertEmptyArraysToObjects($value);
            }
        }
        return $data;
    }

    // Map of OFO codes to trade names
    $ofoCodeMap = [
        '671101' => 'Electrician',
        '642601' => 'Plumber',
        '641201' => 'Bricklaying'
    ];

    // Step 1: Get learner details to find their class
    $learnerQuery = "SELECT * FROM learnerdetails WHERE LearnerID = $learner_id LIMIT 1";
    $learnerResult = $conn->query($learnerQuery);
    if (!$learnerResult) {
        $data['_debug'][] = "Learner query failed: " . $conn->error;
    } elseif ($learnerResult->num_rows == 0) {
        $data['_debug'][] = "No learner found with ID $learner_id";
    } else {
        $learner = $learnerResult->fetch_assoc();
        $data['_debug'][] = "Found learner: " . json_encode($learner);
        $classID = $learner['classID'] ?? null;

        // Step 2: Get class details and JOIN with arpl_trades to find the trade
        $classOfo = null;
        $qualName = null;
        if ($classID) {
            $classQuery = "
                SELECT 
                    c.*,
                    t.trade_name,
                    t.ofo_number
                FROM class c
                LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
                WHERE c.classID = $classID 
                LIMIT 1
            ";
            $classResult = $conn->query($classQuery);
            if (!$classResult) {
                $data['_debug'][] = "Class query failed: " . $conn->error;
            } elseif ($classResult->num_rows > 0) {
                $class = $classResult->fetch_assoc();
                $data['_debug'][] = "Found class with trade_id: " . ($class['trade_id'] ?? 'NULL');
                
                // Get OFO and trade name from JOIN result
                $classOfo = $class['ofo_number'] ?? null;
                $qualName = $class['trade_name'] ?? null;
                
                $data['_debug'][] = "From arpl_trades table - Trade: " . ($qualName ?? 'NULL') . ", OFO: " . ($classOfo ?? 'NULL');
            }
        }

        // If no trade from arpl_trades, try fallback to hardcoded OFO map
        if (!$classOfo || !$qualName) {
            $classOfo = '671101';
            $qualName = 'Electrician';
            $data['_debug'][] = "No trade found via JOIN, using default Electrician: 671101";
        }

        $data['_debug'][] = "Final trade selected: $qualName (OFO: $classOfo)";

        // Step 3: Get ARPL papers for this trade OFO code
        $papersTableExists = $conn->query("SHOW TABLES LIKE 'arpl_papers'");
        $papersById = [];

        if ($papersTableExists && $papersTableExists->num_rows > 0) {
            $papersColumns = getTableColumns($conn, 'arpl_papers');
            $data['_debug'][] = "arpl_papers columns: " . json_encode($papersColumns);

            // Query papers by trade_ofo_code
            $papersQuery = "SELECT * FROM arpl_papers WHERE trade_ofo_code = '$classOfo' ORDER BY paper_number, paper_type";
            $papersResult = $conn->query($papersQuery);
            if (!$papersResult) {
                $data['_debug'][] = "Papers query failed: " . $conn->error;
            } else {
                while ($row = $papersResult->fetch_assoc()) {
                    $paperId = $row['id'];
                    $papersById[$paperId] = $row;
                    $data['_debug'][] = "Loaded paper ID $paperId: " . $row['paper_title'];
                }
                $data['_debug'][] = "Total papers loaded: " . count($papersById);
            }
        }

        // Initialize qualification structure with papers organized by type and number
        $data['pathways']['ARPL']['qualifications'][$qualName] = [
            'theory_papers' => [],
            'practical_papers' => []
        ];

        // Build paper structure organized by paper_type
        if (!empty($papersById)) {
            foreach ($papersById as $paperId => $paper) {
                $paperType = strtolower($paper['paper_type'] ?? 'theory');
                $groupKey = str_contains($paperType, 'practical') ? 'practical_papers' : 'theory_papers';
                $paperName = $paper['paper_title'] ?? 'Paper';

                $data['pathways']['ARPL']['qualifications'][$qualName][$groupKey][$paperName] = [
                    'paper_id' => $paperId,
                    'paper_number' => $paper['paper_number'] ?? null,
                    'paper_type' => $paperType,
                    'total_marks' => $paper['total_marks'] ?? 100,
                    'questions' => []
                ];
            }
            $data['_debug'][] = "Created paper structure with " . count($papersById) . " papers";
        } else {
            $data['_debug'][] = "No papers found for OFO code: $classOfo";
        }

        // Step 4: Get ARPL questions and link them to papers by paper_id
        $questionsTableExists = $conn->query("SHOW TABLES LIKE 'arpl_questions'");

        if ($questionsTableExists && $questionsTableExists->num_rows > 0) {
            $questionsColumns = getTableColumns($conn, 'arpl_questions');
            $data['_debug'][] = "arpl_questions columns: " . json_encode($questionsColumns);

            $questionsQuery = "SELECT * FROM arpl_questions ORDER BY paper_id, question_number";
            $questionsResult = $conn->query($questionsQuery);
            if (!$questionsResult) {
                $data['_debug'][] = "Questions query failed: " . $conn->error;
            } else {
                $questionsProcessed = 0;
                while ($row = $questionsResult->fetch_assoc()) {
                    $questionPaperId = $row['paper_id'] ?? null;

                    // Find the paper this question belongs to
                    if ($questionPaperId && isset($papersById[$questionPaperId])) {
                        $paper = $papersById[$questionPaperId];
                        $paperType = strtolower($paper['paper_type'] ?? 'theory');
                        $groupKey = str_contains($paperType, 'practical') ? 'practical_papers' : 'theory_papers';
                        $paperName = $paper['paper_title'] ?? 'Paper';

                        // Create assessment object
                        $questionNumber = isset($row['question_number']) ? intval($row['question_number']) : (isset($row['number']) ? intval($row['number']) : 0);
                        $marks = isset($row['marks']) ? intval($row['marks']) : (isset($row['mark']) ? intval($row['mark']) : 0);

                        $assessment = [
                            'question_number' => $questionNumber,
                            'specific_outcome' => $row['specific_outcome'] ?? '',
                            'assessment_criteria' => $row['assessment_criteria'] ?? '',
                            'exercise' => $row['question_text'] ?? $row['text'] ?? '',
                            'marks' => $marks,
                            'filePath' => null,
                            'fileUrl' => null,
                            'marks_scored' => null,
                            'a_comment' => null,
                            'comment' => null,
                            'approval_status' => null,
                            'moderator_status' => null,
                            'moderator_comment' => null,
                            'question_type' => $row['question_type'] ?? 'Theory'
                        ];

                        // Add question to the paper
                        if (isset($data['pathways']['ARPL']['qualifications'][$qualName][$groupKey][$paperName])) {
                            $data['pathways']['ARPL']['qualifications'][$qualName][$groupKey][$paperName]['questions'][] = $assessment;
                            $questionsProcessed++;
                        }
                    }
                }
                $data['_debug'][] = "Total questions processed: $questionsProcessed";
            }
        }

        // Step 5: Try to match POE files
        $poeTableExists = $conn->query("SHOW TABLES LIKE 'poe'");
        if ($poeTableExists && $poeTableExists->num_rows > 0) {
            $poeQuery = "SELECT * FROM poe WHERE learnerID = $learner_id";
            $poeResult = $conn->query($poeQuery);
            if ($poeResult) {
                while ($poeRow = $poeResult->fetch_assoc()) {
                    foreach ($data['pathways'] as $pathwayName => &$pathwayData) {
                        foreach ($pathwayData['qualifications'] as $qualName => &$qualData) {
                            foreach (['theory_papers', 'practical_papers'] as $groupKey) {
                                if (isset($qualData[$groupKey])) {
                                    foreach ($qualData[$groupKey] as $paperName => &$paperData) {
                                        foreach ($paperData['questions'] as &$question) {
                                            $match = false;
                                            if (isset($question['exercise']) && isset($poeRow['exercise'])) {
                                                $exercisePart = substr($poeRow['exercise'], 0, 50);
                                                $questionPart = substr($question['exercise'], 0, 50);
                                                $match = (stripos($question['exercise'], $exercisePart) !== false ||
                                                          stripos($poeRow['exercise'], $questionPart) !== false);
                                            }
                                            if ($match && isset($poeRow['filePath'])) {
                                                $question['filePath'] = $poeRow['filePath'];
                                                $question['fileUrl'] = $baseUrl . 'serve_file.php?file=' . urlencode(ltrim($poeRow['filePath'], '/')) . '&learner_id=' . $learner_id;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Convert empty arrays to objects before JSON encoding
    // This ensures empty theory_papers/practical_papers become {} not []
    $data['pathways']['ARPL']['qualifications'] = convertEmptyArraysToObjects($data['pathways']['ARPL']['qualifications']);

    $conn->close();
    echo json_encode($data, JSON_PRETTY_PRINT);
} else {
    echo json_encode(['error' => 'Invalid request method']);
}
