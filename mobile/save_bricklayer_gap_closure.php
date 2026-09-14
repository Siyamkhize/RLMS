<?php
/**
 * Save Bricklayer Gap Closure Recommendations
 * Saves selected unit standards, recommendation status, and candidate marks/score.
 * Auto-adds CandidateScore column to the access recommendation table if missing.
 *
 * Endpoint: POST mobile/save_bricklayer_gap_closure.php
 *
 * Request:
 * {
 *   "learnerID": 20286,
 *   "recommendations": [
 *     {"acrid": 1, "status": "Not Ready", "remarks": "...", "candidate_score": "85"},
 *     {"acrid": 2, "status": "Recommended", "remarks": "...", "candidate_score": "90"},
 *     {"acrid": 3, "status": "Recommended", "remarks": "...", "candidate_score": ""},
 *     {"acrid": 4, "status": "Recommended for Gap Closure", "remarks": "...", "candidate_score": ""}
 *   ],
 *   "selected_unit_standards": ["unit_id_1", "unit_id_2", ...],
 *   "ofo_code": "641201",
 *   "trade": "bricklayer"
 * }
 */

header('Content-Type: application/json');
require_once 'connection.php';

/** Ensure a column exists on a table – add it if missing. */
function ensure_column($conn, $table, $column, $definition) {
    $res = $conn->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
    if ($res && $res->num_rows === 0) {
        $conn->query("ALTER TABLE `$table` ADD COLUMN `$column` $definition");
    }
}

// Ensure CandidateScore (marks) column exists on the recommendation table
ensure_column($conn, 'arplbricklayer_access_recommendation', 'CandidateScore',
    "VARCHAR(50) DEFAULT '' AFTER Remarks");

try {
    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input || !isset($input['learnerID']) || !isset($input['recommendations'])) {
        throw new Exception('Missing required fields: learnerID, recommendations');
    }

    $learner_id = intval($input['learnerID']);
    $recommendations = $input['recommendations'];
    $selected_unit_standards = isset($input['selected_unit_standards']) ? $input['selected_unit_standards'] : [];
    $ofo_code = $input['ofo_code'] ?? '641201';
    $trade = $input['trade'] ?? 'bricklayer';

    if ($learner_id <= 0) {
        throw new Exception('Invalid learnerID');
    }

    // Robust column detection for unitstandard table
    $checkColumn = $conn->query("SHOW COLUMNS FROM unitstandard");
    $hasUnitStandardId = false;
    if ($checkColumn) {
        while ($col = $checkColumn->fetch_assoc()) {
            if ($col['Field'] === 'unit_standard_id') { $hasUnitStandardId = true; break; }
        }
    }
    $idColumn = $hasUnitStandardId ? 'unit_standard_id' : 'id';
    $DEFAULT_QUAL = 65409;

    $conn->begin_transaction();

    try {
        // STEP 1: DELETE EXISTING RECOMMENDATIONS FOR THIS LEARNER
        $delete_stmt = $conn->prepare("DELETE FROM arplbricklayer_access_recommendation WHERE LearnerID = ?");
        if (!$delete_stmt) throw new Exception('Database error: ' . $conn->error);
        $delete_stmt->bind_param('i', $learner_id);
        $delete_stmt->execute();
        $delete_stmt->close();

        // STEP 2: INSERT NEW RECOMMENDATIONS (including CandidateScore / marks)
        $insert_stmt = $conn->prepare("
            INSERT INTO arplbricklayer_access_recommendation
            (LearnerID, ACRID, Trade, OFOCode, Status, Remarks, CandidateScore)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        if (!$insert_stmt) throw new Exception('Database error: ' . $conn->error);

        $recommendation_id = null;
        $overall_result_status = null;

        foreach ($recommendations as $rec) {
            $acrid = intval($rec['acrid']);
            $status = $rec['status'] ?? '';
            $remarks = $rec['remarks'] ?? '';
            $cand_score = $rec['candidate_score'] ?? '';

            $insert_stmt->bind_param('iisssss', $learner_id, $acrid, $trade, $ofo_code, $status, $remarks, $cand_score);
            if (!$insert_stmt->execute()) {
                throw new Exception('Failed to insert recommendation: ' . $insert_stmt->error);
            }
            if ($acrid === 4) {
                $recommendation_id = $conn->insert_id;
                $overall_result_status = $status;
            }
        }
        $insert_stmt->close();

        // STEP 3: DELETE EXISTING GAP UNIT STANDARDS
        $delete_gap_stmt = $conn->prepare("
            DELETE FROM arplbricklayer_gap_unit_standards WHERE learner_id = ?
        ");
        if (!$delete_gap_stmt) throw new Exception('Database error: ' . $conn->error);
        $delete_gap_stmt->bind_param('i', $learner_id);
        $delete_gap_stmt->execute();
        $delete_gap_stmt->close();

        // STEP 4: INSERT SELECTED UNIT STANDARDS (only when Gap Closure is selected)
        $inserted_standards = 0;
        if ($overall_result_status === 'Recommended for Gap Closure' && !empty($selected_unit_standards)) {
            $placeholders = implode(',', array_fill(0, count($selected_unit_standards), '?'));
            $gap_stmt = $conn->prepare("
                INSERT INTO arplbricklayer_gap_unit_standards
                (learner_id, recommendation_id, unit_standard_id, unit_standard_name, qualification_id, ofo_code, assigned_date, status)
                SELECT
                    ? as learner_id,
                    ? as recommendation_id,
                    us.$idColumn,
                    us.unit_standard_name,
                    us.qualification_id,
                    ? as ofo_code,
                    CURDATE() as assigned_date,
                    'Pending' as status
                FROM unitstandard us
                WHERE us.$idColumn IN ($placeholders)
                AND us.qualification_id = $DEFAULT_QUAL
            ");
            if (!$gap_stmt) throw new Exception('Database error: ' . $conn->error);

            $param_types = 'ii' . str_repeat('s', count($selected_unit_standards) + 1);
            $params = [$learner_id, $recommendation_id, $ofo_code];
            $params = array_merge($params, $selected_unit_standards);
            $gap_stmt->bind_param($param_types, ...$params);

            if (!$gap_stmt->execute()) {
                throw new Exception('Failed to insert unit standards: ' . $gap_stmt->error);
            }
            $inserted_standards = $gap_stmt->affected_rows;
            $gap_stmt->close();
        }

        $conn->commit();

        http_response_code(200);
        echo json_encode([
            'status' => 'success',
            'message' => 'Bricklayer gap closure recommendations saved successfully',
            'learner_id' => $learner_id,
            'recommendation_id' => $recommendation_id,
            'overall_result_status' => $overall_result_status,
            'unit_standards_saved' => $inserted_standards,
            'id_column_used' => $idColumn,
            'qualification_id_used' => $DEFAULT_QUAL,
            'next_action' => $overall_result_status === 'Recommended for Gap Closure' ? 'gap_closure' : null
        ]);

    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
