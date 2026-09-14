<?php
/**
 * Get Electrician Gap Closure Unit Standards
 * Fetches all unit standards for qualification 91761 (Electrician)
 * Electrician uses a DIFFERENT table: occupational_unit_standards (NOT unitstandard)
 * Used when assessor selects "Recommended for Gap Closure" in Appendix H
 *
 * Endpoint: POST mobile/get_electrician_gap_unit_standards.php
 *
 * Request:
 * {
 *   "learnerID": 20286,
 *   "qualification_id": 91761
 * }
 *
 * Response: Array of unit standards that can be selected for gap closure
 */

header('Content-Type: application/json');
include('connection.php');

try {
    $input = json_decode(file_get_contents('php://input'), true);

    $learnerID = isset($input['learnerID']) ? intval($input['learnerID']) : 0;
    $qualification_id = isset($input['qualification_id']) ? intval($input['qualification_id']) : 91761;

    if ($learnerID <= 0) {
        throw new Exception('Missing or invalid learnerID');
    }

    // ══════════════════════════════════════════════════════════
    // ELECTRICIAN = occupational_unit_standards table (DIFFERENT from brick/plumber)
    // Robust column detection: table may have 'unit_standard_id' or 'id'
    // ══════════════════════════════════════════════════════════
    $tableName = 'occupational_unit_standards';
    $checkColumn = $conn->query("SHOW COLUMNS FROM $tableName");
    $hasUnitStandardId = false;
    $hasId = false;
    if ($checkColumn) {
        while ($col = $checkColumn->fetch_assoc()) {
            if ($col['Field'] === 'unit_standard_id') $hasUnitStandardId = true;
            if ($col['Field'] === 'id') $hasId = true;
        }
    }
    $idColumn = $hasUnitStandardId ? 'unit_standard_id' : 'id';

    $stmt = $conn->prepare("
        SELECT
            $idColumn as unit_standard_id,
            unit_standard_name,
            credits,
            qualification_id
        FROM $tableName
        WHERE qualification_id = ?
        ORDER BY $idColumn ASC
    ");

    if (!$stmt) {
        throw new Exception('Database error: ' . $conn->error);
    }

    $stmt->bind_param('i', $qualification_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $unit_standards = [];

    while ($row = $result->fetch_assoc()) {
        $unit_standards[] = [
            'unit_standard_id' => $row['unit_standard_id'] ?? '',
            'unit_standard_name' => $row['unit_standard_name'] ?? '',
            'credits' => intval($row['credits'] ?? 0),
            'qualification_id' => intval($row['qualification_id'] ?? 0)
        ];
    }
    $stmt->close();

    // ══════════════════════════════════════════════════════════
    // GET ALREADY SELECTED UNIT STANDARDS FOR THIS LEARNER
    // ══════════════════════════════════════════════════════════
    $selected_standards = [];
    $stmt = $conn->prepare("
        SELECT unit_standard_id
        FROM arplelectrician_gap_unit_standards
        WHERE learner_id = ?
    ");

    if ($stmt) {
        $stmt->bind_param('i', $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();

        while ($row = $result->fetch_assoc()) {
            $selected_standards[] = $row['unit_standard_id'];
        }
        $stmt->close();
    }

    // ══════════════════════════════════════════════════════════
    // RETURN RESPONSE
    // ══════════════════════════════════════════════════════════
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'learnerID' => $learnerID,
        'qualification_id' => $qualification_id,
        'trade' => 'electrician',
        'ofo_code' => '671101',
        'table_used' => $tableName,
        'id_column_used' => $idColumn,
        'unit_standards' => $unit_standards,
        'selected_unit_standards' => $selected_standards,
        'total_available' => count($unit_standards),
        'total_selected' => count($selected_standards)
    ]);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
