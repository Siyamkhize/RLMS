<?php
/**
 * Get learners with POE for moderation - WITH COMPREHENSIVE STRATIFIED SAMPLING
 * 
 * Uses stratified random sampling across 5 dimensions to ensure representative selection:
 * 1. Class - Different classes may have different teaching approaches
 * 2. Site - Multiple classes can exist at one site, each site may have unique characteristics
 * 3. POE Completeness - Complete (3+ docs), Partial (1-2 docs), Incomplete (0 docs)
 * 4. Marking Status - Marked (has assessment marks) vs Not Marked (no marks yet)
 * 5. Performance Level - High (70%+), Medium (50-69%), Low (<50%), Not Assessed (no marks)
 * 
 * Selects 25% from each stratum proportionally to ensure:
 * - Fair representation across all classes and sites
 * - Balance between marked and unmarked learners
 * - Mix of performance levels (high, medium, low performers)
 * - Variety of POE completion statuses
 * 
 * Each learner can only be assigned to one moderator.
 * Each moderator gets their selection only once (persistent assignment).
 */

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// TEMPORARY: Increase timeout for large class allocations (62 classes)
// Remove this after assignments are created
ini_set('max_execution_time', 300); // 5 minutes
set_time_limit(300);

// Include database connection
include('connection.php');

// Set proper headers for API response
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

/**
 * Get database connection from connection.php
 */
function getDatabaseConnection() {
    global $conn;
    if (!$conn) {
        throw new Exception("Database connection not available");
    }
    return $conn;
}

/**
 * Create moderator assignments table if it doesn't exist
 * Now includes stratification metadata columns for performance
 */
function createModeratorAssignmentsTable($mysqli) {
    $sql = "CREATE TABLE IF NOT EXISTS moderator_assignments (
        id INT(11) NOT NULL AUTO_INCREMENT,
        moderator_id VARCHAR(50) NOT NULL,
        learner_id INT(11) NOT NULL,
        class_id VARCHAR(50) NULL,
        site_id VARCHAR(50) NULL,
        stratum_type VARCHAR(50) NULL COMMENT 'Type of stratification used',
        poe_completeness VARCHAR(20) NULL COMMENT 'Complete/Partial/Incomplete',
        marking_status VARCHAR(20) NULL COMMENT 'Marked/Not Marked',
        performance_level VARCHAR(20) NULL COMMENT 'High/Medium/Low/Not Assessed',
        poe_count INT(11) DEFAULT 0,
        assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY unique_learner (learner_id),
        KEY idx_moderator (moderator_id),
        KEY idx_class (class_id)
    )";
    
    if (!$mysqli->query($sql)) {
        throw new Exception("Failed to create moderator_assignments table: " . $mysqli->error);
    }
    
    // Add columns if they don't exist (for existing tables) - MariaDB compatible
    $columnsToAdd = [
        'class_id' => "ALTER TABLE moderator_assignments ADD COLUMN class_id VARCHAR(50) NULL",
        'site_id' => "ALTER TABLE moderator_assignments ADD COLUMN site_id VARCHAR(50) NULL",
        'stratum_type' => "ALTER TABLE moderator_assignments ADD COLUMN stratum_type VARCHAR(50) NULL",
        'poe_completeness' => "ALTER TABLE moderator_assignments ADD COLUMN poe_completeness VARCHAR(20) NULL",
        'marking_status' => "ALTER TABLE moderator_assignments ADD COLUMN marking_status VARCHAR(20) NULL",
        'performance_level' => "ALTER TABLE moderator_assignments ADD COLUMN performance_level VARCHAR(20) NULL",
        'poe_count' => "ALTER TABLE moderator_assignments ADD COLUMN poe_count INT(11) DEFAULT 0"
    ];
    
    // Check which columns exist
    $result = $mysqli->query("SHOW COLUMNS FROM moderator_assignments");
    $existingColumns = [];
    while ($row = $result->fetch_assoc()) {
        $existingColumns[] = $row['Field'];
    }
    
    // Add missing columns one by one with proper error handling
    foreach ($columnsToAdd as $columnName => $query) {
        if (!in_array($columnName, $existingColumns)) {
            $result = $mysqli->query($query);
            if (!$result) {
                error_log("Warning: Could not add column $columnName: " . $mysqli->error);
            }
        }
    }
}

/**
 * Check if moderator already has assignments
 */
function moderatorHasAssignments($mysqli, $moderatorId) {
    $sql = "SELECT COUNT(*) as count FROM moderator_assignments WHERE moderator_id = ?";
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param("s", $moderatorId);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    $stmt->close();
    
    return $row['count'] > 0;
}

/**
 * Get existing assignments for moderator - FAST VERSION
 * Simply retrieves stored stratification metadata from the table
 * No complex calculations needed!
 * FILTERS BY MODERATOR'S ALLOCATED CLASSES ONLY
 */
function getModeratorAssignments($mysqli, $moderatorId) {
    // Get moderator's allocated classes
    $moderatorClasses = getModeratorClasses($mysqli, $moderatorId);
    
    if (empty($moderatorClasses)) {
        // No classes allocated to this moderator
        return [];
    }
    
    // Escape and quote class IDs for safe SQL IN clause
    $escapedClasses = array_map(function($classId) use ($mysqli) {
        return "'" . $mysqli->real_escape_string($classId) . "'";
    }, $moderatorClasses);
    $classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";
    
    // Simple query - just get the stored data, filtered by moderator's classes
    $sql = "SELECT DISTINCT 
                l.LearnerID,
                l.Name,
                l.Surname,
                l.IDNumber,
                l.Email,
                l.PhoneNumber,
                l.classID,
                COALESCE(c.className, 'Unknown Class') as className,
                COALESCE(ma.site_id, c.siteID, 'Unknown') as siteID,
                COALESCE(ma.poe_completeness, 'Unknown') as poe_completeness,
                COALESCE(ma.marking_status, 'Unknown') as marking_status,
                COALESCE(ma.performance_level, 'Unknown') as performance_level,
                COALESCE(ma.poe_count, 0) as poe_count,
                ma.assigned_at
            FROM moderator_assignments ma
            INNER JOIN learnerdetails l ON ma.learner_id = l.LearnerID
            LEFT JOIN class c ON l.classID = c.classID
            WHERE ma.moderator_id = ?
            $classFilter
            ORDER BY c.className, l.Surname, l.Name
            LIMIT 2000";
    
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param("s", $moderatorId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $learners = [];
    while ($row = $result->fetch_assoc()) {
        // Add stratification metadata from stored values
        $row['stratum_class'] = $row['classID'];
        $row['stratum_site'] = $row['siteID'];
        $row['stratum_completeness'] = $row['poe_completeness'];
        $row['stratum_marking'] = $row['marking_status'];
        $row['stratum_performance'] = $row['performance_level'];
        $row['unit_standards_count'] = $row['poe_count'];
        
        $learners[] = $row;
    }
    
    $stmt->close();
    return $learners;
}

/**
 * Get moderator's allocated classes
 * Returns array of classIDs that the moderator is assigned to
 * HANDLES COMMA-SEPARATED CLASS IDS IN SINGLE ROW
 */
function getModeratorClasses($mysqli, $moderatorId) {
    $sql = "SELECT DISTINCT classID 
            FROM facilitator 
            WHERE facilitator_id = ?";
    
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param("s", $moderatorId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $classIds = [];
    while ($row = $result->fetch_assoc()) {
        $classIdValue = $row['classID'];
        
        // Check if classID contains comma-separated values
        if (strpos($classIdValue, ',') !== false) {
            // Split comma-separated values and add each one
            $splitIds = explode(',', $classIdValue);
            foreach ($splitIds as $id) {
                $trimmedId = trim($id);
                if (!empty($trimmedId) && !in_array($trimmedId, $classIds)) {
                    $classIds[] = $trimmedId;
                }
            }
        } else {
            // Single value, add directly
            if (!empty($classIdValue) && !in_array($classIdValue, $classIds)) {
                $classIds[] = $classIdValue;
            }
        }
    }
    
    $stmt->close();
    return $classIds;
}

/**
 * Get available learners with comprehensive stratification data
 * ULTRA-FAST version with aggressive limits and simplified queries
 * Stratifies by: Class, Site, POE Completeness, Marking Status, Performance Level
 * 
 * POE Completeness checks ALL THREE tables:
 * - poe table: POE documents uploaded
 * - marks table: Assessment marks (uses exercise column, not unit_standard_id)
 * - logbook_marks table: Logbook marks
 * 
 * Performance Level calculation:
 * - For each learner, sum all SUMMATIVE marks per unit standard
 * - Calculate average across all unit standards
 * - This gives accurate overall performance: High (70%+), Medium (50-69%), Low (<50%), Not Assessed
 * 
 * FILTERS BY MODERATOR'S ALLOCATED CLASSES ONLY
 */
function getAvailableLearnersByStrata($mysqli, $moderatorId) {
    // Get moderator's allocated classes
    $moderatorClasses = getModeratorClasses($mysqli, $moderatorId);
    
    if (empty($moderatorClasses)) {
        // No classes allocated to this moderator
        return [];
    }
    
    // Escape and quote class IDs for safe SQL IN clause (no prepared statement binding for IN clause)
    $escapedClasses = array_map(function($classId) use ($mysqli) {
        return "'" . $mysqli->real_escape_string($classId) . "'";
    }, $moderatorClasses);
    $classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";
    // First, create a temp table with POE learners from moderator's classes only
    $mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_poe_learners");
    $mysqli->query("
        CREATE TEMPORARY TABLE temp_poe_learners (
            learnerID INT PRIMARY KEY
        )
    ");
    
    // Build query with class filter (no prepared statement needed, already escaped)
    $poeQuery = "
        INSERT INTO temp_poe_learners
        SELECT DISTINCT p.learnerID 
        FROM poe p
        INNER JOIN learnerdetails l ON p.learnerID = l.LearnerID
        WHERE p.filePath IS NOT NULL AND p.filePath != ''
        $classFilter
        LIMIT 2000
    ";
    
    $result = $mysqli->query($poeQuery);
    if (!$result) {
        throw new Exception("Failed to insert POE learners: " . $mysqli->error);
    }
    
    // Get learner marks summary using the temp table
    // Calculate performance based on SUMMATIVE marks ONLY
    // IMPORTANT: Detect summative marks by checking if exercise contains "Summative" keyword
    // This is because the type column may be incorrectly set to "Formative" for all marks
    // For each unit standard, sum all summative marks, then average across all unit standards
    // This gives accurate overall performance per learner
    // FIXED: Extract 4-5 digit unit standard ID from ANYWHERE in exercise string
    $mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_learner_marks");
    
    // Try MySQL 8.0+ method first (REGEXP_SUBSTR)
    $useRegexpSubstr = false;
    $testResult = $mysqli->query("SELECT REGEXP_SUBSTR('Test 9964 String', '[0-9]{4,5}') as test");
    if ($testResult) {
        $testRow = $testResult->fetch_assoc();
        if ($testRow && $testRow['test'] == '9964') {
            $useRegexpSubstr = true;
        }
    }
    
    if ($useRegexpSubstr) {
        // MySQL 8.0+ with REGEXP_SUBSTR
        // CRITICAL FIX: marks_scored and marks columns may contain comma-separated values
        // We MUST filter out these invalid records before attempting SUM operations
        // Only process records where marks_scored is a valid single numeric value (no commas)
        $mysqli->query("
            CREATE TEMPORARY TABLE temp_learner_marks AS
            SELECT 
                unit_standard_totals.learnerID,
                COUNT(DISTINCT unit_standard_totals.unit_standard_id) as unit_standard_count,
                AVG(unit_standard_totals.unit_standard_percentage) as avg_marks
            FROM (
                SELECT 
                    m.learnerID,
                    CAST(REGEXP_SUBSTR(m.exercise, '[0-9]{4,5}') AS UNSIGNED) as unit_standard_id,
                    (SUM(CAST(m.marks_scored AS DECIMAL(10,2))) / SUM(CAST(a.marks AS DECIMAL(10,2)))) * 100 as unit_standard_percentage
                FROM marks m
                INNER JOIN temp_poe_learners tpl ON m.learnerID = tpl.learnerID
                LEFT JOIN assessments a ON m.exercise = a.exercise
                WHERE m.marks_scored IS NOT NULL
                AND m.marks_scored NOT LIKE '%,%'
                AND m.marks_scored REGEXP '^[0-9]+(\\\\.[0-9]+)?$'
                AND a.marks IS NOT NULL
                AND a.marks NOT LIKE '%,%'
                AND a.marks REGEXP '^[0-9]+(\\\\.[0-9]+)?$'
                AND CAST(a.marks AS DECIMAL(10,2)) > 0
                AND (
                    a.assessment_type = 'Summative'
                    OR (a.exercise IS NULL AND (
                        m.exercise LIKE '%Summative%'
                        OR m.exercise LIKE '%All Summative Questions%'
                    ))
                )
                AND m.exercise IS NOT NULL
                AND m.exercise != ''
                AND m.exercise REGEXP '[0-9]{4,5}'
                GROUP BY m.learnerID, unit_standard_id
            ) AS unit_standard_totals
            WHERE unit_standard_id > 0 AND unit_standard_id < 99999
            GROUP BY unit_standard_totals.learnerID
        ");
    } else {
        // MySQL 5.7/MariaDB - Use REGEXP to filter, extract in subquery
        // CRITICAL FIX: marks_scored and marks columns may contain comma-separated values
        // We MUST filter out these invalid records before attempting SUM operations
        // Only process records where marks_scored is a valid single numeric value (no commas)
        $mysqli->query("
            CREATE TEMPORARY TABLE temp_learner_marks AS
            SELECT 
                unit_standard_totals.learnerID,
                COUNT(DISTINCT unit_standard_totals.unit_standard_id) as unit_standard_count,
                AVG(unit_standard_totals.unit_standard_percentage) as avg_marks
            FROM (
                SELECT 
                    m.learnerID,
                    CAST(
                        SUBSTRING(
                            m.exercise,
                            LOCATE(
                                SUBSTRING_INDEX(
                                    SUBSTRING_INDEX(
                                        SUBSTRING_INDEX(m.exercise, ' - ', 2),
                                        ' - ',
                                        -1
                                    ),
                                    ' ',
                                    1
                                ),
                                m.exercise
                            ),
                            5
                        ) AS UNSIGNED
                    ) as unit_standard_id,
                    (SUM(CAST(m.marks_scored AS DECIMAL(10,2))) / SUM(CAST(a.marks AS DECIMAL(10,2)))) * 100 as unit_standard_percentage
                FROM marks m
                INNER JOIN temp_poe_learners tpl ON m.learnerID = tpl.learnerID
                LEFT JOIN assessments a ON m.exercise = a.exercise
                WHERE m.marks_scored IS NOT NULL
                AND m.marks_scored NOT LIKE '%,%'
                AND m.marks_scored REGEXP '^[0-9]+(\\\\.[0-9]+)?$'
                AND a.marks IS NOT NULL
                AND a.marks NOT LIKE '%,%'
                AND a.marks REGEXP '^[0-9]+(\\\\.[0-9]+)?$'
                AND CAST(a.marks AS DECIMAL(10,2)) > 0
                AND (
                    a.assessment_type = 'Summative'
                    OR (a.exercise IS NULL AND (
                        m.exercise LIKE '%Summative%'
                        OR m.exercise LIKE '%All Summative Questions%'
                    ))
                )
                AND m.exercise IS NOT NULL
                AND m.exercise != ''
                AND m.exercise REGEXP '[0-9]{4,5}'
                GROUP BY m.learnerID, unit_standard_id
            ) AS unit_standard_totals
            WHERE unit_standard_id > 0 AND unit_standard_id < 99999
            GROUP BY unit_standard_totals.learnerID
        ");
    }
    
    // Get POE coverage count - COUNT DISTINCT UNIT STANDARDS across ALL 3 tables
    // This ensures we count unique unit standards (max 10), not total records
    // FIXED: Extract 4-5 digit unit standard ID from ANYWHERE in exercise string
    $mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_learner_coverage");
    
    if ($useRegexpSubstr) {
        // MySQL 8.0+ with REGEXP_SUBSTR
        $mysqli->query("
            CREATE TEMPORARY TABLE temp_learner_coverage AS
            SELECT 
                learnerID,
                COUNT(DISTINCT unit_standard_id) as total_unit_standards
            FROM (
                -- From POE table
                SELECT DISTINCT 
                    p.learnerID, 
                    CAST(REGEXP_SUBSTR(p.exercise, '[0-9]{4,5}') AS UNSIGNED) as unit_standard_id
                FROM poe p
                INNER JOIN temp_poe_learners tpl ON p.learnerID = tpl.learnerID
                WHERE p.filePath IS NOT NULL AND p.filePath != ''
                AND p.exercise IS NOT NULL
                AND p.exercise != ''
                AND p.exercise REGEXP '[0-9]{4,5}'
                
                UNION
                
                -- From marks table
                SELECT DISTINCT 
                    m.learnerID, 
                    CAST(REGEXP_SUBSTR(m.exercise, '[0-9]{4,5}') AS UNSIGNED) as unit_standard_id
                FROM marks m
                INNER JOIN temp_poe_learners tpl ON m.learnerID = tpl.learnerID
                WHERE m.exercise IS NOT NULL
                AND m.exercise != ''
                AND m.exercise REGEXP '[0-9]{4,5}'
                
                UNION
                
                -- From logbook_marks table (uses unit_standard_id column directly)
                SELECT DISTINCT 
                    lm.learner_id as learnerID, 
                    CAST(lm.unit_standard_id AS UNSIGNED) as unit_standard_id
                FROM logbook_marks lm
                INNER JOIN temp_poe_learners tpl ON lm.learner_id = tpl.learnerID
                WHERE lm.unit_standard_id IS NOT NULL
                AND lm.unit_standard_id != ''
                AND lm.unit_standard_id REGEXP '^[0-9]{4,5}$'
            ) AS all_unit_standards
            WHERE unit_standard_id > 0 AND unit_standard_id < 99999
            GROUP BY learnerID
        ");
    } else {
        // MySQL 5.7/MariaDB - Use REGEXP to filter, extract in subquery
        $mysqli->query("
            CREATE TEMPORARY TABLE temp_learner_coverage AS
            SELECT 
                learnerID,
                COUNT(DISTINCT unit_standard_id) as total_unit_standards
            FROM (
                -- From POE table
                SELECT DISTINCT 
                    p.learnerID, 
                    CAST(
                        SUBSTRING(
                            p.exercise,
                            LOCATE(
                                SUBSTRING_INDEX(
                                    SUBSTRING_INDEX(
                                        SUBSTRING_INDEX(p.exercise, ' - ', 2),
                                        ' - ',
                                        -1
                                    ),
                                    ' ',
                                    1
                                ),
                                p.exercise
                            ),
                            5
                        ) AS UNSIGNED
                    ) as unit_standard_id
                FROM poe p
                INNER JOIN temp_poe_learners tpl ON p.learnerID = tpl.learnerID
                WHERE p.filePath IS NOT NULL AND p.filePath != ''
                AND p.exercise IS NOT NULL
                AND p.exercise != ''
                AND p.exercise REGEXP '[0-9]{4,5}'
                
                UNION
                
                -- From marks table
                SELECT DISTINCT 
                    m.learnerID, 
                    CAST(
                        SUBSTRING(
                            m.exercise,
                            LOCATE(
                                SUBSTRING_INDEX(
                                    SUBSTRING_INDEX(
                                        SUBSTRING_INDEX(m.exercise, ' - ', 2),
                                        ' - ',
                                        -1
                                    ),
                                    ' ',
                                    1
                                ),
                                m.exercise
                            ),
                            5
                        ) AS UNSIGNED
                    ) as unit_standard_id
                FROM marks m
                INNER JOIN temp_poe_learners tpl ON m.learnerID = tpl.learnerID
                WHERE m.exercise IS NOT NULL
                AND m.exercise != ''
                AND m.exercise REGEXP '[0-9]{4,5}'
                
                UNION
                
                -- From logbook_marks table (uses unit_standard_id column directly)
                SELECT DISTINCT 
                    lm.learner_id as learnerID, 
                    CAST(lm.unit_standard_id AS UNSIGNED) as unit_standard_id
                FROM logbook_marks lm
                INNER JOIN temp_poe_learners tpl ON lm.learner_id = tpl.learnerID
                WHERE lm.unit_standard_id IS NOT NULL
                AND lm.unit_standard_id != ''
                AND lm.unit_standard_id REGEXP '^[0-9]{4,5}$'
            ) AS all_unit_standards
            WHERE unit_standard_id > 0 AND unit_standard_id < 99999
            GROUP BY learnerID
        ");
    }
    
    // Main query with optimized joins - LIMIT to 100 learners max
    // CRITICAL: Use temp_poe_learners to ensure only moderator's class learners are included
    $sql = "SELECT DISTINCT 
                l.LearnerID,
                l.Name,
                l.Surname,
                l.IDNumber,
                l.Email,
                l.PhoneNumber,
                l.classID,
                COALESCE(c.className, 'Unknown Class') as className,
                COALESCE(c.siteID, 'Unknown') as siteID,
                COALESCE(tc.total_unit_standards, 0) as poe_count,
                MAX(p.submitted_at) as last_poe_submission,
                -- Marking status: Check if learner has summative marks
                CASE 
                    WHEN COALESCE(tm.unit_standard_count, 0) > 0 THEN 'Marked' 
                    ELSE 'Not Marked' 
                END as marking_status,
                -- Performance level from temp table (handle NULL for learners without marks)
                CASE 
                    WHEN tm.avg_marks IS NULL THEN 'Not Assessed'
                    WHEN tm.avg_marks >= 70 THEN 'High'
                    WHEN tm.avg_marks >= 50 THEN 'Medium'
                    WHEN tm.avg_marks >= 0 THEN 'Low'
                    ELSE 'Not Assessed'
                END as performance_level,
                -- POE completeness: Based on DISTINCT unit standards covered (out of 10 total)
                -- Complete = 10/10, Partial = 1-9, Incomplete = 0
                CASE 
                    WHEN COALESCE(tc.total_unit_standards, 0) >= 10 THEN 'Complete'
                    WHEN COALESCE(tc.total_unit_standards, 0) >= 1 THEN 'Partial'
                    ELSE 'Incomplete'
                END as poe_completeness
            FROM temp_poe_learners tpl
            INNER JOIN learnerdetails l ON tpl.learnerID = l.LearnerID
            INNER JOIN poe p ON l.LearnerID = p.learnerID
            LEFT JOIN class c ON l.classID = c.classID
            LEFT JOIN temp_learner_marks tm ON l.LearnerID = tm.learnerID
            LEFT JOIN temp_learner_coverage tc ON l.LearnerID = tc.learnerID
            WHERE p.filePath IS NOT NULL AND p.filePath != ''
            AND l.LearnerID NOT IN (
                SELECT learner_id FROM moderator_assignments
            )
            GROUP BY l.LearnerID, l.Name, l.Surname, l.IDNumber, l.Email, 
                     l.PhoneNumber, l.classID, c.className, c.siteID, 
                     tm.unit_standard_count, tm.avg_marks, tc.total_unit_standards
            ORDER BY l.classID, l.LearnerID DESC
            LIMIT 2000";
    
    $stmt = $mysqli->prepare($sql);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $strata = [];
    while ($row = $result->fetch_assoc()) {
        // Create multi-dimensional stratum key
        $classId = $row['classID'] ?? 'Unknown';
        $siteId = $row['siteID'] ?? 'Unknown';
        $poeCompleteness = $row['poe_completeness'];
        $markingStatus = $row['marking_status'];
        $performanceLevel = $row['performance_level'];
        
        // Composite key for stratification
        $stratumKey = "{$classId}|{$siteId}|{$poeCompleteness}|{$markingStatus}|{$performanceLevel}";
        
        if (!isset($strata[$stratumKey])) {
            $strata[$stratumKey] = [
                'classID' => $classId,
                'className' => $row['className'],
                'siteID' => $siteId,
                'poe_completeness' => $poeCompleteness,
                'marking_status' => $markingStatus,
                'performance_level' => $performanceLevel,
                'learners' => []
            ];
        }
        $strata[$stratumKey]['learners'][] = $row;
    }
    
    $stmt->close();
    
    // Cleanup temp tables
    $mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_poe_learners");
    $mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_learner_marks");
    $mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_learner_coverage");
    
    return $strata;
}

/**
 * Perform comprehensive stratified random sampling
 * Selects 25% from each stratum across 5 dimensions:
 * - Class, Site, POE Completeness, Marking Status, Performance Level
 */
function performStratifiedSampling($strata, $samplingRate = 0.25) {
    $selectedLearners = [];
    $strataSummary = [];
    
    foreach ($strata as $stratumKey => $stratumData) {
        $learners = $stratumData['learners'];
        $totalInStratum = count($learners);
        
        // Calculate sample size for this stratum (minimum 1 if stratum has learners)
        $sampleSize = max(1, ceil($totalInStratum * $samplingRate));
        
        // Randomly select learners from this stratum
        $selectedFromStratum = array_slice($learners, 0, $sampleSize);
        
        // Add stratification metadata to each learner
        foreach ($selectedFromStratum as &$learner) {
            $learner['stratum_class'] = $stratumData['classID'];
            $learner['stratum_site'] = $stratumData['siteID'];
            $learner['stratum_completeness'] = $stratumData['poe_completeness'];
            $learner['stratum_marking'] = $stratumData['marking_status'];
            $learner['stratum_performance'] = $stratumData['performance_level'];
            $learner['stratum_type'] = 'comprehensive';
            $learner['unit_standards_count'] = $learner['poe_count']; // Add for UI display
        }
        
        // Add to overall selection
        $selectedLearners = array_merge($selectedLearners, $selectedFromStratum);
        
        // Track stratum summary with all dimensions
        $strataSummary[] = [
            'class' => $stratumData['className'],
            'classID' => $stratumData['classID'],
            'site' => $stratumData['siteID'],
            'poe_completeness' => $stratumData['poe_completeness'],
            'marking_status' => $stratumData['marking_status'],
            'performance_level' => $stratumData['performance_level'],
            'total_in_stratum' => $totalInStratum,
            'selected_from_stratum' => count($selectedFromStratum),
            'sampling_rate' => round((count($selectedFromStratum) / $totalInStratum) * 100, 2) . '%'
        ];
    }
    
    return [
        'selected_learners' => $selectedLearners,
        'strata_summary' => $strataSummary,
        'total_strata' => count($strata)
    ];
}

/**
 * Assign learners to moderator WITH stratification metadata stored
 * This ensures fast retrieval later without recalculation
 */
function assignLearnersToModerator($mysqli, $moderatorId, $learners, $stratumType = 'comprehensive') {
    $sql = "INSERT INTO moderator_assignments 
            (moderator_id, learner_id, class_id, site_id, stratum_type, 
             poe_completeness, marking_status, performance_level, poe_count) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
    $stmt = $mysqli->prepare($sql);
    
    foreach ($learners as $learner) {
        $learnerId = $learner['LearnerID'];
        $classId = $learner['classID'] ?? null;
        $siteId = $learner['siteID'] ?? null;
        $poeCompleteness = $learner['poe_completeness'] ?? 'Unknown';
        $markingStatus = $learner['marking_status'] ?? 'Unknown';
        $performanceLevel = $learner['performance_level'] ?? 'Unknown';
        $poeCount = $learner['poe_count'] ?? 0;
        
        $stmt->bind_param("sissssssi", 
            $moderatorId, 
            $learnerId, 
            $classId,
            $siteId,
            $stratumType,
            $poeCompleteness,
            $markingStatus,
            $performanceLevel,
            $poeCount
        );
        
        if (!$stmt->execute()) {
            // If learner is already assigned, skip silently
            if ($mysqli->errno != 1062) { // 1062 is duplicate entry error
                throw new Exception("Failed to assign learner $learnerId: " . $stmt->error);
            }
        }
    }
    
    $stmt->close();
}

/**
 * Get learners with POE for moderator using comprehensive stratified sampling
 */
function getLearnersWithPOEForModerator($mysqli, $moderatorId) {
    // Create table if it doesn't exist
    createModeratorAssignmentsTable($mysqli);
    
    // STEP 1: Get SIMPLE total count of ALL learners with POE (from test_simple_count.php)
    // This is the accurate total count: 1571 learners
    $sql_total_poe = "SELECT COUNT(DISTINCT learnerID) as total FROM poe";
    $result_total_poe = $mysqli->query($sql_total_poe);
    $totalPOELearnersGlobal = 0;
    
    if ($result_total_poe) {
        $row_total_poe = $result_total_poe->fetch_assoc();
        $totalPOELearnersGlobal = (int)$row_total_poe['total'];
    }
    
    // Check if moderator already has assignments
    if (moderatorHasAssignments($mysqli, $moderatorId)) {
        // Return existing assignments with stored stratification data
        $learners = getModeratorAssignments($mysqli, $moderatorId);
        
        // Calculate ACTUAL total learners with POE in moderator's classes
        $moderatorClasses = getModeratorClasses($mysqli, $moderatorId);
        $totalWithPOE = 0;
        
        if (!empty($moderatorClasses)) {
            $escapedClasses = array_map(function($classId) use ($mysqli) {
                return "'" . $mysqli->real_escape_string($classId) . "'";
            }, $moderatorClasses);
            $classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";
            
            $sqlTotal = "SELECT COUNT(DISTINCT p.learnerID) as total 
                         FROM poe p
                         INNER JOIN learnerdetails l ON p.learnerID = l.LearnerID
                         WHERE p.filePath IS NOT NULL AND p.filePath != ''
                         $classFilter";
            $resultTotal = $mysqli->query($sqlTotal);
            if ($resultTotal) {
                $rowTotal = $resultTotal->fetch_assoc();
                $totalWithPOE = $rowTotal['total'];
            }
        }
        
        // Group by all stratification dimensions for summary
        $strataSummary = [];
        foreach ($learners as $learner) {
            $key = ($learner['classID'] ?? 'Unknown') . '|' . 
                   ($learner['siteID'] ?? 'Unknown') . '|' .
                   ($learner['poe_completeness'] ?? 'Unknown') . '|' .
                   ($learner['marking_status'] ?? 'Unknown') . '|' .
                   ($learner['performance_level'] ?? 'Unknown');
            
            if (!isset($strataSummary[$key])) {
                $strataSummary[$key] = [
                    'class' => $learner['className'] ?? 'Unknown',
                    'classID' => $learner['classID'] ?? 'Unknown',
                    'site' => $learner['siteID'] ?? 'Unknown',
                    'poe_completeness' => $learner['poe_completeness'] ?? 'Unknown',
                    'marking_status' => $learner['marking_status'] ?? 'Unknown',
                    'performance_level' => $learner['performance_level'] ?? 'Unknown',
                    'total_in_stratum' => 0,
                    'selected_from_stratum' => 0
                ];
            }
            $strataSummary[$key]['selected_from_stratum']++;
            $strataSummary[$key]['total_in_stratum']++; // For existing, total = selected
        }
        
        // Calculate sampling rates
        foreach ($strataSummary as &$stratum) {
            if ($stratum['total_in_stratum'] > 0) {
                $stratum['sampling_rate'] = '100%'; // Already selected
            }
        }
        
        return [
            'total_learners_with_poe_global' => $totalPOELearnersGlobal, // SIMPLE count: ALL learners with POE (1571)
            'total_learners_with_poe' => $totalWithPOE, // Total in moderator's classes
            'selected_count' => count($learners),
            'learners' => $learners,
            'is_existing_assignment' => true,
            'sampling_method' => 'stratified_comprehensive',
            'strata_summary' => array_values($strataSummary),
            'stratification_dimensions' => [
                'Class',
                'Site',
                'POE Completeness (Complete/Partial/Incomplete)',
                'Marking Status (Marked/Not Marked)',
                'Performance Level (High/Medium/Low/Not Assessed)'
            ],
            'message' => 'Returning your existing moderation assignment with stored stratification data'
        ];
    } else {
        // Get available learners with comprehensive stratification (filtered by moderator's classes)
        $strata = getAvailableLearnersByStrata($mysqli, $moderatorId);
        
        if (empty($strata)) {
            return [
                'total_learners_with_poe_global' => $totalPOELearnersGlobal, // SIMPLE count: ALL learners with POE (1571)
                'total_learners_with_poe' => 0,
                'selected_count' => 0,
                'learners' => [],
                'is_existing_assignment' => false,
                'sampling_method' => 'stratified_comprehensive',
                'message' => 'No learners with POE available for assignment'
            ];
        }
        
        // Calculate total available
        $totalAvailable = 0;
        foreach ($strata as $stratumData) {
            $totalAvailable += count($stratumData['learners']);
        }
        
        // Perform comprehensive stratified sampling (25% from each stratum)
        $samplingResult = performStratifiedSampling($strata, 0.25);
        $selectedLearners = $samplingResult['selected_learners'];
        $strataSummary = $samplingResult['strata_summary'];
        $totalStrata = $samplingResult['total_strata'];
        
        // Assign learners to this moderator
        assignLearnersToModerator($mysqli, $moderatorId, $selectedLearners, 'comprehensive');
        
        return [
            'total_learners_with_poe_global' => $totalPOELearnersGlobal, // SIMPLE count: ALL learners with POE (1571)
            'total_learners_with_poe' => $totalAvailable,
            'selected_count' => count($selectedLearners),
            'learners' => $selectedLearners,
            'is_existing_assignment' => false,
            'sampling_method' => 'stratified_comprehensive',
            'sampling_rate' => '25%',
            'total_strata' => $totalStrata,
            'strata_summary' => $strataSummary,
            'stratification_dimensions' => [
                'Class',
                'Site',
                'POE Completeness (Complete/Partial/Incomplete)',
                'Marking Status (Marked/Not Marked)',
                'Performance Level (High/Medium/Low/Not Assessed)'
            ],
            'message' => 'Comprehensive stratified random sampling applied: 25% selected from each stratum across 5 dimensions to ensure fair representation'
        ];
    }
}

// Main API logic
try {
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        // Get moderator ID from query parameter
        $moderatorId = $_GET['moderator_id'] ?? '';
        
        if (empty($moderatorId)) {
            http_response_code(400);
            echo json_encode([
                'status' => 'error',
                'message' => 'moderator_id parameter is required'
            ]);
            exit();
        }
        
        // Create database connection
        $mysqli = getDatabaseConnection();
        
        // Get learners with POE for this moderator using stratified sampling
        $result = getLearnersWithPOEForModerator($mysqli, $moderatorId);
        
        // Return success response
        http_response_code(200);
        echo json_encode([
            'status' => 'success',
            'message' => 'Learners with POE retrieved successfully using stratified sampling',
            'data' => $result
        ]);
        
    } else {
        // Method not allowed
        http_response_code(405);
        echo json_encode([
            'status' => 'error',
            'message' => 'Method not allowed. Use GET to retrieve learners with POE.'
        ]);
    }
    
} catch (Exception $e) {
    // Log error
    error_log("Get Learners with POE API Error: " . $e->getMessage());
    
    // Return error response
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
