<?php
/**
 * Get Bricklayer ARPL Toolkit Data
 * Loads bricklayer trade data with activities from database
 * Endpoint: POST mobile/get_bricklayer_toolkit_data.php
 * 
 * Note: Since bricklayer-specific tables don't exist yet, falls back to electrician tables
 */

// Increase execution time for large dataset
set_time_limit(60);
ini_set('max_execution_time', 60);

header('Content-Type: application/json');
require_once 'connection.php';

try {
    // Get input from POST JSON body
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    // Extract parameters - support both JSON body and direct POST
    $learnerID = 0;
    $classID = 0;
    
    if (isset($data['learnerID']) && isset($data['classID'])) {
        // From JSON body
        $learnerID = intval($data['learnerID']);
        $classID = intval($data['classID']);
    } elseif (isset($_POST['learnerID']) && isset($_POST['classID'])) {
        // From direct POST (fallback)
        $learnerID = intval($_POST['learnerID']);
        $classID = intval($_POST['classID']);
    }
    
    $ofo_number = '641201';  // Bricklayer workplace activities OFO
    
    if (!$learnerID || !$classID) {
        throw new Exception('Missing learnerID or classID. Received: ' . json_encode([
            'json_input' => $input,
            'json_decoded' => $data,
            'post_data' => $_POST,
            'learnerID' => $learnerID,
            'classID' => $classID
        ]));
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD LEARNER DETAILS
    // ══════════════════════════════════════════════════════════
    $stmt = $conn->prepare("
        SELECT 
            LearnerID, Title, Name, Surname, IDNumber, DateOfBirth,
            PhoneNumber, Email, Gender, Race, Language,
            AddressLine1, AddressLine2, AddressLine3, PostalCode,
            SchoolName, SchoolCompletion, SchoolGrade
        FROM learnerdetails
        WHERE LearnerID = ?
    ");
    if (!$stmt) {
        throw new Exception('Database error: ' . $conn->error);
    }
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $learner = $result->fetch_assoc();
    $stmt->close();
    
    // ══════════════════════════════════════════════════════════
    // LOAD CLASS INFO
    // ══════════════════════════════════════════════════════════
    $stmt = $conn->prepare("
        SELECT c.className, c.classID, s.siteName
        FROM class c
        LEFT JOIN sites s ON c.siteID = s.siteID
        WHERE c.classID = ?
    ");
    if (!$stmt) {
        throw new Exception('Database error: ' . $conn->error);
    }
    $stmt->bind_param('i', $classID);
    $stmt->execute();
    $result = $stmt->get_result();
    $class_info = $result->fetch_assoc();
    $stmt->close();
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX B DATA (Theory Assessment Activities)
    // Using bricklaying activities from database - OPTIMIZED
    // ══════════════════════════════════════════════════════════
    $appendixB_table = 'arplappxb_bricklaying_activities';
    $appendixB_ratings_table = 'arplappxb_activity_ratings';
    
    // OPTIMIZED: Single query with LEFT JOIN to get activities and ratings together
    $sql = "
        SELECT 
            a.activity_id,
            a.activity_number,
            a.activity_name,
            r.competency_level,
            r.rating as rating_score,
            r.comments,
            r.assessment_date as rating_date,
            cs.rating_name,
            cs.rating_description
        FROM " . $conn->real_escape_string($appendixB_table) . " a
        LEFT JOIN " . $conn->real_escape_string($appendixB_ratings_table) . " r 
            ON a.activity_id = r.activity_id AND r.learnerID = ?
        LEFT JOIN arpl_competency_scale cs ON r.competency_level = cs.level
        ORDER BY a.activity_number ASC
    ";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Appendix B query error: ' . $conn->error);
    }
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $appendixB = [];
    while ($row = $result->fetch_assoc()) {
        $activity = [
            'activity_id' => $row['activity_id'],
            'activity_number' => $row['activity_number'],
            'activity_name' => $row['activity_name']
        ];
        
        // Add rating if exists
        if ($row['competency_level'] !== null) {
            $activity['rating'] = [
                'activity_id' => $row['activity_id'],
                'competency_level' => $row['competency_level'],
                'rating_score' => $row['rating_score'],
                'comments' => $row['comments'],
                'rating_date' => $row['rating_date'],
                'rating_name' => $row['rating_name'],
                'rating_description' => $row['rating_description']
            ];
            $activity['has_rating'] = true;
        } else {
            $activity['rating'] = null;
            $activity['has_rating'] = false;
        }
        
        $appendixB[] = $activity;
    }
    $stmt->close();
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX D DATA (Practical Skills - Yes/No responses)
    // ══════════════════════════════════════════════════════════
    $appendixD_data = null;
    $appendixD_table = 'arpl_appendix_d_bricklayer';
    
    // Check if table exists first
    $table_check = $conn->query("SHOW TABLES LIKE '$appendixD_table'");
    if ($table_check && $table_check->num_rows > 0) {
        $sql = "SELECT * FROM " . $conn->real_escape_string($appendixD_table) . " WHERE learnerID = ? LIMIT 1";
        $stmt = $conn->prepare($sql);
        if ($stmt) {
            $stmt->bind_param('i', $learnerID);
            $stmt->execute();
            $result = $stmt->get_result();
            $appendixD_data = $result->fetch_assoc();
            $stmt->close();
        }
    }
    
    // Extract activity responses as object (NOT array - must be object for Dart)
    $appendixD = (object)[];
    if ($appendixD_data) {
        // Load all activity responses from the database record
        for ($i = 1; $i <= 22; $i++) {
            $field = 'activity_' . $i;
            if (isset($appendixD_data[$field])) {
                $appendixD->{$field} = $appendixD_data[$field];
            } else {
                $appendixD->{$field} = '';
            }
        }
        $appendixD->saved_at = $appendixD_data['updated_at'] ?? $appendixD_data['created_at'] ?? null;
    } else {
        // If no data exists, initialize with empty object
        for ($i = 1; $i <= 22; $i++) {
            $appendixD->{'activity_' . $i} = '';
        }
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX E DATA (Workplace Activities - Used in Appendix F)
    // Table: arplappxe_bricklaying_activities
    // These same activities show in Appendix F workplace observations - OPTIMIZED
    // ══════════════════════════════════════════════════════════
    $appendixE_table = 'arplappxe_bricklaying_activities';
    $appendixE_ratings_table = 'arplappxe_bricklaying_activity_ratings';
    
    // OPTIMIZED: Single query with LEFT JOIN (ratings table may not have ofo_number column)
    $sql = "
        SELECT 
            a.activity_id,
            a.activity_number,
            a.activity_name,
            a.ofo_number,
            r.competency_level,
            r.rating as rating_score,
            r.comments,
            r.assessment_date as rating_date
        FROM " . $conn->real_escape_string($appendixE_table) . " a
        LEFT JOIN " . $conn->real_escape_string($appendixE_ratings_table) . " r
            ON a.activity_id = r.activity_id AND r.learnerID = ?
        WHERE a.ofo_number = ?
        ORDER BY a.activity_number ASC
    ";
    
    $stmt = $conn->prepare($sql);
    $appendixE = [];
    if ($stmt) {
        $stmt->bind_param('is', $learnerID, $ofo_number);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $activity = [
                'activity_id' => $row['activity_id'],
                'activity_number' => $row['activity_number'],
                'activity_name' => $row['activity_name'],
                'ofo_number' => $row['ofo_number']
            ];
            
            if ($row['competency_level'] !== null) {
                $activity['rating'] = [
                    'activity_id' => $row['activity_id'],
                    'competency_level' => $row['competency_level'],
                    'rating_score' => $row['rating_score'],
                    'comments' => $row['comments'],
                    'rating_date' => $row['rating_date']
                ];
                $activity['has_rating'] = true;
            } else {
                $activity['rating'] = null;
                $activity['has_rating'] = false;
            }
            
            $appendixE[] = $activity;
        }
        $stmt->close();
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX F DATA (Practical Assessment Evaluation)
    // ══════════════════════════════════════════════════════════
    $appendixF = null;
    $appendixF_table = 'arpl_appendix_f_bricklayer';
    $appendixF_tasks_table = 'arpl_appendix_f_practical_tasks_bricklayer';
    $appendixF_obs_table = 'arpl_appendix_f_workplace_observations_bricklayer';
    
    // Check if main table exists
    $table_check = $conn->query("SHOW TABLES LIKE '$appendixF_table'");
    if ($table_check && $table_check->num_rows > 0) {
        // Get main appendix F record
        $sql = "SELECT * FROM " . $conn->real_escape_string($appendixF_table) . " WHERE learnerID = ? ORDER BY created_at DESC LIMIT 1";
        $stmt = $conn->prepare($sql);
        if ($stmt) {
            $stmt->bind_param('i', $learnerID);
            $stmt->execute();
            $result = $stmt->get_result();
            if ($row = $result->fetch_assoc()) {
                $appendixF = $row;
                
                // Get practical tasks
                $appendixF['practicalTasks'] = [];
                $tasks_check = $conn->query("SHOW TABLES LIKE '$appendixF_tasks_table'");
                if ($tasks_check && $tasks_check->num_rows > 0) {
                    $sql_tasks = "SELECT * FROM " . $conn->real_escape_string($appendixF_tasks_table) . " WHERE appendixF_id = ? ORDER BY taskNumber";
                    $stmt_tasks = $conn->prepare($sql_tasks);
                    if ($stmt_tasks) {
                        $stmt_tasks->bind_param('i', $appendixF['id']);
                        $stmt_tasks->execute();
                        $result_tasks = $stmt_tasks->get_result();
                        while ($task = $result_tasks->fetch_assoc()) {
                            $appendixF['practicalTasks'][] = $task;
                        }
                        $stmt_tasks->close();
                    }
                }
                
                // Get workplace observations
                $appendixF['workplaceObservations'] = [];
                $obs_check = $conn->query("SHOW TABLES LIKE '$appendixF_obs_table'");
                if ($obs_check && $obs_check->num_rows > 0) {
                    $sql_obs = "SELECT * FROM " . $conn->real_escape_string($appendixF_obs_table) . " WHERE appendixF_id = ? ORDER BY observationNumber";
                    $stmt_obs = $conn->prepare($sql_obs);
                    if ($stmt_obs) {
                        $stmt_obs->bind_param('i', $appendixF['id']);
                        $stmt_obs->execute();
                        $result_obs = $stmt_obs->get_result();
                        while ($obs = $result_obs->fetch_assoc()) {
                            $appendixF['workplaceObservations'][] = $obs;
                        }
                        $stmt_obs->close();
                    }
                }
            }
            $stmt->close();
        }
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX H DATA (Access Recommendations - Ready/Not Ready)
    // ══════════════════════════════════════════════════════════
    $appendixH_items = [];
    $appendixH_recommendations = [];
    $appendixH_gap_standards = [];
    
    // Get ACR items for bricklaying - check if table exists
    $acr_table = 'appxh_acrbricklaying';
    $table_check = $conn->query("SHOW TABLES LIKE '$acr_table'");
    if ($table_check && $table_check->num_rows > 0) {
        $stmt = $conn->prepare("
            SELECT ACRID, AssessmentType
            FROM appxh_acrbricklaying
            ORDER BY ACRID ASC
        ");
        if ($stmt) {
            $stmt->execute();
            $result = $stmt->get_result();
            while ($row = $result->fetch_assoc()) {
                $appendixH_items[] = [
                    'acrId' => intval($row['ACRID']),
                    'assessmentType' => $row['AssessmentType']
                ];
            }
            $stmt->close();
        }
    }
    
    // Get saved recommendations for this learner from bricklayer table
    $rec_table = 'arplbricklayer_access_recommendation';
    $table_check = $conn->query("SHOW TABLES LIKE '$rec_table'");
    $recommendationsMap = [];
    if ($table_check && $table_check->num_rows > 0) {
        $stmt = $conn->prepare("
            SELECT 
                RecommendationID as recommendationId,
                LearnerID as learnerId,
                ACRID as acrId,
                Trade as trade,
                OFOCode as ofoCode,
                Status as status,
                Remarks as remarks,
                CreatedAt as createdAt,
                UpdatedAt as updatedAt
            FROM arplbricklayer_access_recommendation
            WHERE LearnerID = ?
            ORDER BY ACRID ASC
        ");
        
        if ($stmt) {
            $stmt->bind_param('i', $learnerID);
            $stmt->execute();
            $result = $stmt->get_result();
            while ($row = $result->fetch_assoc()) {
                $recommendationsMap[$row['acrId']] = $row;
                $appendixH_recommendations[] = $row;
            }
            $stmt->close();
        }
    }
    
    // Create default recommendations for ACR items without saved data
    foreach ($appendixH_items as $item) {
        if (!isset($recommendationsMap[$item['acrId']])) {
            $appendixH_recommendations[] = [
                'recommendationId' => 0,
                'learnerId' => $learnerID,
                'acrId' => $item['acrId'],
                'trade' => 'bricklayer',
                'ofoCode' => $ofo_number,
                'status' => '',  // Default empty - user fills in during assessment
                'remarks' => '',
                'createdAt' => date('Y-m-d H:i:s'),
                'updatedAt' => date('Y-m-d H:i:s')
            ];
        }
    }
    
    // Sort by acrId
    usort($appendixH_recommendations, function($a, $b) {
        return $a['acrId'] - $b['acrId'];
    });
    
    // Get gap unit standards if "Recommended for Gap Closure" is selected
    $gap_table = 'arplbricklayer_gap_unit_standards';
    $table_check = $conn->query("SHOW TABLES LIKE '$gap_table'");
    if ($table_check && $table_check->num_rows > 0) {
        $stmt = $conn->prepare("
            SELECT 
                unit_standard_id as unitStandardId,
                unit_standard_name as unitStandardName,
                assigned_date as assignedDate
            FROM arplbricklayer_gap_unit_standards
            WHERE learner_id = ?
            ORDER BY created_at DESC
        ");
        
        if ($stmt) {
            $stmt->bind_param('i', $learnerID);
            $stmt->execute();
            $result = $stmt->get_result();
            while ($row = $result->fetch_assoc()) {
                $appendixH_gap_standards[] = $row;
            }
            $stmt->close();
        }
    }
    
    // ══════════════════════════════════════════════════════════
    // BUILD RESPONSE
    // ══════════════════════════════════════════════════════════
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'learnerID' => $learnerID,
        'classID' => $classID,
        'trade' => 'bricklayer',
        'ofo_number' => $ofo_number,
        'learner' => $learner,
        'facilitator' => null,
        'class_info' => $class_info,
        'appendixA' => null,
        'appendixB' => $appendixB,
        'appendixC' => null,
        'appendixD' => $appendixD,
        'appendixE' => $appendixE,
        'appendixF' => $appendixF,
        'appendixG' => null,
        'appendixH' => (object)[
            'items' => $appendixH_items,
            'recommendations' => $appendixH_recommendations,
            'gap_standards' => $appendixH_gap_standards
        ],
        'appendixI' => null,
        'appendixJ' => null
    ]);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();

