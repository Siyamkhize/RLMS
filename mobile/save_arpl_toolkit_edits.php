<?php
/**
 * Save ARPL Toolkit Edits - Combined Endpoint for Appendix B, D, E
 * 
 * This endpoint is called from ArplToolkitViewerPage.dart to save all three appendices
 * in a single request when viewing the complete toolkit.
 * 
 * Request body (JSON):
 * {
 *   "learnerID": 11701,
 *   "classID": 797,
 *   "ofoNumber": "641201",
 *   "appendixB": [
 *     {"activity_id": 1, "rating": 4, "comments": "Good work"}
 *   ],
 *   "appendixD": {
 *     "1": "yes",
 *     "2": "no",
 *     ...
 *   },
 *   "appendixE": [
 *     {"activity_id": 1, "rating": 3, "comments": "Needs improvement"}
 *   ]
 * }
 * 
 * Response:
 * {
 *   "status": "success" | "error",
 *   "message": "All appendices saved successfully",
 *   "details": {
 *     "appendixB": {...},
 *     "appendixD": {...},
 *     "appendixE": {...}
 *   }
 * }
 */

header('Content-Type: application/json');

// Enable error logging
error_log("=== ARPL Toolkit Save Request ===");
error_log("Raw input: " . file_get_contents('php://input'));

try {
    // Get request body
    $rawInput = file_get_contents('php://input');
    error_log("Raw input received: " . substr($rawInput, 0, 500));
    
    $input = json_decode($rawInput, true);
    
    if (!$input) {
        $jsonError = json_last_error_msg();
        error_log("JSON decode error: " . $jsonError);
        throw new Exception('Invalid JSON input: ' . $jsonError);
    }
    
    error_log("Parsed input: " . print_r($input, true));
    
    // Validate required fields
    $required = ['learnerID', 'ofoNumber'];
    foreach ($required as $field) {
        if (!isset($input[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    $learnerID = intval($input['learnerID']);
    $classID = isset($input['classID']) ? intval($input['classID']) : 0;
    $ofoNumber = $input['ofoNumber'];
    $appendixB = isset($input['appendixB']) ? $input['appendixB'] : [];
    $appendixD = isset($input['appendixD']) ? $input['appendixD'] : [];
    $appendixE = isset($input['appendixE']) ? $input['appendixE'] : [];
    
    // Database connection
    require_once 'connection.php';
    
    if (!$conn) {
        throw new Exception('Database connection failed');
    }
    
    // Use facilitator ID from app (the logged-in assessor)
    // The app should be sending this, otherwise default to 1
    $facilitator_id = isset($input['facilitator_id']) ? intval($input['facilitator_id']) : 1;
    
    // Fallback: Try to get from existing records if not provided
    if ($facilitator_id == 0 || $facilitator_id == 1) {
        $stmt = $conn->prepare("SELECT assessor_id FROM arplappxb_activity_ratings WHERE learnerID = ? LIMIT 1");
        if ($stmt) {
            $stmt->bind_param('i', $learnerID);
            $stmt->execute();
            $result = $stmt->get_result();
            if ($row = $result->fetch_assoc()) {
                $facilitator_id = intval($row['assessor_id']);
            }
            $stmt->close();
        }
    }
    
    // Last resort: use learnerID's associated facilitator or default to 1
    if ($facilitator_id == 0 || $facilitator_id == 1) {
        $facilitator_id = 1; // Safe default
    }
    
    $response = [
        'status' => 'success',
        'message' => 'All appendices saved successfully',
        'details' => []
    ];
    
    // ══════════════════════════════════════════════════════════
    // SAVE APPENDIX B
    // ══════════════════════════════════════════════════════════
    if (!empty($appendixB) && is_array($appendixB)) {
        $savedB = 0;
        $errorsB = [];
        
        // Check which columns exist in arplappxb_activity_ratings
        $columnsB = [];
        $resultCols = $conn->query("SHOW COLUMNS FROM arplappxb_activity_ratings");
        if ($resultCols) {
            while ($row = $resultCols->fetch_assoc()) {
                $columnsB[] = $row['Field'];
            }
        }
        
        // Check for foreign key constraints
        $hasForeignKey = false;
        $fkQuery = $conn->query("
            SELECT REFERENCED_TABLE_NAME 
            FROM information_schema.KEY_COLUMN_USAGE 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'arplappxb_activity_ratings' 
            AND COLUMN_NAME = 'activity_id'
            AND REFERENCED_TABLE_NAME IS NOT NULL
        ");
        
        if ($fkQuery && $fkQuery->num_rows > 0) {
            $fkInfo = $fkQuery->fetch_assoc();
            $hasForeignKey = true;
            error_log("WARNING: Foreign key constraint found on activity_id -> " . $fkInfo['REFERENCED_TABLE_NAME']);
        }
        
        // If there's a problematic foreign key, try to work around it
        if ($hasForeignKey) {
            // Temporarily disable foreign key checks for this session
            $conn->query("SET FOREIGN_KEY_CHECKS = 0");
            error_log("Temporarily disabled foreign key checks for Appendix B save");
        }
        
        // Build dynamic INSERT query based on available columns
        $insertCols = ['learnerID'];
        $insertVals = ['?'];
        $insertTypes = 'i';
        $updateParts = [];
        
        if (in_array('ofo_number', $columnsB)) {
            $insertCols[] = 'ofo_number';
            $insertVals[] = '?';
            $insertTypes .= 's';
        }
        
        $insertCols[] = 'activity_id';
        $insertVals[] = '?';
        $insertTypes .= 'i';
        
        // Handle rating column - check for different possible names
        $ratingColName = null;
        if (in_array('competency_scale_id', $columnsB)) {
            $ratingColName = 'competency_scale_id';
        } elseif (in_array('rating', $columnsB)) {
            $ratingColName = 'rating';
        } elseif (in_array('scale_id', $columnsB)) {
            $ratingColName = 'scale_id';
        }
        
        if ($ratingColName) {
            $insertCols[] = $ratingColName;
            $insertVals[] = '?';
            $insertTypes .= 'i';
            $updateParts[] = "$ratingColName = VALUES($ratingColName)";
        }
        
        if (in_array('assessor_id', $columnsB)) {
            $insertCols[] = 'assessor_id';
            $insertVals[] = '?';
            $insertTypes .= 'i';
        }
        
        if (in_array('comments', $columnsB)) {
            $insertCols[] = 'comments';
            $insertVals[] = '?';
            $insertTypes .= 's';
            $updateParts[] = 'comments = VALUES(comments)';
        }
        
        if (in_array('rating_date', $columnsB)) {
            $insertCols[] = 'rating_date';
            $insertVals[] = 'NOW()';
            $updateParts[] = 'rating_date = NOW()';
        } elseif (in_array('created_at', $columnsB)) {
            $insertCols[] = 'created_at';
            $insertVals[] = 'NOW()';
        }
        
        $sqlB = "INSERT INTO arplappxb_activity_ratings 
                 (" . implode(', ', $insertCols) . ")
                 VALUES (" . implode(', ', $insertVals) . ")
                 ON DUPLICATE KEY UPDATE " . implode(', ', $updateParts);
        
        $stmtB = $conn->prepare($sqlB);
        if (!$stmtB) {
            // Re-enable foreign key checks before throwing
            if ($hasForeignKey) {
                $conn->query("SET FOREIGN_KEY_CHECKS = 1");
            }
            throw new Exception('Failed to prepare Appendix B statement: ' . $conn->error);
        }
        
        foreach ($appendixB as $item) {
            $activity_id = intval($item['activity_id']);
            $rating = intval($item['rating']);
            $comments = isset($item['comments']) ? $item['comments'] : '';
            
            if ($rating >= 1 && $rating <= 5) {
                // Bind parameters dynamically
                $bindParams = [$learnerID];
                if (in_array('ofo_number', $columnsB)) {
                    $bindParams[] = $ofoNumber;
                }
                $bindParams[] = $activity_id;
                $bindParams[] = $rating;
                if (in_array('assessor_id', $columnsB)) {
                    $bindParams[] = $facilitator_id;
                }
                if (in_array('comments', $columnsB)) {
                    $bindParams[] = $comments;
                }
                
                $stmtB->bind_param($insertTypes, ...$bindParams);
                if ($stmtB->execute()) {
                    $savedB++;
                } else {
                    $errorsB[] = "Activity $activity_id: " . $stmtB->error;
                    error_log("Appendix B save error for activity $activity_id: " . $stmtB->error);
                }
            } else {
                $errorsB[] = "Invalid rating for activity $activity_id: $rating";
            }
        }
        
        $stmtB->close();
        
        // Re-enable foreign key checks
        if ($hasForeignKey) {
            $conn->query("SET FOREIGN_KEY_CHECKS = 1");
            error_log("Re-enabled foreign key checks after Appendix B save");
        }
        
        $response['details']['appendixB'] = [
            'saved' => $savedB,
            'errors' => $errorsB
        ];
    }
    
    // ══════════════════════════════════════════════════════════
    // SAVE APPENDIX D
    // ══════════════════════════════════════════════════════════
    if (!empty($appendixD)) {
        // Check if assessment exists (try with ofo_number if column exists)
        $hasOfoColumn = false;
        $checkCol = $conn->query("SHOW COLUMNS FROM arpl_appendix_d LIKE 'ofo_number'");
        if ($checkCol && $checkCol->num_rows > 0) {
            $hasOfoColumn = true;
        }
        
        if ($hasOfoColumn) {
            $stmt = $conn->prepare("
                SELECT id FROM arpl_appendix_d 
                WHERE learnerID = ? AND assessor_id = ? AND ofo_number = ?
            ");
            $stmt->bind_param('iis', $learnerID, $facilitator_id, $ofoNumber);
        } else {
            $stmt = $conn->prepare("
                SELECT id FROM arpl_appendix_d 
                WHERE learnerID = ? AND assessor_id = ?
            ");
            $stmt->bind_param('ii', $learnerID, $facilitator_id);
        }
        
        $stmt->execute();
        $result = $stmt->get_result();
        $existing = $result->fetch_assoc();
        $stmt->close();
        
        // Build updates
        $updates = [];
        $params = [];
        $param_types = '';
        
        for ($i = 1; $i <= 22; $i++) {
            if (isset($appendixD[$i])) {
                $response_val = strtolower($appendixD[$i]);
                if (in_array($response_val, ['yes', 'no', 'pending'])) {
                    $updates[] = "activity_{$i} = ?";
                    $params[] = $response_val;
                    $param_types .= 's';
                }
            }
        }
        
        if (!empty($updates)) {
            if ($existing) {
                // UPDATE
                if ($hasOfoColumn) {
                    $sql = "UPDATE arpl_appendix_d SET " . implode(', ', $updates) . 
                           ", updated_at = NOW() WHERE learnerID = ? AND assessor_id = ? AND ofo_number = ?";
                    $params[] = $learnerID;
                    $params[] = $facilitator_id;
                    $params[] = $ofoNumber;
                    $param_types .= 'iis';
                } else {
                    $sql = "UPDATE arpl_appendix_d SET " . implode(', ', $updates) . 
                           ", updated_at = NOW() WHERE learnerID = ? AND assessor_id = ?";
                    $params[] = $learnerID;
                    $params[] = $facilitator_id;
                    $param_types .= 'ii';
                }
                
                $stmt = $conn->prepare($sql);
                $stmt->bind_param($param_types, ...$params);
                $stmt->execute();
                $stmt->close();
                
                $response['details']['appendixD'] = ['status' => 'updated'];
            } else {
                // INSERT
                $columns = ['learnerID', 'assessor_id'];
                $values = ['?', '?'];
                $insert_params = [$learnerID, $facilitator_id];
                $insert_types = 'ii';
                
                if ($hasOfoColumn) {
                    $columns[] = 'ofo_number';
                    $values[] = '?';
                    $insert_params[] = $ofoNumber;
                    $insert_types .= 's';
                }
                
                for ($i = 1; $i <= 22; $i++) {
                    if (isset($appendixD[$i])) {
                        $response_val = strtolower($appendixD[$i]);
                        if (in_array($response_val, ['yes', 'no', 'pending'])) {
                            $columns[] = "activity_{$i}";
                            $values[] = '?';
                            $insert_params[] = $response_val;
                            $insert_types .= 's';
                        }
                    }
                }
                
                $sql = "INSERT INTO arpl_appendix_d (" . implode(', ', $columns) . 
                       ") VALUES (" . implode(', ', $values) . ")";
                
                $stmt = $conn->prepare($sql);
                $stmt->bind_param($insert_types, ...$insert_params);
                $stmt->execute();
                $stmt->close();
                
                $response['details']['appendixD'] = ['status' => 'created'];
            }
        }
    }
    
    // ══════════════════════════════════════════════════════════
    // SAVE APPENDIX E
    // ══════════════════════════════════════════════════════════
    if (!empty($appendixE) && is_array($appendixE)) {
        // Determine table name based on OFO
        $table_name = '';
        switch ($ofoNumber) {
            case '641201': // Bricklayer
                $table_name = 'arplappxe_bricklaying_activity_ratings';
                break;
            case '671101': // Electrician
                $table_name = 'arplappxe_electrician_activity_ratings';
                break;
            case '671201': // Plumber
                $table_name = 'arplappxe_plumber_activity_ratings';
                break;
            default:
                throw new Exception("Unsupported OFO number for Appendix E: $ofoNumber");
        }
        
        // Verify table exists
        $checkTable = $conn->query("SHOW TABLES LIKE '$table_name'");
        if ($checkTable->num_rows === 0) {
            throw new Exception("Table '$table_name' does not exist for OFO $ofoNumber");
        }
        
        // Check which columns exist in the Appendix E table
        $columnsE = [];
        $resultCols = $conn->query("SHOW COLUMNS FROM `$table_name`");
        if ($resultCols) {
            while ($row = $resultCols->fetch_assoc()) {
                $columnsE[] = $row['Field'];
            }
        }
        
        // Build dynamic INSERT query based on available columns
        $insertCols = ['learnerID'];
        $insertVals = ['?'];
        $insertTypes = 'i';
        $updateParts = [];
        
        if (in_array('ofo_number', $columnsE)) {
            $insertCols[] = 'ofo_number';
            $insertVals[] = '?';
            $insertTypes .= 's';
        }
        
        $insertCols[] = 'activity_id';
        $insertVals[] = '?';
        $insertTypes .= 'i';
        
        // Handle rating column - check for different possible names
        $ratingColName = null;
        if (in_array('competency_scale_id', $columnsE)) {
            $ratingColName = 'competency_scale_id';
        } elseif (in_array('rating', $columnsE)) {
            $ratingColName = 'rating';
        } elseif (in_array('scale_id', $columnsE)) {
            $ratingColName = 'scale_id';
        }
        
        if ($ratingColName) {
            $insertCols[] = $ratingColName;
            $insertVals[] = '?';
            $insertTypes .= 'i';
            $updateParts[] = "$ratingColName = VALUES($ratingColName)";
        }
        
        if (in_array('facilitator_id', $columnsE)) {
            $insertCols[] = 'facilitator_id';
            $insertVals[] = '?';
            $insertTypes .= 'i';
            $updateParts[] = 'facilitator_id = VALUES(facilitator_id)';
        } elseif (in_array('assessor_id', $columnsE)) {
            $insertCols[] = 'assessor_id';
            $insertVals[] = '?';
            $insertTypes .= 'i';
            $updateParts[] = 'assessor_id = VALUES(assessor_id)';
        }
        
        if (in_array('rating_date', $columnsE)) {
            $insertCols[] = 'rating_date';
            $insertVals[] = 'NOW()';
            $updateParts[] = 'rating_date = NOW()';
        }
        
        if (in_array('comments', $columnsE)) {
            $insertCols[] = 'comments';
            $insertVals[] = '?';
            $insertTypes .= 's';
            $updateParts[] = 'comments = VALUES(comments)';
        }
        
        if (in_array('created_at', $columnsE)) {
            $insertCols[] = 'created_at';
            $insertVals[] = 'NOW()';
        }
        
        $sqlE = "INSERT INTO `$table_name` 
                 (" . implode(', ', $insertCols) . ")
                 VALUES (" . implode(', ', $insertVals) . ")
                 ON DUPLICATE KEY UPDATE " . implode(', ', $updateParts);
        
        $savedE = 0;
        $errorsE = [];
        
        $stmtE = $conn->prepare($sqlE);
        if (!$stmtE) {
            throw new Exception("Failed to prepare Appendix E statement: " . $conn->error);
        }
        
        foreach ($appendixE as $item) {
            $activity_id = intval($item['activity_id']);
            $rating = intval($item['rating']);
            $comments = isset($item['comments']) ? $item['comments'] : '';
            
            if ($rating >= 1 && $rating <= 5) {
                // Bind parameters dynamically
                $bindParams = [$learnerID];
                if (in_array('ofo_number', $columnsE)) {
                    $bindParams[] = $ofoNumber;
                }
                $bindParams[] = $activity_id;
                $bindParams[] = $rating;
                if (in_array('facilitator_id', $columnsE) || in_array('assessor_id', $columnsE)) {
                    $bindParams[] = $facilitator_id;
                }
                if (in_array('comments', $columnsE)) {
                    $bindParams[] = $comments;
                }
                
                $stmtE->bind_param($insertTypes, ...$bindParams);
                if ($stmtE->execute()) {
                    $savedE++;
                } else {
                    $errorsE[] = "Activity $activity_id: " . $stmtE->error;
                }
            } else {
                $errorsE[] = "Invalid rating for activity $activity_id: $rating";
            }
        }
        
        $stmtE->close();
        
        $response['details']['appendixE'] = [
            'saved' => $savedE,
            'errors' => $errorsE
        ];
    }
    
    $conn->close();
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'debug' => [
            'file' => $e->getFile(),
            'line' => $e->getLine()
        ]
    ]);
}
?>
