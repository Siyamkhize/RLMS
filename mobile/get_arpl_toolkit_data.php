<?php
/**
 * ARPL Toolkit Data API
 * Returns complete toolkit data for a learner (all appendices)
 * Trade-aware: Routes queries to trade-specific tables
 * 
 * Endpoint: POST mobile/get_arpl_toolkit_data.php
 * 
 * Request:
 * {
 *   "learnerID": 20286,
 *   "classID": 782,
 *   "ofoNumber": "671101",
 *   "trade": "electrician"  // Optional: electrician, bricklayer, or plumber
 * }
 * 
 * Response: Complete toolkit data including all appendices
 */

header('Content-Type: application/json');
require_once 'connection.php';

// ══════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ══════════════════════════════════════════════════════════

/**
 * Securely load signature file and convert to base64 data URL
 * Prevents exposing file paths in API responses
 * 
 * @param string $signature - Either filename or already base64 data
 * @return string|null - Base64 data URL or null if file not found
 */
function loadSignatureSecurely($signature) {
    if (empty($signature)) {
        return null;
    }
    
    // Check if signature is a filename (ends with .png, .jpg, etc.)
    if (preg_match('/\.(png|jpg|jpeg|gif)$/i', $signature)) {
        // It's a filename - look for it in the mobile/signatures folder
        $mobilePath = __DIR__ . '/signatures/' . $signature;
        
        // Try to load the file and convert to base64
        if (file_exists($mobilePath)) {
            $imageData = file_get_contents($mobilePath);
            $base64 = base64_encode($imageData);
            return 'data:image/png;base64,' . $base64;
        }
        
        // Try parent signatures folder
        $parentPath = dirname(__DIR__) . '/signatures/' . $signature;
        if (file_exists($parentPath)) {
            $imageData = file_get_contents($parentPath);
            $base64 = base64_encode($imageData);
            return 'data:image/png;base64,' . $base64;
        }
        
        // File not found
        error_log("ERROR: Signature file not found: $signature");
        return null;
    }
    
    // If it's already a data URL, use as-is
    if (strpos($signature, 'data:image') === 0) {
        return $signature;
    }
    
    // If it's just base64, prepend data URL prefix
    if (!empty($signature)) {
        return 'data:image/png;base64,' . $signature;
    }
    
    return null;
}

function getTradeName($ofoNumber) {
    $ofoMapping = [
        '671101' => 'electrician',    // OFO for Electrician
        '642601' => 'plumbing',       // OFO for Plumber (FIXED from 671102)
        '641201' => 'bricklaying'     // OFO for Bricklayer (FIXED from 671103)
    ];
    return isset($ofoMapping[$ofoNumber]) ? $ofoMapping[$ofoNumber] : null;
}

function getTableName($appendix, $trade) {
    if ($trade === 'electrician') {
        $tables = [
            'a' => 'arpl_appendix_a',
            'c' => 'arpl_appendix_c',
            'd' => 'arpl_appendix_d',
            'f' => 'arpl_appendix_f',
            'f_tasks' => 'arpl_appendix_f_practical_tasks',
            'f_obs' => 'arpl_appendix_f_workplace_observations',
            'g' => 'arpl_appendix_g',
            'i' => 'arpl_appendix_i',
            'j' => 'arpl_appendix_j'
        ];
    } elseif ($trade === 'bricklaying') {
        // Note: appendix tables use 'bricklayer', activity tables use 'bricklaying'
        $tables = [
            'a' => 'arpl_appendix_a_bricklayer',
            'c' => 'arpl_appendix_c_bricklayer',
            'd' => 'arpl_appendix_d_bricklayer',
            'f' => 'arpl_appendix_f_bricklayer',
            'f_tasks' => 'arpl_appendix_f_practical_tasks_bricklayer',
            'f_obs' => 'arpl_appendix_f_workplace_observations_bricklayer',
            'g' => 'arpl_appendix_g_bricklayer',
            'i' => 'arpl_appendix_i_bricklayer',
            'j' => 'arpl_appendix_j_bricklayer'
        ];
    } elseif ($trade === 'plumbing') {
        $tables = [
            'a' => 'arpl_appendix_a_plumber',
            'c' => 'arpl_appendix_c_plumber',
            'd' => 'arpl_appendix_d_plumber',
            'f' => 'arpl_appendix_f_plumber',
            'f_tasks' => 'arpl_appendix_f_practical_tasks_plumber',
            'f_obs' => 'arpl_appendix_f_workplace_observations_plumber',
            'g' => 'arpl_appendix_g_plumber',
            'i' => 'arpl_appendix_i_plumber',
            'j' => 'arpl_appendix_j_plumber'
        ];
    } else {
        return null;
    }
    return isset($tables[$appendix]) ? $tables[$appendix] : null;
}

try {
    // Read JSON input from request body
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    // Get request parameters (support JSON body, POST, and GET)
    if ($data && isset($data['learnerID'])) {
        $learnerID = intval($data['learnerID']);
        $classID = isset($data['classID']) ? intval($data['classID']) : 0;
        $ofoNumber = isset($data['ofoNumber']) ? $data['ofoNumber'] : null;
        $trade = isset($data['trade']) ? $data['trade'] : null;
    } else {
        // Fallback to POST/GET parameters
        $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0);
        $classID = isset($_POST['classID']) ? intval($_POST['classID']) : (isset($_GET['classID']) ? intval($_GET['classID']) : 0);
        $ofoNumber = isset($_POST['ofoNumber']) ? $_POST['ofoNumber'] : (isset($_GET['ofoNumber']) ? $_GET['ofoNumber'] : null);
        $trade = isset($_POST['trade']) ? $_POST['trade'] : (isset($_GET['trade']) ? $_GET['trade'] : null);
    }
    
    // ══════════════════════════════════════════════════════════
    // FETCH OFO FROM CLASS'S TRADE IF NOT PROVIDED
    // ══════════════════════════════════════════════════════════
    if (!$ofoNumber || $ofoNumber === '671101') {
        // Query class's trade to get OFO
        if ($classID > 0) {
            $stmt_trade = $conn->prepare("
                SELECT t.ofo_number, t.trade_name
                FROM class c
                LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
                WHERE c.classID = ?
                LIMIT 1
            ");
            
            if ($stmt_trade) {
                $stmt_trade->bind_param("i", $classID);
                $stmt_trade->execute();
                $result_trade = $stmt_trade->get_result();
                
                if ($result_trade && $result_trade->num_rows > 0) {
                    $row_trade = $result_trade->fetch_assoc();
                    $tradeOfo = $row_trade['ofo_number'] ?? null;
                    $tradeName = $row_trade['trade_name'] ?? null;
                    
                    // Use class trade's OFO if found
                    if ($tradeOfo && ($tradeOfo !== '671101' || !$ofoNumber)) {
                        $ofoNumber = $tradeOfo;
                        if ($tradeName) {
                            $trade = strtolower($tradeName);
                        }
                    }
                }
                $stmt_trade->close();
            }
        }
        
        // If still not found from class, try learner's qualification
        if (!$ofoNumber || $ofoNumber === '671101') {
            $stmt_ofo = $conn->prepare("
                SELECT q.OFOcode 
                FROM learnerdetails l
                LEFT JOIN qualification q ON l.qualification_id = q.qualification_id
                WHERE l.LearnerID = ?
                LIMIT 1
            ");
            
            if ($stmt_ofo) {
                $stmt_ofo->bind_param("i", $learnerID);
                $stmt_ofo->execute();
                $result_ofo = $stmt_ofo->get_result();
                
                if ($result_ofo && $result_ofo->num_rows > 0) {
                    $row_ofo = $result_ofo->fetch_assoc();
                    $dbOfo = $row_ofo['OFOcode'] ?? null;
                    
                    // Use database OFO if found and different from what was passed
                    if ($dbOfo && ($dbOfo !== '671101' || !$ofoNumber)) {
                        $ofoNumber = $dbOfo;
                    }
                }
                $stmt_ofo->close();
            }
        }
    }
    
    // Auto-detect trade from OFO if not provided
    if (!$trade && $ofoNumber) {
        $trade = getTradeName($ofoNumber);
    }
    
    // If still no trade found, return error instead of defaulting to electrician
    if (!$trade || !$ofoNumber) {
        throw new Exception('Could not determine trade for learner. ClassID: ' . $classID . ', OFO: ' . ($ofoNumber ?? 'null'));
    }
    
    if ($learnerID <= 0) {
        throw new Exception('Missing or invalid learnerID');
    }
    
    $response = [
        'status' => 'success',
        'learnerID' => $learnerID,
        'classID' => $classID,
        'ofoNumber' => $ofoNumber,
        'trade' => $trade
    ];
    
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
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $response['learner'] = $result->fetch_assoc();
    $stmt->close();
    
    if (!$response['learner']) {
        throw new Exception('Learner not found');
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD CLASS INFO
    // ══════════════════════════════════════════════════════════
    if ($classID > 0) {
        $stmt = $conn->prepare("
            SELECT c.className, c.classID, s.siteName
            FROM class c
            LEFT JOIN sites s ON c.siteID = s.siteID
            WHERE c.classID = ?
        ");
        $stmt->bind_param('i', $classID);
        $stmt->execute();
        $result = $stmt->get_result();
        $response['class_info'] = $result->fetch_assoc();
        $stmt->close();
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD COMPETENCY SCALE (for interpreting ratings)
    // ══════════════════════════════════════════════════════════
    $stmt = $conn->prepare("
        SELECT score, proficiency_level, description
        FROM arpl_competency_scale
        ORDER BY score ASC
    ");
    $stmt->execute();
    $result = $stmt->get_result();
    $response['competency_scale'] = [];
    while ($row = $result->fetch_assoc()) {
        $response['competency_scale'][] = $row;
    }
    $stmt->close();
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX B DATA (Theory Assessment - Competency Ratings 1-5)
    // ══════════════════════════════════════════════════════════
    // Get trade-specific activities table
    $appendixB_table = 'arplappxb_' . $trade . '_activities';
    // Activity ratings table is SHARED for all trades (Appendix B)
    $appendixB_ratings_table = 'arplappxb_activity_ratings';
    
    // Get all activities for this trade
    $result = $conn->query("
        SELECT activity_id, activity_number, activity_name
        FROM " . $conn->real_escape_string($appendixB_table) . "
        ORDER BY activity_number ASC
    ");
    if (!$result) {
        throw new Exception('Database error: ' . $conn->error . ' | Table: ' . $appendixB_table);
    }
    $appendixB_activities = [];
    while ($row = $result->fetch_assoc()) {
        $appendixB_activities[] = $row;
    }
    
    // Get saved ratings for this learner from trade-specific table
    $sql = "
        SELECT 
            aar.activity_id,
            aar.competency_scale_id as rating_score,
            aar.comments,
            aar.rating_date,
            acs.proficiency_level,
            acs.description as scale_description
        FROM " . $conn->real_escape_string($appendixB_ratings_table) . " aar
        LEFT JOIN arpl_competency_scale acs ON aar.competency_scale_id = acs.score
        WHERE aar.learnerID = ?
    ";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Database error: ' . $conn->error . ' | Table: ' . $appendixB_ratings_table);
    }
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $ratingsMap = [];
    while ($row = $result->fetch_assoc()) {
        $ratingsMap[$row['activity_id']] = $row;
    }
    $stmt->close();
    
    // Combine activities with ratings
    $response['appendixB'] = [];
    foreach ($appendixB_activities as $activity) {
        $activityData = $activity;
        if (isset($ratingsMap[$activity['activity_id']])) {
            $activityData['rating'] = $ratingsMap[$activity['activity_id']];
            $activityData['has_rating'] = true;
        } else {
            $activityData['rating'] = null;
            $activityData['has_rating'] = false;
        }
        $response['appendixB'][] = $activityData;
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX D DATA (Practical Skills - Yes/No responses)
    // ══════════════════════════════════════════════════════════
    $tableD = getTableName('d', $trade);
    $stmt = null;
    if ($tableD) {
        $stmt = $conn->prepare("
            SELECT * FROM `".$conn->real_escape_string($tableD)."`
            WHERE learnerID = ?
            ORDER BY id DESC
            LIMIT 1
        ");
    }
    
    $appendixD = null;
    if ($stmt) {
        $stmt->bind_param('i', $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();
        $appendixD = $result->fetch_assoc();
        $stmt->close();
    }
    
    // Extract activity responses as object/map (NOT array)
    $response['appendixD'] = (object)[];
    if ($appendixD) {
        for ($i = 1; $i <= 22; $i++) {
            $field = 'activity_' . $i;
            if (isset($appendixD[$field])) {
                $response['appendixD']->{$field} = $appendixD[$field];
            }
        }
        $response['appendixD']->saved_at = $appendixD['updated_at'] ?? $appendixD['created_at'] ?? null;
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX E DATA (Workplace Experience - Competency Ratings 1-5)
    // Also used for Appendix F Workplace Observations
    // ══════════════════════════════════════════════════════════
    // Get trade-specific activities table
    // Table names: arplappxe_electrician_activities, arplappxe_bricklaying_activities, arplappxe_plumbing_activities
    $appendixE_table = 'arplappxe_' . $trade . '_activities';
    $appendixE_ratings_table = 'arplappxe_' . $trade . '_activity_ratings';
    
    // Get all activities for this trade
    $stmt = $conn->prepare("
        SELECT activity_id, activity_number, activity_name, ofo_number
        FROM " . $conn->real_escape_string($appendixE_table) . "
        WHERE ofo_number = ?
        ORDER BY activity_number ASC
    ");
    $stmt->bind_param('s', $ofoNumber);
    $stmt->execute();
    $result = $stmt->get_result();
    $appendixE_activities = [];
    while ($row = $result->fetch_assoc()) {
        $appendixE_activities[] = $row;
    }
    $stmt->close();
    
    // Get saved ratings for this learner from trade-specific table
    $sql = "
        SELECT 
            activity_id,
            competency_scale_id as rating_score,
            comments,
            rating_date
        FROM " . $conn->real_escape_string($appendixE_ratings_table) . "
        WHERE learnerID = ? AND ofo_number = ?
    ";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    $result = $stmt->get_result();
    $ratingsMapE = [];
    while ($row = $result->fetch_assoc()) {
        $ratingsMapE[$row['activity_id']] = $row;
    }
    $stmt->close();
    
    // Combine activities with ratings
    $response['appendixE'] = [];
    foreach ($appendixE_activities as $activity) {
        $activityData = $activity;
        if (isset($ratingsMapE[$activity['activity_id']])) {
            $activityData['rating'] = $ratingsMapE[$activity['activity_id']];
            $activityData['has_rating'] = true;
        } else {
            $activityData['rating'] = null;
            $activityData['has_rating'] = false;
        }
        $response['appendixE'][] = $activityData;
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX H DATA (Access Recommendation)
    // ══════════════════════════════════════════════════════════
    // Get ACR assessment items (4 components) - trade specific
    $acrTable = 'appxh_acr' . $trade;
    $appendixH_items = [];
    $appendixH_recommendations = [];
    $appendixH_gap_standards = [];
    
    $stmt = $conn->prepare("
        SELECT ACRID as acrId, AssessmentType as assessmentType
        FROM `".$conn->real_escape_string($acrTable)."`
        ORDER BY ACRID
    ");
    if ($stmt) {
        $stmt->execute();
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            $appendixH_items[] = $row;
        }
        $stmt->close();
    }
    
    // Get saved recommendations for this learner (trade-specific)
    $recommendationTable = 'arpl' . $trade . '_access_recommendation';
    
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
        FROM `".$conn->real_escape_string($recommendationTable)."`
        WHERE LearnerID = ?
        ORDER BY CreatedAt DESC
    ");
    if ($stmt) {
        $stmt->bind_param('i', $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            $appendixH_recommendations[] = $row;
        }
        $stmt->close();
    }
    
    // Get gap analysis unit standards (if applicable)
    $table_check = $conn->query("SHOW TABLES LIKE 'arpl_gap_analysis_unit_standards'");
    if ($table_check && $table_check->num_rows > 0) {
        $stmt = $conn->prepare("
            SELECT * FROM arpl_gap_analysis_unit_standards
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
    
    $response['appendixH'] = (object)[
        'items' => $appendixH_items,
        'recommendations' => $appendixH_recommendations,
        'gap_standards' => $appendixH_gap_standards
    ];
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX A DATA (Application Form)
    // ══════════════════════════════════════════════════════════
    $response['appendixA'] = null;
    $tableA = getTableName('a', $trade);
    if ($tableA) {
        $table_check = $conn->query("SHOW TABLES LIKE '".$conn->real_escape_string($tableA)."'");
        if ($table_check && $table_check->num_rows > 0) {
            $stmt = $conn->prepare("
                SELECT * FROM `".$conn->real_escape_string($tableA)."`
                WHERE learnerID = ? AND ofo_number = ?
                LIMIT 1
            ");
            if ($stmt) {
                $stmt->bind_param('is', $learnerID, $ofoNumber);
                $stmt->execute();
                $result = $stmt->get_result();
                $appendixA = $result->fetch_assoc();
                $stmt->close();
                
                if ($appendixA) {
                    // Decode JSON employment history
                    if ($appendixA['employment_history']) {
                        $appendixA['employment_history'] = json_decode($appendixA['employment_history'], true) ?? [];
                    } else {
                        $appendixA['employment_history'] = [];
                    }
                    
                    // Secure signature handling - never expose file URLs
                    if (!empty($appendixA['candidate_signature'])) {
                        $appendixA['candidate_signature'] = loadSignatureSecurely($appendixA['candidate_signature']);
                    }
                }
                $response['appendixA'] = $appendixA;
            }
        }
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX C DATA (Trade Curriculum)
    // ══════════════════════════════════════════════════════════
    $response['appendixC'] = null;
    $tableC = getTableName('c', $trade);
    if ($tableC) {
        $table_check = $conn->query("SHOW TABLES LIKE '".$conn->real_escape_string($tableC)."'");
        if ($table_check && $table_check->num_rows > 0) {
            $stmt = $conn->prepare("
                SELECT * FROM `".$conn->real_escape_string($tableC)."`
                WHERE learnerID = ? AND ofo_number = ?
                LIMIT 1
            ");
            if ($stmt) {
                $stmt->bind_param('is', $learnerID, $ofoNumber);
                $stmt->execute();
                $result = $stmt->get_result();
                $response['appendixC'] = $result->fetch_assoc();
                $stmt->close();
            }
        }
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX F DATA (Practical Assessment Evaluation)
    // ══════════════════════════════════════════════════════════
    // Note: Appendix F workplace observation activities are hardcoded in the Flutter app
    // This ensures consistent data display and avoids database dependency issues
    $response['appendixF'] = null;
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX G DATA (Appeals Form)
    // ══════════════════════════════════════════════════════════
    $response['appendixG'] = null;
    $tableG = getTableName('g', $trade);
    if ($tableG) {
        $table_check = $conn->query("SHOW TABLES LIKE '".$conn->real_escape_string($tableG)."'");
        if ($table_check && $table_check->num_rows > 0) {
            $stmt = $conn->prepare("
                SELECT * FROM `".$conn->real_escape_string($tableG)."`
                WHERE learnerID = ? AND ofo_number = ?
                ORDER BY created_at DESC
                LIMIT 1
            ");
            if ($stmt) {
                $stmt->bind_param('is', $learnerID, $ofoNumber);
                $stmt->execute();
                $result = $stmt->get_result();
                $appendixG = $result->fetch_assoc();
                $stmt->close();
                
                if ($appendixG) {
                    // Secure signature handling - never expose file URLs
                    if (!empty($appendixG['candidate_signature'])) {
                        $appendixG['candidate_signature'] = loadSignatureSecurely($appendixG['candidate_signature']);
                    }
                    if (!empty($appendixG['assessor_signature'])) {
                        $appendixG['assessor_signature'] = loadSignatureSecurely($appendixG['assessor_signature']);
                    }
                }
                $response['appendixG'] = $appendixG;
            }
        }
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX I DATA (Statement of Results)
    // ══════════════════════════════════════════════════════════
    $response['appendixI'] = null;
    $tableI = getTableName('i', $trade);
    if ($tableI) {
        $table_check = $conn->query("SHOW TABLES LIKE '".$conn->real_escape_string($tableI)."'");
        if ($table_check && $table_check->num_rows > 0) {
            $stmt = $conn->prepare("
                SELECT * FROM `".$conn->real_escape_string($tableI)."`
                WHERE learnerID = ? AND ofo_number = ?
                LIMIT 1
            ");
            if ($stmt) {
                $stmt->bind_param('is', $learnerID, $ofoNumber);
                $stmt->execute();
                $result = $stmt->get_result();
                $response['appendixI'] = $result->fetch_assoc();
                $stmt->close();
            }
        }
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX J DATA (Pre-Assessment Agreement)
    // ══════════════════════════════════════════════════════════
    $response['appendixJ'] = null;
    $tableJ = getTableName('j', $trade);
    if ($tableJ) {
        $table_check = $conn->query("SHOW TABLES LIKE '".$conn->real_escape_string($tableJ)."'");
        if ($table_check && $table_check->num_rows > 0) {
            $stmt = $conn->prepare("
                SELECT * FROM `".$conn->real_escape_string($tableJ)."`
                WHERE learnerID = ? AND ofo_number = ?
                LIMIT 1
            ");
            if ($stmt) {
                $stmt->bind_param('is', $learnerID, $ofoNumber);
                $stmt->execute();
                $result = $stmt->get_result();
                $appendixJ = $result->fetch_assoc();
                $stmt->close();
                
                if ($appendixJ) {
                    // Secure signature handling - never expose file URLs
                    if (!empty($appendixJ['candidate_signature'])) {
                        $appendixJ['candidate_signature'] = loadSignatureSecurely($appendixJ['candidate_signature']);
                    }
                    if (!empty($appendixJ['witness_signature'])) {
                        $appendixJ['witness_signature'] = loadSignatureSecurely($appendixJ['witness_signature']);
                    }
                }
                $response['appendixJ'] = $appendixJ;
            }
        }
    }
    
    // Return success response
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'error_details' => $e->getTraceAsString()
    ]);
}
?>
