<?php
ob_start();
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', '/public_html/logs/php_errors.log');

try {
    // Include database connection
    include('connection.php');
    $conn = new mysqli($servername, $username, $password, $dbname);
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }

    // Get request parameters
    $learnerID = isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0;
    $unit_standard_id = isset($_GET['unit_standard_id']) ? trim($_GET['unit_standard_id']) : '';
    error_log("System Tagging Request: learnerID=$learnerID, unit_standard_id=$unit_standard_id");

    // Handle AJAX system tagging request
    if (isset($_POST['action']) && $_POST['action'] === 'system_tag' && isset($_POST['exercises'])) {
        header('Content-Type: application/json; charset=utf-8');
        $exercises = json_decode($_POST['exercises'], true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("JSON decode error: " . json_last_error_msg());
        }
        if (!is_array($exercises)) {
            throw new Exception("Exercises parameter must be an array");
        }

        $response = ['success' => false, 'messages' => [], 'errors' => []];
        $conn->begin_transaction();

        try {
            foreach ($exercises as $item) {
                if (!isset($item['exercise'], $item['type'], $item['question_number'])) {
                    $response['errors'][] = "Missing required fields in exercise data";
                    continue;
                }

                $selected_exercise = $item['exercise'];
                $type = $item['type'];
                $question_number = $item['question_number'];

                // Check if files exist for this assessment type before allowing system tagging
                $sql_check_files = "SELECT p.filePath FROM poe p 
                                   WHERE p.learnerID = ? AND p.type = ? 
                                   AND (
                                       p.filePath LIKE CONCAT('%', ?, '_', ?, '_%') 
                                       OR p.filePath LIKE CONCAT('%_', ?, '_%')
                                       OR p.exercise LIKE CONCAT('%All Questions - ', ?, ' -%')
                                       OR EXISTS (
                                           SELECT 1 FROM assessments a 
                                           WHERE a.unit_standard_id = ? AND a.exercise = p.exercise
                                       )
                                   )
                                   AND p.filePath IS NOT NULL 
                                   ORDER BY p.submitted_at ASC LIMIT 1";
                $stmt = $conn->prepare($sql_check_files);
                if (!$stmt) {
                    throw new Exception("Prepare failed for file check query: " . $conn->error);
                }
                $stmt->bind_param("isssssss", $learnerID, $type, $type, $unit_standard_id, $unit_standard_id, $unit_standard_id, $unit_standard_id);
                $stmt->execute();
                $file_result = $stmt->get_result();
                
                if ($file_result->num_rows === 0) {
                    $response['errors'][] = "No completed files found for $type assessments. Cannot perform system tagging.";
                    $stmt->close();
                    continue;
                } else {
                    $completed_file = $file_result->fetch_assoc();
                }
                $stmt->close();

                // Verify the file actually exists on the filesystem
                $selected_file = $completed_file['filePath'];
                $full_file_path = $_SERVER['DOCUMENT_ROOT'] . '/' . ltrim($selected_file, '/');
                
                if (!file_exists($full_file_path)) {
                    $response['errors'][] = "File does not exist on filesystem: $selected_file";
                    continue;
                }

                // Check if this exercise already exists in POE table (by exercise only, like detection logic)
                $checkStmt = $conn->prepare("SELECT poe_id, filePath, type FROM poe WHERE learnerID = ? AND exercise = ?");
                if (!$checkStmt) {
                    throw new Exception("Prepare failed for check query: " . $conn->error);
                }
                $checkStmt->bind_param("is", $learnerID, $selected_exercise);
                $checkStmt->execute();
                $checkResult = $checkStmt->get_result();
                
                if ($checkResult->num_rows > 0) {
                    // Update existing record
                    $existing_record = $checkResult->fetch_assoc();
                    $updateStmt = $conn->prepare("UPDATE poe SET filePath = ?, type = ?, submitted_at = NOW() WHERE poe_id = ?");
                    if (!$updateStmt) {
                        throw new Exception("Prepare failed for update: " . $conn->error);
                    }
                    $updateStmt->bind_param("ssi", $selected_file, $type, $existing_record['poe_id']);
                    $updateStmt->execute();
                    $response['messages'][] = "System updated exercise '$selected_exercise' ($type) with file: " . basename($selected_file);
                    $updateStmt->close();
                } else {
                    // Insert new record
                    $insertStmt = $conn->prepare("INSERT INTO poe (learnerID, exercise, type, filePath, submitted_at) VALUES (?, ?, ?, ?, NOW())");
                    if (!$insertStmt) {
                        throw new Exception("Prepare failed for insert: " . $conn->error);
                    }
                    $insertStmt->bind_param("isss", $learnerID, $selected_exercise, $type, $selected_file);
                    $insertStmt->execute();
                    $response['messages'][] = "System tagged exercise '$selected_exercise' ($type) with file: " . basename($selected_file);
                    $insertStmt->close();
                }
                $checkStmt->close();
            }

            $conn->commit();
            $response['success'] = true;

        } catch (Exception $e) {
            $conn->rollback();
            error_log("System tagging error: " . $e->getMessage());
            $response['errors'][] = $e->getMessage();
        }

        echo json_encode($response);
        exit();
    }

    // Handle learner list (following poe_tag.php logic exactly)
    if ($learnerID <= 0) {
        $search_id = isset($_POST['search_id']) ? trim($_POST['search_id']) : '';
        $sql = "SELECT LearnerID, Name, Surname, Email, PhoneNumber, IDNumber FROM learnerdetails";
        if (!empty($search_id)) {
            $sql .= " WHERE IDNumber LIKE ?";
            $search_param = "%" . $search_id . "%";
        }
        $sql .= " ORDER BY Surname, Name";
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception("Prepare failed for learners: " . $conn->error);
        }
        if (!empty($search_id)) {
            $stmt->bind_param("s", $search_param);
        }
        $stmt->execute();
        $learners = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        error_log("Fetched " . count($learners) . " learners");
        ?>
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>System Tagging - Select Learner</title>
            <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
            <style>
                body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 20px; }
                .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 15px; box-shadow: 0 20px 40px rgba(0,0,0,0.1); overflow: hidden; }
                .header { background: linear-gradient(135deg, #4CAF50, #45a049); color: white; padding: 30px; text-align: center; }
                .header h1 { font-size: 2.5em; margin-bottom: 10px; display: flex; align-items: center; justify-content: center; gap: 15px; }
                .content { padding: 30px; }
                .search-form { display: flex; gap: 15px; align-items: center; flex-wrap: wrap; background: #f8f9fa; padding: 25px; border-radius: 10px; margin-bottom: 30px; border-left: 5px solid #4CAF50; }
                .search-form input[type="text"] { padding: 12px 15px; border: 2px solid #ddd; border-radius: 8px; font-size: 16px; min-width: 250px; }
                .btn { padding: 12px 25px; background: linear-gradient(135deg, #4CAF50, #45a049); color: white; border: none; border-radius: 8px; cursor: pointer; font-size: 16px; display: inline-flex; align-items: center; gap: 8px; }
                .btn:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(76, 175, 80, 0.3); }
                table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; box-shadow: 0 5px 15px rgba(0,0,0,0.1); }
                thead { background: linear-gradient(135deg, #2c3e50, #34495e); color: white; }
                th, td { padding: 15px; text-align: left; border-bottom: 1px solid #eee; }
                td a { color: #4CAF50; text-decoration: none; font-weight: 600; display: flex; align-items: center; gap: 8px; }
                td a:hover { color: #45a049; text-decoration: underline; }
                .no-results { text-align: center; padding: 40px; color: #666; font-size: 1.2em; display: flex; align-items: center; justify-content: center; gap: 10px; }
                .stats-card { background: linear-gradient(135deg, #667eea, #764ba2); color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; display: flex; align-items: center; justify-content: space-between; }
                .stats-number { font-size: 2.5em; font-weight: bold; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1><i class="fas fa-robot"></i> System Tagging - Learner Selection</h1>
                    <p>Select a learner to view and manage their unit standards</p>
                </div>
                <div class="content">
                    <div class="search-section">
                        <form method="POST" class="search-form">
                            <label for="search_id"><i class="fas fa-search"></i> Search by ID Number:</label>
                            <input type="text" id="search_id" name="search_id" value="<?php echo htmlspecialchars($search_id); ?>" placeholder="Enter ID number...">
                            <button type="submit" class="btn"><i class="fas fa-search"></i> Search</button>
                        </form>
                    </div>
                    <?php if (count($learners) > 0): ?>
                        <div class="stats-card">
                            <div><h3>Total Learners Found</h3><p>Active learners in the system</p></div>
                            <div class="stats-number"><?php echo count($learners); ?></div>
                        </div>
                        <table>
                            <thead>
                                <tr>
                                    <th><i class="fas fa-user"></i> Name</th>
                                    <th><i class="fas fa-id-card"></i> ID Number</th>
                                    <th><i class="fas fa-envelope"></i> Email</th>
                                    <th><i class="fas fa-phone"></i> Phone</th>
                                    <th><i class="fas fa-cogs"></i> Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($learners as $learner): ?>
                                    <tr>
                                        <td><?php echo htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']); ?></td>
                                        <td><?php echo htmlspecialchars($learner['IDNumber']); ?></td>
                                        <td><?php echo htmlspecialchars($learner['Email'] ?? 'N/A'); ?></td>
                                        <td><?php echo htmlspecialchars($learner['PhoneNumber'] ?? 'N/A'); ?></td>
                                        <td><a href="?learnerID=<?php echo $learner['LearnerID']; ?>"><i class="fas fa-arrow-right"></i> Select Learner</a></td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    <?php else: ?>
                        <div class="no-results">
                            <i class="fas fa-search"></i>
                            <span>No learners found matching your search criteria.</span>
                        </div>
                    <?php endif; ?>
                </div>
            </div>
        </body>
        </html>
        <?php
        $conn->close();
        ob_end_flush();
        exit();
    }

    // Get learner info
    $stmt = $conn->prepare("SELECT Name, Surname, IDNumber FROM learnerdetails WHERE learnerID = ?");
    $stmt->bind_param("i", $learnerID);
    $stmt->execute();
    $learner_info = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    // Get unit standards for this learner - including "All Questions" files
    $stmt = $conn->prepare("
        SELECT DISTINCT 
            CASE 
                WHEN a.unit_standard_id IS NOT NULL THEN a.unit_standard_id
                WHEN p.exercise LIKE '%All Questions%' THEN 
                    TRIM(SUBSTRING(p.exercise, 
                        LOCATE('- ', p.exercise) + 2, 
                        CASE 
                            WHEN LOCATE(' -', p.exercise, LOCATE('- ', p.exercise) + 2) > 0 
                            THEN LOCATE(' -', p.exercise, LOCATE('- ', p.exercise) + 2) - LOCATE('- ', p.exercise) - 2
                            ELSE LENGTH(p.exercise) - LOCATE('- ', p.exercise) - 1
                        END
                    ))
                WHEN p.exercise LIKE '%All Formative Questions%' THEN
                    TRIM(SUBSTRING(p.exercise,
                        LOCATE('- ', p.exercise) + 2,
                        CASE
                            WHEN LOCATE(' -', p.exercise, LOCATE('- ', p.exercise) + 2) > 0
                            THEN LOCATE(' -', p.exercise, LOCATE('- ', p.exercise) + 2) - LOCATE('- ', p.exercise) - 2
                            ELSE LENGTH(p.exercise) - LOCATE('- ', p.exercise) - 1
                        END
                    ))
                WHEN p.exercise LIKE '%All Summative Questions%' THEN
                    TRIM(SUBSTRING(p.exercise,
                        LOCATE('- ', p.exercise) + 2,
                        CASE
                            WHEN LOCATE(' -', p.exercise, LOCATE('- ', p.exercise) + 2) > 0
                            THEN LOCATE(' -', p.exercise, LOCATE('- ', p.exercise) + 2) - LOCATE('- ', p.exercise) - 2
                            ELSE LENGTH(p.exercise) - LOCATE('- ', p.exercise) - 1
                        END
                    ))
                ELSE NULL
            END as unit_standard_id
        FROM learnerdetails l
        LEFT JOIN poe p ON l.LearnerID = p.learnerID
        LEFT JOIN assessments a ON p.exercise = a.exercise
        WHERE l.LearnerID = ? AND p.filePath IS NOT NULL 
        AND (
            a.unit_standard_id IS NOT NULL 
            OR p.exercise LIKE '%All Questions%'
            OR p.exercise LIKE '%All Formative Questions%'
            OR p.exercise LIKE '%All Summative Questions%'
        )
        ORDER BY unit_standard_id ASC
    ");
    if (!$stmt) {
        throw new Exception("Prepare failed for unit standards: " . $conn->error);
    }
    $stmt->bind_param("i", $learnerID);
    $stmt->execute();
    $unit_standards = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    
    error_log("Fetched " . count($unit_standards) . " unit standards with completed files for learnerID: $learnerID");
    foreach ($unit_standards as $unit) {
        error_log("Unit Standard: " . $unit['unit_standard_id']);
    }
    
    // For each unit standard, calculate how many questions need tagging
    foreach ($unit_standards as &$unit_standard) {
        $unit_id = $unit_standard['unit_standard_id'];
        
        // Get all assessments for this unit standard (Formative and Summative only, check question_type for Practical/LogBook)
        $stmt = $conn->prepare("SELECT exercise, question_number, assessment_type, question_type 
                                FROM assessments 
                                WHERE unit_standard_id = ? AND assessment_type IN ('Formative', 'Summative')
                                ORDER BY assessment_type, CAST(question_number AS DECIMAL(10,2)) ASC");
        $stmt->bind_param("s", $unit_id);
        $stmt->execute();
        $unit_exercises = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        
        // Get POE entries for this unit standard (including LogBook)
        $stmt = $conn->prepare("SELECT poe_id, exercise, type, filePath, submitted_at 
                                FROM poe 
                                WHERE learnerID = ? AND type IN ('Formative', 'Summative', 'LogBook')");
        $stmt->bind_param("i", $learnerID);
        $stmt->execute();
        $unit_poe_entries = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        
        // Count completed and pending questions by assessment type (matching poe_tag.php logic exactly)
        $total_questions = 0;
        $completed_questions = 0;
        $formative_total = 0;
        $formative_completed = 0;
        $summative_total = 0;
        $summative_completed = 0;
        $logbook_total = 0;
        $logbook_completed = 0;
        
        // Check for "All Questions" files for this unit standard
        $allQuestionsFiles = [];
        foreach ($unit_poe_entries as $entry) {
            $isAllQuestionsFormat = (strpos($entry['exercise'], 'All') !== false && strpos($entry['exercise'], 'Questions') !== false) ||
                                    (strpos($entry['filePath'], 'All_Questions') !== false);
            
            if ($isAllQuestionsFormat) {
                // Extract unit standard ID
                $extractedUnitId = null;
                if (preg_match('/- (\d{4,10}) -/', $entry['exercise'], $matches)) {
                    $extractedUnitId = $matches[1];
                } elseif (!empty($entry['filePath']) && preg_match('/_-_(\d{4,10})_-_/', $entry['filePath'], $matches)) {
                    $extractedUnitId = $matches[1];
                }
                
                if ($extractedUnitId == $unit_id) {
                    $allQuestionsFiles[] = $entry;
                }
            }
        }
        
        foreach ($unit_exercises as $exercise) {
            $assessment_type = $exercise['assessment_type'];
            $question_type = $exercise['question_type'] ?? 'Knowledge'; // Default to Knowledge if not set
            
            if (empty($assessment_type)) {
                continue; // Skip NULL or empty assessment_type
            }
            
            // Determine POE type based on question_type
            // IMPORTANT: Only Summative + Practical = LogBook. Formative + Practical stays as Formative.
            $poe_type = ($assessment_type === 'Summative' && $question_type === 'Practical') ? 'LogBook' : $assessment_type;
            
            $is_completed = false;
            
            // Check if there's a POE entry for this exercise
            $trimmed_exercise = trim($exercise['exercise']);
            foreach ($unit_poe_entries as $entry) {
                if (trim($entry['exercise']) === $trimmed_exercise && $entry['type'] === $poe_type) {
                    $is_completed = true;
                    break;
                }
            }
            
            // Special case: Check for "All Questions" files that cover all questions for this POE type
            if (!$is_completed && count($allQuestionsFiles) > 0) {
                foreach ($allQuestionsFiles as $entry) {
                    if ($entry['type'] === $poe_type) {
                        $is_completed = true;
                        break;
                    }
                }
            }
            
            $total_questions++;
            if ($is_completed) {
                $completed_questions++;
            }
            
            // Count by display category (based on question_type and assessment_type)
            // IMPORTANT: Only Summative + Practical = LogBook
            if ($assessment_type === 'Summative' && $question_type === 'Practical') {
                // Summative Practical questions go to LogBook
                $logbook_total++;
                if ($is_completed) {
                    $logbook_completed++;
                }
            } elseif ($assessment_type === 'Formative') {
                // All Formative questions (including Practical) stay as Formative
                $formative_total++;
                if ($is_completed) {
                    $formative_completed++;
                }
            } elseif ($assessment_type === 'Summative') {
                // Summative Knowledge questions stay as Summative
                $summative_total++;
                if ($is_completed) {
                    $summative_completed++;
                }
            }
        }
        
        $unit_standard['total_questions'] = $total_questions;
        $unit_standard['completed_questions'] = $completed_questions;
        $unit_standard['pending_questions'] = $total_questions - $completed_questions;
        $unit_standard['is_complete'] = (($total_questions - $completed_questions) == 0 && $total_questions > 0);
        
        // Add assessment type breakdowns
        $unit_standard['formative'] = [
            'total' => $formative_total,
            'completed' => $formative_completed,
            'pending' => $formative_total - $formative_completed,
            'is_complete' => (($formative_total - $formative_completed) == 0 && $formative_total > 0)
        ];
        
        $unit_standard['summative'] = [
            'total' => $summative_total,
            'completed' => $summative_completed,
            'pending' => $summative_total - $summative_completed,
            'is_complete' => (($summative_total - $summative_completed) == 0 && $summative_total > 0)
        ];
        
        $unit_standard['logbook'] = [
            'total' => $logbook_total,
            'completed' => $logbook_completed,
            'pending' => $logbook_total - $logbook_completed,
            'is_complete' => (($logbook_total - $logbook_completed) == 0 && $logbook_total > 0)
        ];
    }
    
    error_log("Fetched " . count($unit_standards) . " unit standards with completed files for learnerID: $learnerID");
    error_log("Unit standards data: " . json_encode($unit_standards));

    // If no unit standard selected, show unit standard selection
    if (empty($unit_standard_id)) {
        ?>
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>System Tagging - Unit Standards</title>
            <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f8f9fa; }
                .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 15px; margin-bottom: 30px; }
                .header h1 { font-size: 2.2rem; margin-bottom: 10px; }
                .learner-info { background: rgba(255,255,255,0.1); padding: 15px; border-radius: 8px; margin-top: 15px; }
                .breadcrumb { margin-bottom: 20px; }
                .breadcrumb a { color: #007bff; text-decoration: none; margin-right: 15px; }
                .breadcrumb a:hover { text-decoration: underline; }
                .unit-standards-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
                .unit-card { background: white; border-radius: 12px; padding: 25px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); transition: all 0.3s ease; border-left: 4px solid #28a745; }
                .unit-card:hover { transform: translateY(-5px); box-shadow: 0 8px 25px rgba(0,0,0,0.15); }
                .unit-card h3 { color: #2c3e50; margin-bottom: 10px; }
                .unit-card p { color: #6c757d; margin-bottom: 15px; }
                .unit-card a { display: inline-block; padding: 12px 24px; background: linear-gradient(135deg, #28a745, #20c997); color: white; text-decoration: none; border-radius: 8px; font-weight: 500; transition: all 0.3s ease; }
                .unit-card a:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(40,167,69,0.3); text-decoration: none; color: white; }
                .poe-count { background: #17a2b8; color: white; padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; font-weight: 600; margin-left: 10px; }
                .stats-card { background: white; border-radius: 12px; padding: 20px; margin-bottom: 30px; text-align: center; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                .stats-number { font-size: 2.5rem; font-weight: 700; color: #28a745; }
                .no-results { text-align: center; padding: 60px 20px; color: #6c757d; }
                .no-results i { font-size: 4rem; margin-bottom: 20px; opacity: 0.5; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1><i class="fas fa-cogs"></i> System Tagging - Unit Standards</h1>
                    <?php if ($learner_info): ?>
                        <div class="learner-info">
                            <strong>Learner:</strong> <?php echo htmlspecialchars($learner_info['Name'] . ' ' . $learner_info['Surname']); ?>
                            (ID: <?php echo htmlspecialchars($learner_info['IDNumber']); ?>)
                        </div>
                    <?php else: ?>
                        <div style="color: #ffe6e6;">
                            <i class="fas fa-exclamation-triangle"></i>
                            Learner ID <?php echo $learnerID; ?> not found.
                        </div>
                    <?php endif; ?>
                </div>
                <div class="breadcrumb">
                    <a href="<?php echo $_SERVER['PHP_SELF']; ?>"><i class="fas fa-arrow-left"></i> Back to Learner List</a>
                </div>

                <!-- Debug Info -->
                <!--<div style="background: #f0f0f0; padding: 10px; margin: 10px 0; border-radius: 5px; font-size: 12px;">-->
                <!--    <strong>Debug Info:</strong><br>-->
                <!--    Unit standards with completed files (Q1-5): <?= count($unit_standards) ?><br>-->
                <!--    Valid unit standards: <?= count(array_filter($unit_standards, function($unit) { return !empty($unit['unit_standard_id']); })) ?><br>-->
                <!--    Learner ID: <?= $learnerID ?><br>-->
                <!--    Unit standards data: <?= htmlspecialchars(json_encode($unit_standards)) ?><br>-->
                <!--    <em>Note: Only showing unit standards where learner has uploaded files for questions 1-5</em><br>-->
                <!--    <strong>Completion Summary:</strong>-->
                <!--    <php-->
                <!--    $complete_count = 0;-->
                <!--    $pending_count = 0;-->
                <!--    foreach ($unit_standards as $unit) {-->
                <!--        if ($unit['is_complete']) {-->
                <!--            $complete_count++;-->
                <!--        } else {-->
                <!--            $pending_count++;-->
                <!--        }-->
                <!--    }-->
                <!--    ?>-->
                <!--    <?= $complete_count ?> complete, <?= $pending_count ?> with pending questions-->
                <!--</div>-->

                <?php if (count($unit_standards) > 0): ?>
                    <div class="stats-card">
                        <div><h3>Available Unit Standards</h3><p>Click to view exercises and assessments</p></div>
                        <div class="stats-number"><?php echo count(array_filter($unit_standards, function($unit) { return !empty($unit['unit_standard_id']); })); ?></div>
                    </div>
                    <div class="unit-standards-grid">
                        <?php foreach ($unit_standards as $unit): ?>
                            <?php if (!empty($unit['unit_standard_id'])): ?>
                                <div class="unit-card">
                                    <h3><i class="fas fa-clipboard-check"></i> Unit Standard</h3>
                                    <p style="font-size: 1.1em; color: #2c3e50; font-weight: 600; margin-bottom: 20px;"><?php echo htmlspecialchars($unit['unit_standard_id']); ?></p>
                                    
                                    <!-- Assessment Type Cards -->
                                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(100px, 1fr)); gap: 15px; margin-bottom: 20px;">
                                        <!-- Formative Assessment Card -->
                                        <?php if ($unit['formative']['total'] > 0): ?>
                                            <div style="background: #e3f2fd; border: 2px solid #2196f3; border-radius: 8px; padding: 15px; text-align: center;">
                                                <h4 style="color: #1976d2; margin-bottom: 8px; font-size: 0.9em;">
                                                    <i class="fas fa-edit"></i> Formative
                                                </h4>
                                                <?php if ($unit['formative']['is_complete']): ?>
                                                    <div style="background: #4caf50; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.8em; font-weight: 600;">
                                                        <i class="fas fa-check"></i> Complete
                                                    </div>
                                                <?php else: ?>
                                                    <div style="background: #ff9800; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.8em; font-weight: 600;">
                                                        <?php echo $unit['formative']['pending']; ?> pending
                                                    </div>
                                                <?php endif; ?>
                                                <div style="font-size: 0.75em; color: #666; margin-top: 5px;">
                                                    <?php echo $unit['formative']['completed']; ?>/<?php echo $unit['formative']['total']; ?>
                                                </div>
                                            </div>
                                        <?php endif; ?>
                                        
                                        <!-- Summative Assessment Card -->
                                        <?php if ($unit['summative']['total'] > 0): ?>
                                            <div style="background: #f3e5f5; border: 2px solid #9c27b0; border-radius: 8px; padding: 15px; text-align: center;">
                                                <h4 style="color: #7b1fa2; margin-bottom: 8px; font-size: 0.9em;">
                                                    <i class="fas fa-trophy"></i> Summative
                                                </h4>
                                                <?php if ($unit['summative']['is_complete']): ?>
                                                    <div style="background: #4caf50; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.8em; font-weight: 600;">
                                                        <i class="fas fa-check"></i> Complete
                                                    </div>
                                                <?php else: ?>
                                                    <div style="background: #ff9800; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.8em; font-weight: 600;">
                                                        <?php echo $unit['summative']['pending']; ?> pending
                                                    </div>
                                                <?php endif; ?>
                                                <div style="font-size: 0.75em; color: #666; margin-top: 5px;">
                                                    <?php echo $unit['summative']['completed']; ?>/<?php echo $unit['summative']['total']; ?>
                                                </div>
                                            </div>
                                        <?php endif; ?>
                                        
                                        <!-- Logbook Assessment Card -->
                                        <?php if ($unit['logbook']['total'] > 0): ?>
                                            <div style="background: #fff3e0; border: 2px solid #ff9800; border-radius: 8px; padding: 15px; text-align: center;">
                                                <h4 style="color: #f57c00; margin-bottom: 8px; font-size: 0.9em;">
                                                    <i class="fas fa-book"></i> Logbook
                                                </h4>
                                                <?php if ($unit['logbook']['is_complete']): ?>
                                                    <div style="background: #4caf50; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.8em; font-weight: 600;">
                                                        <i class="fas fa-check"></i> Complete
                                                    </div>
                                                <?php else: ?>
                                                    <div style="background: #ff9800; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.8em; font-weight: 600;">
                                                        <?php echo $unit['logbook']['pending']; ?> pending
                                                    </div>
                                                <?php endif; ?>
                                                <div style="font-size: 0.75em; color: #666; margin-top: 5px;">
                                                    <?php echo $unit['logbook']['completed']; ?>/<?php echo $unit['logbook']['total']; ?>
                                                </div>
                                            </div>
                                        <?php endif; ?>
                                    </div>
                                    
                                    <!-- Overall Status -->
                                    <?php if ($unit['is_complete']): ?>
                                        <div style="background: #d4edda; color: #155724; padding: 8px 12px; border-radius: 20px; font-size: 0.9em; font-weight: 600; margin: 10px 0; text-align: center;">
                                            <i class="fas fa-check-circle"></i> All Complete
                                        </div>
                                    <?php else: ?>
                                        <div style="background: #fff3cd; color: #856404; padding: 8px 12px; border-radius: 20px; font-size: 0.9em; font-weight: 600; margin: 10px 0; text-align: center;">
                                            <i class="fas fa-exclamation-circle"></i> <?php echo $unit['pending_questions']; ?> questions need tagging
                                        </div>
                                    <?php endif; ?>
                                    
                                    <a href="?learnerID=<?php echo $learnerID; ?>&unit_standard_id=<?php echo urlencode($unit['unit_standard_id']); ?>">
                                        <i class="fas fa-eye"></i> View Exercises
                                    </a>
                                </div>
                            <?php endif; ?>
                        <?php endforeach; ?>
                    </div>
                <?php else: ?>
                    <div class="no-results">
                        <i class="fas fa-inbox"></i>
                        <h3>No unit standards found</h3>
                        <p>No unit standards found for this learner.</p>
                    </div>
                <?php endif; ?>
            </div>
        </body>
        </html>
        <?php
        $conn->close();
        ob_end_flush();
        exit();
    }

    // Validate inputs
    if ($learnerID <= 0 || empty($unit_standard_id)) {
        throw new Exception("Invalid learnerID ($learnerID) or unit_standard_id ($unit_standard_id)");
    }

    // Get assessments for system tagging (get Formative and Summative, check question_type for Practical/LogBook)
    // IMPORTANT: Only Summative + Practical = LogBook. Formative + Practical stays as Formative.
    $stmt = $conn->prepare("SELECT exercise, question_number, assessment_type, question_type,
                            CASE 
                                WHEN assessment_type = 'Summative' AND question_type = 'Practical' THEN 'LogBook' 
                                ELSE assessment_type 
                            END as type
                            FROM assessments 
                            WHERE unit_standard_id = ? AND assessment_type IN ('Formative', 'Summative')
                            ORDER BY assessment_type, CAST(question_number AS DECIMAL(10,2)) ASC");
    if (!$stmt) {
        throw new Exception("Prepare failed for assessments: " . $conn->error);
    }
    $stmt->bind_param("s", $unit_standard_id);
    $stmt->execute();
    $all_exercises = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    
    error_log("=== ASSESSMENTS FOR UNIT STANDARD $unit_standard_id ===");
    error_log("Total assessments found: " . count($all_exercises));
    if (count($all_exercises) === 0) {
        error_log("⚠️ WARNING: No assessments found in database for unit standard $unit_standard_id");
    } else {
        foreach ($all_exercises as $idx => $ex) {
            error_log("Assessment #$idx: Q" . $ex['question_number'] . " - Type: " . $ex['type'] . " - Exercise: '" . $ex['exercise'] . "'");
        }
    }
    error_log("Fetched " . count($all_exercises) . " exercises for unit_standard_id='$unit_standard_id'");
    error_log("All exercises: " . json_encode($all_exercises));
    
    
    // Check what assessment_type values exist
    $assessment_types_found = [];
    foreach ($all_exercises as $exercise) {
        $type = $exercise['type'] ?? 'NULL';
        if (!in_array($type, $assessment_types_found)) {
            $assessment_types_found[] = $type;
        }
    }
    error_log("Assessment types found: " . json_encode($assessment_types_found));

    // Get POE entries (including LogBook for Practical questions)
    $stmt = $conn->prepare("SELECT poe_id, exercise, type, filePath, submitted_at 
                            FROM poe 
                            WHERE learnerID = ? AND type IN ('Formative', 'Summative', 'LogBook')");
    if (!$stmt) {
        throw new Exception("Prepare failed for poe: " . $conn->error);
    }
    $stmt->bind_param("i", $learnerID);
    $stmt->execute();
    $poe_entries = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    error_log("Fetched " . count($poe_entries) . " POE entries for learnerID: " . $learnerID . " (including LogBook)");
    
    // Check for "All Questions" files and extract their details
    $allQuestionsFiles = [];
    foreach ($poe_entries as $entry) {
        $isAllQuestionsFormat = (strpos($entry['exercise'], 'All') !== false && strpos($entry['exercise'], 'Questions') !== false) ||
                                (strpos($entry['filePath'], 'All_Questions') !== false);
        
        if ($isAllQuestionsFormat) {
            // Extract unit standard ID
            $extractedUnitId = null;
            if (preg_match('/- (\d{4,10}) -/', $entry['exercise'], $matches)) {
                $extractedUnitId = $matches[1];
            } elseif (!empty($entry['filePath']) && preg_match('/_-_(\d{4,10})_-_/', $entry['filePath'], $matches)) {
                $extractedUnitId = $matches[1];
            }
            
            if ($extractedUnitId == $unit_standard_id) {
                $allQuestionsFiles[] = $entry;
                error_log(">>> ALL QUESTIONS FILE for Unit $unit_standard_id: Exercise='" . $entry['exercise'] . "', Type='" . $entry['type'] . "', File='" . $entry['filePath'] . "'");
            }
        }
    }
    
    error_log("Found " . count($allQuestionsFiles) . " All Questions files for unit standard $unit_standard_id");
    

    // Check for completed files for each assessment type
    $has_formative_files = false;
    $has_summative_files = false;
    $has_logbook_files = false;

    foreach (['Formative', 'Summative', 'LogBook'] as $type) {
        $sql_check_files = "SELECT COUNT(*) as count FROM poe p 
                            WHERE p.learnerID = ? AND p.type = ? 
                            AND (
                                p.filePath LIKE CONCAT('%', ?, '_', ?, '_%') 
                                OR p.filePath LIKE CONCAT('%_', ?, '_%')
                                OR p.exercise LIKE CONCAT('%All Questions - ', ?, ' -%')
                                OR EXISTS (
                                    SELECT 1 FROM assessments a 
                                    WHERE a.unit_standard_id = ? AND a.exercise = p.exercise
                                )
                            )
                            AND p.filePath IS NOT NULL";
        $stmt = $conn->prepare($sql_check_files);
        $stmt->bind_param("isssssss", $learnerID, $type, $type, $unit_standard_id, $unit_standard_id, $unit_standard_id, $unit_standard_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $count = $result->fetch_assoc()['count'];
        $stmt->close();
        
        if ($type === 'Formative') {
            $has_formative_files = $count > 0;
        } elseif ($type === 'Summative') {
            $has_summative_files = $count > 0;
        } else {
            $has_logbook_files = $count > 0;
        }
    }

    // Create POE lookup
    $poe_lookup = [];
    foreach ($poe_entries as $entry) {
        $key = $entry['exercise'] . '|' . $entry['type'];
        $poe_lookup[$key] = $entry;
    }

    // Group exercises by type and create questions array
    $questions = [];
    
    foreach ($all_exercises as $exercise) {
        $assessment_type = $exercise['type'];
        
        if (empty($assessment_type)) {
            continue; // Skip NULL or empty assessment_type
        }
        
        $is_completed = false;
        $filePath = null;
        $submitted_at = null;
        
        // Check if there's a POE entry for this exercise (matching poe_tag.php logic exactly)
        $trimmed_exercise = trim($exercise['exercise']);
        foreach ($poe_entries as $entry) {
            if (trim($entry['exercise']) === $trimmed_exercise && $entry['type'] === $exercise['type']) {
                $is_completed = true;
                $filePath = $entry['filePath'];
                $submitted_at = $entry['submitted_at'];
                break;
            }
        }
        
        // Special case: Check for "All Questions" files that cover all questions for this assessment type
        if (!$is_completed && count($allQuestionsFiles) > 0) {
            foreach ($allQuestionsFiles as $entry) {
                // Check if the type matches
                if ($entry['type'] === $exercise['type']) {
                    error_log("✓✓✓ All Questions MATCH FOUND: Question '" . $exercise['exercise'] . "' (Q" . $exercise['question_number'] . ") matched by All Questions file: Type=" . $entry['type'] . ", File='" . $entry['filePath'] . "'");
                    $is_completed = true;
                    $filePath = $entry['filePath'];
                    $submitted_at = $entry['submitted_at'];
                    break;
                }
            }
        }
        
        // Verify file exists on filesystem if filePath is set
        $file_actually_exists = false;
        if (!empty($filePath)) {
            // Try multiple methods to locate the file
            $paths_to_try = [
                $_SERVER['DOCUMENT_ROOT'] . '/' . ltrim($filePath, '/'),
                dirname(__FILE__) . '/' . $filePath,
                dirname(__FILE__) . '/mobile/' . ltrim($filePath, '/'),
                $filePath // Try relative path
            ];
            
            foreach ($paths_to_try as $test_path) {
                if (file_exists($test_path)) {
                    $file_actually_exists = true;
                    break;
                }
            }
            
            if (!$file_actually_exists) {
                error_log("⚠️ File path set but file missing: $filePath (tried " . count($paths_to_try) . " locations)");
            }
        }
        
        $questions[$assessment_type][] = [
            'exercise' => $exercise['exercise'],
            'question_number' => $exercise['question_number'],
            'is_completed' => $is_completed,
            'file_exists' => $file_actually_exists,
            'file_path' => $filePath,
            'exercise_length' => strlen($exercise['exercise'])
        ];
        
        // Debug log for LogBook entries
        if ($assessment_type === 'LogBook') {
            error_log("LogBook Q" . $exercise['question_number'] . ": Completed=" . ($is_completed ? 'YES' : 'NO') . ", FilePath=" . ($filePath ?? 'NULL') . ", FileExists=" . ($file_actually_exists ? 'YES' : 'NO'));
        }
    }

    // Check if all questions are already completed
    $all_completed = true;
    $total_questions = 0;
    $completed_questions = 0;
    
    foreach ($questions as $assessment_type => $type_questions) {
        foreach ($type_questions as $question) {
            $total_questions++;
            if ($question['is_completed']) {
                $completed_questions++;
            } else {
                $all_completed = false;
            }
        }
    }
    
    error_log("Completion status for unit_standard_id=$unit_standard_id: $completed_questions/$total_questions completed");
    error_log("Questions breakdown: " . json_encode($questions));
    error_log("All exercises found: " . json_encode($all_exercises));
    error_log("POE entries found: " . json_encode($poe_entries));
    error_log("Has formative files: " . ($has_formative_files ? 'Yes' : 'No'));
    error_log("Has summative files: " . ($has_summative_files ? 'Yes' : 'No'));

    // Auto-tagging function - automatically tag questions that have Q1-5 files uploaded
    function performAutoTagging($conn, $learnerID, $unit_standard_id, $assessment_type) {
        try {
            // Get all questions for this assessment type that need tagging (Q6 not completed but Q1-5 have files)
            $sql_auto_tag = "
                SELECT DISTINCT a.exercise, a.question_number, a.assessment_type as type
                FROM assessments a
                WHERE a.unit_standard_id = ? AND a.assessment_type = ?
                AND a.exercise NOT IN (
                    SELECT p.exercise FROM poe p WHERE p.learnerID = ? AND p.type = ?
                )
                AND EXISTS (
                    SELECT 1 FROM poe p2 
                    JOIN assessments a2 ON p2.exercise = a2.exercise 
                    WHERE p2.learnerID = ? AND a2.unit_standard_id = ? AND p2.type = ? 
                    AND a2.question_number IN ('1', '2', '3', '4', '5') AND p2.filePath IS NOT NULL
                )
                ORDER BY CAST(a.question_number AS DECIMAL(10,2)) ASC
            ";
            
            $stmt = $conn->prepare($sql_auto_tag);
            if (!$stmt) {
                error_log("Auto-tag prepare failed: " . $conn->error);
                return ['success' => false, 'error' => 'Database prepare failed'];
            }
            
            $stmt->bind_param("ssissis", $unit_standard_id, $assessment_type, $learnerID, $assessment_type, 
                             $learnerID, $unit_standard_id, $assessment_type);
            $stmt->execute();
            $auto_tag_exercises = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmt->close();
            
            if (empty($auto_tag_exercises)) {
                return ['success' => true, 'tagged' => 0, 'message' => 'No questions available for auto-tagging'];
            }
            
            $tagged_count = 0;
            $conn->begin_transaction();
            
            foreach ($auto_tag_exercises as $exercise) {
                $selected_exercise = $exercise['exercise'];
                $type = $exercise['type'];
                $question_number = $exercise['question_number'];
                
                // Skip if exercise is too long
                if (strlen($selected_exercise) > 10000) {
                    continue;
                }
                
                // Get a file path from Q1-5 for this assessment type
                $sql_file = "SELECT p.filePath FROM poe p 
                            JOIN assessments a ON p.exercise = a.exercise 
                            WHERE p.learnerID = ? AND a.unit_standard_id = ? AND p.type = ? 
                            AND a.question_number IN ('1', '2', '3', '4', '5') AND p.filePath IS NOT NULL 
                            ORDER BY p.submitted_at ASC LIMIT 1";
                $stmt = $conn->prepare($sql_file);
                $stmt->bind_param("iss", $learnerID, $unit_standard_id, $type);
                $stmt->execute();
                $result = $stmt->get_result();
                $completed_file = $result->fetch_assoc();
                $stmt->close();
                
                if (!$completed_file) {
                    continue; // No file found, skip
                }
                
                $filePath = $completed_file['filePath'];
                
                // Insert POE entry
                $sql_insert = "INSERT INTO poe (learnerID, exercise, type, filePath, submitted_at) VALUES (?, ?, ?, ?, NOW())";
                $stmt = $conn->prepare($sql_insert);
                if (!$stmt) {
                    error_log("Auto-tag insert prepare failed: " . $conn->error);
                    continue;
                }
                
                $stmt->bind_param("isss", $learnerID, $selected_exercise, $type, $filePath);
                if ($stmt->execute()) {
                    $tagged_count++;
                    error_log("Auto-tagged: LearnerID=$learnerID, Exercise='$selected_exercise', Type='$type', Q=$question_number");
                } else {
                    error_log("Auto-tag insert failed: " . $stmt->error);
                }
                $stmt->close();
            }
            
            $conn->commit();
            return ['success' => true, 'tagged' => $tagged_count, 'message' => "Auto-tagged $tagged_count questions"];
            
        } catch (Exception $e) {
            $conn->rollback();
            error_log("Auto-tagging error: " . $e->getMessage());
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    // Perform auto-tagging for both assessment types if they have files
    $auto_tag_results = [];
    if ($has_formative_files) {
        $result = performAutoTagging($conn, $learnerID, $unit_standard_id, 'Formative');
        $auto_tag_results['Formative'] = $result;
        error_log("Formative auto-tag result: " . json_encode($result));
    }
    
    if ($has_summative_files) {
        $result = performAutoTagging($conn, $learnerID, $unit_standard_id, 'Summative');
        $auto_tag_results['Summative'] = $result;
        error_log("Summative auto-tag result: " . json_encode($result));
    }

    // If any auto-tagging was performed, refresh the POE entries and questions data
    $total_tagged = 0;
    foreach ($auto_tag_results as $result) {
        if ($result['success']) {
            $total_tagged += $result['tagged'];
        }
    }
    
    if ($total_tagged > 0) {
        // Re-fetch POE entries to include newly tagged items (including LogBook)
        $stmt = $conn->prepare("SELECT poe_id, exercise, type, filePath, submitted_at 
                                FROM poe 
                                WHERE learnerID = ? AND type IN ('Formative', 'Summative', 'LogBook')");
        if ($stmt) {
            $stmt->bind_param("i", $learnerID);
            $stmt->execute();
            $poe_entries = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmt->close();
            error_log("Re-fetched " . count($poe_entries) . " POE entries after auto-tagging (including LogBook)");
            
            // Rebuild questions array with updated data
            $questions = [];
            foreach ($all_exercises as $exercise) {
                $assessment_type = $exercise['type'];
                if (empty($assessment_type)) {
                    continue;
                }
                
                $is_completed = false;
                $filePath = null;
                $submitted_at = null;
                
                foreach ($poe_entries as $entry) {
                    if ($entry['exercise'] === $exercise['exercise'] && $entry['type'] === $assessment_type) {
                        $is_completed = true;
                        $filePath = $entry['filePath'];
                        $submitted_at = $entry['submitted_at'];
                        break;
                    }
                }
                
                // Verify file exists on filesystem if filePath is set
                $file_actually_exists = false;
                if (!empty($filePath)) {
                    // Try multiple methods to locate the file
                    $paths_to_try = [
                        $_SERVER['DOCUMENT_ROOT'] . '/' . ltrim($filePath, '/'),
                        dirname(__FILE__) . '/' . $filePath,
                        dirname(__FILE__) . '/mobile/' . ltrim($filePath, '/'),
                        $filePath
                    ];
                    
                    foreach ($paths_to_try as $test_path) {
                        if (file_exists($test_path)) {
                            $file_actually_exists = true;
                            break;
                        }
                    }
                }
                
                $questions[$assessment_type][] = [
                    'exercise' => $exercise['exercise'],
                    'question_number' => $exercise['question_number'],
                    'is_completed' => $is_completed,
                    'file_exists' => $file_actually_exists,
                    'file_path' => $filePath,
                    'exercise_length' => strlen($exercise['exercise'])
                ];
            }
            
            // Recalculate completion status
            $all_completed = true;
            $total_questions = 0;
            $completed_questions = 0;
            
            foreach ($questions as $assessment_type => $type_questions) {
                foreach ($type_questions as $question) {
                    $total_questions++;
                    if ($question['is_completed']) {
                        $completed_questions++;
                    } else {
                        $all_completed = false;
                    }
                }
            }
            
            error_log("After auto-tagging: $completed_questions/$total_questions completed");
        }
    }

} catch (Exception $e) {
    error_log("System tagging error: " . $e->getMessage());
    echo "<div style='color: red; padding: 20px; background: #ffe6e6; border: 1px solid #ff0000; margin: 20px;'>";
    echo "<h3>Error:</h3>";
    echo "<p>" . htmlspecialchars($e->getMessage()) . "</p>";
    echo "</div>";
    exit();
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Tagging - <?php echo htmlspecialchars($unit_standard_id); ?></title>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #28a745 0%, #20c997 100%); color: white; padding: 30px; border-radius: 15px; margin-bottom: 30px; }
        .header h1 { font-size: 2.2rem; margin-bottom: 10px; }
        .learner-info { background: rgba(255,255,255,0.1); padding: 15px; border-radius: 8px; margin-top: 15px; }
        .breadcrumb { margin-bottom: 20px; }
        .breadcrumb a { color: #007bff; text-decoration: none; margin-right: 15px; }
        .breadcrumb a:hover { text-decoration: underline; }
        .assessment-section { background: white; border-radius: 12px; margin-bottom: 25px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .section-header { padding: 20px; font-size: 1.3rem; font-weight: 600; color: white; border-radius: 12px 12px 0 0; display: flex; align-items: center; }
        .section-header.formative { background: linear-gradient(135deg, #007bff, #0056b3); }
        .section-header.summative { background: linear-gradient(135deg, #dc3545, #c82333); }
        .section-content { padding: 25px; }
        .warning-message { background: #fff3cd; color: #856404; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #ffc107; }
        .questions-list { list-style: none; }
        .question-item { display: flex; align-items: center; padding: 15px; margin-bottom: 10px; background: #f8f9fa; border-radius: 8px; border-left: 4px solid #dee2e6; }
        .question-item.completed { background: #d4edda; border-left-color: #28a745; }
        .question-item.pending { background: #fff3cd; border-left-color: #ffc107; }
        .question-item input[type="checkbox"] { transform: scale(1.5); margin-right: 15px; }
        .question-item input[type="checkbox"]:disabled { cursor: not-allowed; opacity: 0.5; }
        .question-item .details { flex: 1; }
        .question-item .details strong { color: #2c3e50; }
        .status { padding: 8px 16px; border-radius: 20px; font-weight: 600; font-size: 0.9em; }
        .status.completed { background: #28a745; color: white; }
        .status.pending { background: #ffc107; color: #212529; }
        .file-status { font-size: 0.8rem; color: #6c757d; margin-top: 5px; }
        .file-exists { color: #28a745; }
        .file-missing { color: #dc3545; }
        .submit-btn { margin-top: 20px; padding: 15px 30px; background: linear-gradient(135deg, #28a745, #20c997); color: white; border: none; border-radius: 8px; cursor: pointer; font-size: 16px; display: inline-flex; align-items: center; gap: 8px; transition: all 0.3s ease; }
        .submit-btn:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(40, 167, 69, 0.3); }
        .submit-btn:disabled { background: #6c757d; cursor: not-allowed; transform: none; box-shadow: none; }
        .no-results { text-align: center; padding: 40px; color: #6c757d; }
        .no-results i { font-size: 3rem; margin-bottom: 15px; opacity: 0.5; }
        .error-message { color: #dc3545; font-size: 0.9em; margin-top: 5px; }
        .loading { display: none; }
        .alert { padding: 15px; margin: 20px 0; border-radius: 8px; }
        .alert-success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .alert-danger { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        .document-viewer { background: white; border-radius: 12px; margin-bottom: 25px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .viewer-header { padding: 20px; font-size: 1.3rem; font-weight: 600; color: white; border-radius: 12px 12px 0 0; background: linear-gradient(135deg, #6f42c1, #e83e8c); display: flex; align-items: center; justify-content: space-between; }
        .viewer-content { padding: 25px; }
        .document-iframe { width: 100%; height: 600px; border: 2px solid #dee2e6; border-radius: 8px; background: #f8f9fa; }
        .document-controls { display: flex; gap: 10px; margin-bottom: 15px; flex-wrap: wrap; }
        .doc-btn { padding: 8px 16px; background: #6f42c1; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 14px; text-decoration: none; display: inline-flex; align-items: center; gap: 5px; }
        .doc-btn:hover { background: #5a32a3; color: white; text-decoration: none; }
        .doc-btn.secondary { background: #6c757d; }
        .doc-btn.secondary:hover { background: #545b62; }
        .no-document { text-align: center; padding: 40px; color: #6c757d; }
        .document-info { background: #e9ecef; padding: 10px; border-radius: 6px; margin-bottom: 15px; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><i class="fas fa-robot"></i> System Tagging: <?php echo htmlspecialchars($unit_standard_id); ?></h1>
            <?php if ($learner_info): ?>
                <div class="learner-info">
                    <strong>Learner:</strong> <?php echo htmlspecialchars($learner_info['Name'] . ' ' . $learner_info['Surname']); ?>
                    (ID: <?php echo htmlspecialchars($learner_info['IDNumber']); ?>)
                </div>
            <?php else: ?>
                <div class="warning-message">
                    <i class="fas fa-exclamation-triangle"></i>
                    Learner ID <?php echo $learnerID; ?> not found.
                </div>
            <?php endif; ?>
        </div>
        <div class="breadcrumb">
            <a href="?learnerID=<?php echo $learnerID; ?>"><i class="fas fa-arrow-left"></i> Back to Unit Standards</a>
            <a href="<?php echo $_SERVER['PHP_SELF']; ?>"><i class="fas fa-users"></i> Back to Learner List</a>
        </div>
        
        <div id="alertContainer"></div>

        <!-- Auto-Tagging Results -->
        <?php if (!empty($auto_tag_results)): ?>
            <?php foreach ($auto_tag_results as $type => $result): ?>
                <?php if ($result['success'] && $result['tagged'] > 0): ?>
                    <div class="alert alert-success">
                        <i class="fas fa-robot"></i>
                        <strong>Auto-Tagging Complete:</strong> Successfully auto-tagged <?php echo $result['tagged']; ?> <?php echo $type; ?> questions!
                    </div>
                <?php elseif (!$result['success']): ?>
                    <div class="alert alert-danger">
                        <i class="fas fa-exclamation-triangle"></i>
                        <strong>Auto-Tagging Error (<?php echo $type; ?>):</strong> <?php echo htmlspecialchars($result['error'] ?? 'Unknown error'); ?>
                    </div>
                <?php endif; ?>
            <?php endforeach; ?>
        <?php endif; ?>


        <!-- Document Viewer Section -->
        <?php
        // Function to validate file paths and types for iframe display
        function isValidDocumentFile($filePath) {
            // Basic validation - just check if it's a PDF and has a path
            if (empty($filePath)) {
                return false;
            }
            
            // Get file extension
            $extension = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
            
            // Allowed file types for iframe display (focusing on PDF as mentioned)
            $allowedExtensions = ['pdf'];
            
            // Check if extension is allowed
            if (!in_array($extension, $allowedExtensions)) {
                return false;
            }
            
            // For now, be more permissive - if it's a PDF file path, allow it
            // We'll let the iframe handle the actual file loading
            return true;
        }

        // Function to convert database path to actual file path
        function getActualFilePath($dbFilePath) {
            // Database stores: POE/filename.pdf or LogBookPOE/filename.pdf
            // Actual file location: mobile/POE/filename.pdf or mobile/LogBookPOE/filename.pdf
            
            // Handle LogBook POE files
            if (strpos($dbFilePath, 'LogBookPOE/') === 0) {
                return 'mobile/' . $dbFilePath;
            }
            
            // Handle regular POE files
            if (strpos($dbFilePath, 'POE/') === 0) {
                return 'mobile/' . $dbFilePath;
            }
            
            // If path already starts with mobile/, return as is
            if (strpos($dbFilePath, 'mobile/') === 0) {
                return $dbFilePath;
            }
            
            // Otherwise return as is (might be full path or different structure)
            return $dbFilePath;
        }

        // Get one representative document per assessment type for document viewing
        $completed_questions_with_files = [];
        $assessment_type_documents = [];
        
        foreach ($questions as $assessment_type => $type_questions) {
            $found_document = false;
            
            foreach ($type_questions as $question) {
                // Only process if we haven't found a document for this assessment type yet
                if (!$found_document && $question['is_completed'] && !empty($question['file_path'])) {
                    // Validate file for iframe display
                    if (isValidDocumentFile($question['file_path'])) {
                        $actualFilePath = getActualFilePath($question['file_path']);
                        
                        // Verify the actual file exists on filesystem - try multiple locations
                        $file_exists_on_disk = false;
                        $paths_to_try = [
                            $_SERVER['DOCUMENT_ROOT'] . '/' . ltrim($actualFilePath, '/'),
                            dirname(__FILE__) . '/' . $actualFilePath,
                            dirname(__FILE__) . '/mobile/' . ltrim($question['file_path'], '/'),
                            $actualFilePath
                        ];
                        
                        foreach ($paths_to_try as $test_path) {
                            if (file_exists($test_path)) {
                                $file_exists_on_disk = true;
                                break;
                            }
                        }
                        
                        // Log for debugging
                        error_log("Document Viewer - $assessment_type: FilePath=" . $question['file_path'] . ", ActualPath=" . $actualFilePath . ", Exists=" . ($file_exists_on_disk ? 'YES' : 'NO'));
                        
                        // Only add if file actually exists
                        if ($file_exists_on_disk) {
                            $assessment_type_documents[$assessment_type] = [
                                'assessment_type' => $assessment_type,
                                'question_number' => $question['question_number'],
                                'exercise' => $question['exercise'],
                                'file_path' => $actualFilePath, // Use actual file path for iframe
                                'db_file_path' => $question['file_path'], // Keep original for reference
                                'file_extension' => strtolower(pathinfo($question['file_path'], PATHINFO_EXTENSION)),
                                'total_questions' => count($type_questions),
                                'completed_questions' => count(array_filter($type_questions, function($q) { return $q['is_completed']; }))
                            ];
                            $found_document = true;
                        } else {
                            error_log("⚠️ Document Viewer - File not found on disk (tried " . count($paths_to_try) . " locations)");
                        }
                    }
                }
            }
        }
        
        // Convert to array format for compatibility
        $completed_questions_with_files = array_values($assessment_type_documents);
        ?>
        
        <?php if (!empty($completed_questions_with_files)): ?>
            <div class="document-viewer">
                <div class="viewer-header">
                    <div>
                        <i class="fas fa-file-pdf"></i>
                        <span style="margin-left: 15px;">PDF Document Viewer</span>
                    </div>
                    <div style="background: rgba(255,255,255,0.2); padding: 5px 12px; border-radius: 15px; font-size: 0.9em;">
                        <?php echo count($completed_questions_with_files); ?> PDF documents available
                    </div>
                </div>
                <div class="viewer-content">
                    <div class="document-controls">
                        <label for="documentSelector" style="display: flex; align-items: center; gap: 8px; font-weight: 600;">
                            <i class="fas fa-list"></i> Select Document:
                        </label>
                        <select id="documentSelector" style="padding: 8px 12px; border: 2px solid #dee2e6; border-radius: 6px; font-size: 14px; min-width: 400px;">
                            <option value="">Choose a document to view...</option>
                            <?php foreach ($completed_questions_with_files as $doc): ?>
                                <option value="<?php echo htmlspecialchars($doc['file_path']); ?>" 
                                        data-type="<?php echo htmlspecialchars($doc['assessment_type']); ?>"
                                        data-question="<?php echo htmlspecialchars($doc['question_number']); ?>"
                                        data-extension="<?php echo htmlspecialchars($doc['file_extension']); ?>"
                                        data-total="<?php echo $doc['total_questions']; ?>"
                                        data-completed="<?php echo $doc['completed_questions']; ?>"
                                        data-db-path="<?php echo htmlspecialchars($doc['db_file_path']); ?>">
                                    <?php 
                                    $type_label = $doc['assessment_type'] === 'LogBook' ? 'LogBook (Practical)' : $doc['assessment_type'];
                                    echo htmlspecialchars($type_label); 
                                    ?> Assessment 
                                    (<?php echo $doc['completed_questions']; ?>/<?php echo $doc['total_questions']; ?> questions completed)
                                    - <?php echo htmlspecialchars(basename($doc['db_file_path'])); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                        <button type="button" class="doc-btn" onclick="loadDocument()">
                            <i class="fas fa-eye"></i> View Document
                        </button>
                        <button type="button" class="doc-btn secondary" onclick="downloadDocument()">
                            <i class="fas fa-download"></i> Download
                        </button>
                        <button type="button" class="doc-btn secondary" onclick="openInNewTab()">
                            <i class="fas fa-external-link-alt"></i> Open in New Tab
                        </button>
                    </div>
                    
                    <div id="documentInfo" class="document-info" style="display: none;">
                        <strong>Document Information:</strong>
                        <div id="docDetails"></div>
                    </div>
                    
                    <div id="documentContainer">
                        <div class="no-document">
                            <i class="fas fa-file-pdf" style="font-size: 3rem; margin-bottom: 15px; opacity: 0.5;"></i>
                            <h3>No PDF Document Selected</h3>
                            <p>Please select a PDF document from the dropdown above to view it.</p>
                        </div>
                    </div>
                </div>
            </div>
        <?php endif; ?>

            <div class="content">
                <?php if ($all_completed): ?>
                    <div class="assessment-section">
                        <div class="section-header" style="background: linear-gradient(135deg, #28a745, #20c997);">
                            <i class="fas fa-check-circle"></i>
                            <span style="margin-left: 15px;">Unit Standard Complete</span>
                        </div>
                        <div class="section-content">
                            <div style="text-align: center; padding: 40px;">
                                <i class="fas fa-check-circle" style="font-size: 4rem; color: #28a745; margin-bottom: 20px;"></i>
                                <h3 style="color: #28a745; margin-bottom: 15px;">All Questions Completed!</h3>
                                <p style="color: #6c757d; font-size: 1.1rem; margin-bottom: 20px;">
                                    This unit standard has been fully completed. All <?php echo $total_questions; ?> questions have been tagged and have valid file paths.
                                </p>
                                <div style="background: #d4edda; padding: 15px; border-radius: 8px; border-left: 4px solid #28a745; margin-bottom: 20px;">
                                    <strong>Status:</strong> <?php echo $completed_questions; ?>/<?php echo $total_questions; ?> questions completed (100%)
                                </div>
                                <a href="?learnerID=<?php echo $learnerID; ?>" class="submit-btn" style="text-decoration: none; display: inline-flex;">
                                    <i class="fas fa-arrow-left"></i> Back to Unit Standards
                                </a>
                            </div>
                        </div>
                    </div>
                <?php else: ?>
                    <?php
                    $assessment_types = ['Formative', 'Summative', 'LogBook'];
                    foreach ($assessment_types as $assessment_type):
            ?>
                <div class="assessment-section">
                    <div class="section-header <?php echo strtolower($assessment_type); ?>">
                        <i class="fas fa-<?php echo $assessment_type === 'Formative' ? 'edit' : 'certificate'; ?>"></i>
                        <?php echo ucfirst($assessment_type); ?> Assessments - System Tagging
                        <span style="margin-left: auto; background: rgba(255,255,255,0.2); padding: 5px 12px; border-radius: 15px; font-size: 0.9em;">
                            <?php echo isset($questions[$assessment_type]) ? count($questions[$assessment_type]) : 0; ?> items
                        </span>
                    </div>
                    <div class="section-content">
                        <?php if ($assessment_type === 'Formative' && !$has_formative_files): ?>
                            <div class="warning-message">
                                <i class="fas fa-exclamation-triangle"></i>
                                No completed files for questions 1-5 in Formative assessments. System tagging disabled.
                            </div>
                        <?php elseif ($assessment_type === 'Summative' && !$has_summative_files): ?>
                            <div class="warning-message">
                                <i class="fas fa-exclamation-triangle"></i>
                                No completed files for questions 1-5 in Summative assessments. System tagging disabled.
                            </div>
                        <?php endif; ?>
                        <?php if (isset($questions[$assessment_type]) && count($questions[$assessment_type]) > 0): ?>
                            <ul class="questions-list">
                                <?php foreach ($questions[$assessment_type] as $question): ?>
                                    <li class="question-item <?php echo $question['is_completed'] ? 'completed' : 'pending'; ?>" data-question-number="<?php echo htmlspecialchars($question['question_number']); ?>">
                                        <?php if (!$question['is_completed']): ?>
                                            <input type="checkbox" class="question-checkbox" 
                                                   data-exercise="<?php echo htmlspecialchars($question['exercise']); ?>" 
                                                   data-type="<?php echo htmlspecialchars($assessment_type); ?>" 
                                                   data-question-number="<?php echo htmlspecialchars($question['question_number']); ?>"
                                                   <?php echo (($assessment_type === 'Formative' && $has_formative_files) || ($assessment_type === 'Summative' && $has_summative_files) || ($assessment_type === 'LogBook' && $has_logbook_files)) && $question['exercise_length'] <= 10000 ? '' : 'disabled'; ?>>
                                        <?php else: ?>
                                            <!-- Show completed icon for completed questions -->
                                            <div style="width: 24px; height: 24px; margin-right: 15px; display: flex; align-items: center; justify-content: center;">
                                                <i class="fas fa-check-circle" style="color: #28a745; font-size: 1.5em;"></i>
                                            </div>
                                        <?php endif; ?>
                                        <div class="details">
                                            <strong>Question <?php echo htmlspecialchars($question['question_number']); ?>:</strong>
                                            <?php echo htmlspecialchars($question['exercise']); ?>
                                            <?php if ($question['exercise_length'] > 10000): ?>
                                                <div class="error-message">
                                                    <i class="fas fa-exclamation-circle"></i>
                                                    Exercise too long (<?php echo $question['exercise_length']; ?> characters)
                                                </div>
                                            <?php endif; ?>
                                            <?php if ($question['is_completed']): ?>
                                                <div class="file-status file-exists">
                                                    <i class="fas fa-file-check"></i> 
                                                    <?php if (!empty($question['file_path'])): ?>
                                                        <strong>File:</strong> <?php echo htmlspecialchars(basename($question['file_path'])); ?>
                                                        <?php if ($question['file_exists']): ?>
                                                            <span style="color: #28a745; font-weight: 600;">✓ File Exists</span>
                                                        <?php else: ?>
                                                            <span style="color: #dc3545; font-weight: 600;">✗ File Missing</span>
                                                        <?php endif; ?>
                                                    <?php else: ?>
                                                        <strong>Status:</strong> <span style="color: #ffc107; font-weight: 600;">⚠ Completed but file path missing - Check database</span>
                                                    <?php endif; ?>
                                                </div>
                                            <?php else: ?>
                                                <div class="file-status file-missing">
                                                    <i class="fas fa-file-times"></i>
                                                    <strong>Status:</strong> <span style="color: #856404;">Awaiting system tagging</span>
                                                </div>
                                            <?php endif; ?>
                                        </div>
                                        <span class="status <?php echo $question['is_completed'] ? 'completed' : 'pending'; ?>">
                                            <?php echo $question['is_completed'] ? 'COMPLETED' : 'Pending'; ?>
                                        </span>
                                    </li>
                                <?php endforeach; ?>
                            </ul>
                            <button class="submit-btn" data-type="<?php echo htmlspecialchars($assessment_type); ?>" 
                                    <?php echo (($assessment_type === 'Formative' && $has_formative_files) || ($assessment_type === 'Summative' && $has_summative_files) || ($assessment_type === 'LogBook' && $has_logbook_files)) ? '' : 'disabled'; ?>>
                                <i class="fas fa-robot"></i> System Tag Selected Questions
                            </button>
                        <?php else: ?>
                            <div class="no-results">
                                <i class="fas fa-inbox"></i>
                                <h3>No <?php echo strtolower($assessment_type); ?> questions found</h3>
                                <p>No questions found for this unit standard.</p>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            <?php endforeach; ?>
                <?php endif; ?>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function() {
            const submitButtons = document.querySelectorAll('.submit-btn');
            
            submitButtons.forEach(button => {
                button.addEventListener('click', function() {
                    const type = this.getAttribute('data-type');
                    const checkboxes = document.querySelectorAll(`input[data-type="${type}"]:checked`);
                    
                    if (checkboxes.length === 0) {
                        showAlert('warning', 'Please select at least one question to system tag.');
                        return;
                    }

                    const exercises = Array.from(checkboxes).map(cb => ({
                        exercise: cb.getAttribute('data-exercise'),
                        type: cb.getAttribute('data-type'),
                        question_number: cb.getAttribute('data-question-number')
                    }));

                    // Show loading state
                    const originalText = this.innerHTML;
                    this.disabled = true;
                    this.innerHTML = '<i class="fas fa-spinner fa-spin"></i> System Tagging...';

                    // Send AJAX request
                    const formData = new FormData();
                    formData.append('action', 'system_tag');
                    formData.append('exercises', JSON.stringify(exercises));

                    fetch('system_tagging2.php', {
                        method: 'POST',
                        body: formData
                    })
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            showAlert('success', 'System tagging completed successfully!');
                            
                            // Mark checkboxes as completed
                            checkboxes.forEach(checkbox => {
                                checkbox.disabled = true;
                                const status = checkbox.closest('.question-item').querySelector('.status');
                                status.textContent = 'COMPLETED';
                                status.className = 'status completed';
                                
                                // Add file status
                                const details = checkbox.closest('.question-item').querySelector('.details');
                                const fileStatus = document.createElement('div');
                                fileStatus.className = 'file-status file-exists';
                                fileStatus.innerHTML = '<i class="fas fa-file-check"></i> System tagged with existing file ✓ Exists';
                                details.appendChild(fileStatus);
                            });
                            
                            // Show messages
                            if (data.messages.length > 0) {
                                data.messages.forEach(msg => showAlert('success', msg));
                            }
                            
                            this.disabled = true;
                            this.innerHTML = '<i class="fas fa-check"></i> System Tagging Complete';
                        } else {
                            showAlert('danger', 'System tagging failed. Please try again.');
                            if (data.errors.length > 0) {
                                data.errors.forEach(err => showAlert('danger', err));
                            }
                            this.disabled = false;
                            this.innerHTML = originalText;
                        }
                    })
                    .catch(error => {
                        console.error('Error:', error);
                        showAlert('danger', 'Network error occurred. Please try again.');
                        this.disabled = false;
                        this.innerHTML = originalText;
                    });
                });
            });
        });

        function showAlert(type, message) {
            const alertContainer = document.getElementById('alertContainer');
            const alertDiv = document.createElement('div');
            alertDiv.className = `alert alert-${type === 'warning' ? 'danger' : type}`;
            alertDiv.innerHTML = `
                <i class="fas fa-${type === 'success' ? 'check-circle' : 'exclamation-triangle'}"></i>
                ${message}
            `;
            
            alertContainer.appendChild(alertDiv);
            
            // Auto-remove after 5 seconds
            setTimeout(() => {
                alertDiv.remove();
            }, 5000);
            
            // Scroll to alert
            alertDiv.scrollIntoView({ behavior: 'smooth' });
        }

        // Document viewer functions
        let currentDocumentPath = '';

        function loadDocument() {
            const selector = document.getElementById('documentSelector');
            const selectedOption = selector.options[selector.selectedIndex];
            
            if (!selectedOption.value) {
                showAlert('warning', 'Please select a document first.');
                return;
            }
            
            currentDocumentPath = selectedOption.value;
            const assessmentType = selectedOption.getAttribute('data-type');
            const questionNumber = selectedOption.getAttribute('data-question');
            const fileExtension = selectedOption.getAttribute('data-extension');
            const totalQuestions = selectedOption.getAttribute('data-total');
            const completedQuestions = selectedOption.getAttribute('data-completed');
            const dbFilePath = selectedOption.getAttribute('data-db-path');
            const fileName = selectedOption.textContent.split(' - ')[1];
            
            // Update document info
            const docInfo = document.getElementById('documentInfo');
            const docDetails = document.getElementById('docDetails');
            docDetails.innerHTML = `
                <strong>Assessment Type:</strong> ${assessmentType}<br>
                <strong>Representative Question:</strong> ${questionNumber}<br>
                <strong>Progress:</strong> ${completedQuestions}/${totalQuestions} questions completed<br>
                <strong>File Name:</strong> ${fileName}<br>
                <strong>File Type:</strong> ${fileExtension.toUpperCase()}<br>
                <strong>Database Path:</strong> ${dbFilePath}<br>
                <strong>Actual File Path:</strong> ${currentDocumentPath}
            `;
            docInfo.style.display = 'block';
            
            // Create iframe with corrected file path
            const container = document.getElementById('documentContainer');
            // Handle database path vs actual file location
            let iframeSrc = currentDocumentPath;
            if (currentDocumentPath.startsWith('POE/')) {
                // Convert POE/filename.pdf to POE/filename.pdf (actual path)
                iframeSrc = currentDocumentPath;
            }
            
            container.innerHTML = `
                <iframe id="documentIframe" class="document-iframe" 
                        src="${iframeSrc}" 
                        title="Document Viewer">
                </iframe>
            `;
            
            // Handle iframe load errors
            const iframe = document.getElementById('documentIframe');
            iframe.onload = function() {
                console.log('Document loaded successfully');
            };
            
            iframe.onerror = function() {
                container.innerHTML = `
                    <div class="no-document">
                        <i class="fas fa-exclamation-triangle" style="font-size: 3rem; margin-bottom: 15px; color: #dc3545;"></i>
                        <h3>Error Loading PDF Document</h3>
                        <p>The PDF document could not be loaded. This might be due to:</p>
                        <ul style="text-align: left; max-width: 400px; margin: 15px auto;">
                            <li>PDF file is corrupted or damaged</li>
                            <li>File path is incorrect</li>
                            <li>File permissions issue</li>
                            <li>Browser PDF viewer compatibility</li>
                        </ul>
                        <p><strong>File:</strong> ${fileName}</p>
                        <button type="button" class="doc-btn secondary" onclick="openInNewTab()">
                            <i class="fas fa-external-link-alt"></i> Try Opening in New Tab
                        </button>
                    </div>
                `;
            };
        }

        function downloadDocument() {
            if (!currentDocumentPath) {
                showAlert('warning', 'Please select and load a document first.');
                return;
            }
            
            // Use the same path logic as iframe
            let downloadPath = currentDocumentPath;
            if (currentDocumentPath.startsWith('POE/')) {
                downloadPath = currentDocumentPath;
            }
            
            // Create a temporary link to trigger download
            const link = document.createElement('a');
            link.href = downloadPath;
            link.download = currentDocumentPath.split('/').pop();
            link.target = '_blank';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            
            showAlert('success', 'Download started. If it doesn\'t work, try right-clicking the document and selecting "Save as..."');
        }

        function openInNewTab() {
            if (!currentDocumentPath) {
                showAlert('warning', 'Please select and load a document first.');
                return;
            }
            
            // Use the same path logic as iframe
            let newTabPath = currentDocumentPath;
            if (currentDocumentPath.startsWith('POE/')) {
                newTabPath = currentDocumentPath;
            }
            
            window.open(newTabPath, '_blank');
        }

        // Auto-load document when selection changes
        document.addEventListener('DOMContentLoaded', function() {
            const selector = document.getElementById('documentSelector');
            if (selector) {
                selector.addEventListener('change', function() {
                    if (this.value) {
                        loadDocument();
                    } else {
                        // Reset to no document state
                        document.getElementById('documentContainer').innerHTML = `
                            <div class="no-document">
                                <i class="fas fa-file-pdf" style="font-size: 3rem; margin-bottom: 15px; opacity: 0.5;"></i>
                                <h3>No PDF Document Selected</h3>
                                <p>Please select a PDF document from the dropdown above to view it.</p>
                            </div>
                        `;
                        document.getElementById('documentInfo').style.display = 'none';
                        currentDocumentPath = '';
                    }
                });
            }
        });
    </script>
</body>
</html>

<?php
$conn->close();
ob_end_flush();
?>
