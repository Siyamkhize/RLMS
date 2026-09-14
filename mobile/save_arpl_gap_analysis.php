<?php
/**
 * ARPL Endpoint: Save Gap Analysis Data (Appendix D)
 * Saves gap analysis findings and identified unit standards
 * Database: arpl_appendix_d, arpl_gap_analysis_unit_standards
 */

require_once 'connection.php';
header('Content-Type: application/json');

$response = [
    'status' => 'error',
    'message' => '',
    'gap_analysis_id' => null
];

try {
    $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : 0;
    $ofo_code = isset($_POST['ofo_code']) ? trim($_POST['ofo_code']) : '';
    
    if ($learnerID <= 0) {
        throw new Exception("Valid learnerID required");
    }
    
    // Handle unit standards if provided (from JSON in POST body)
    $unit_standards = [];
    if (isset($_POST['unit_standards'])) {
        $us_data = $_POST['unit_standards'];
        if (is_string($us_data)) {
            $unit_standards = json_decode($us_data, true) ?? [];
        } else {
            $unit_standards = $us_data;
        }
    }
    
    // Check if gap analysis exists
    $stmt = $conn->prepare("SELECT id FROM arpl_appendix_d WHERE learnerID = ? LIMIT 1");
    $stmt->bind_param("i", $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $exists = $result->num_rows > 0;
    $existing_id = $exists ? $result->fetch_assoc()['id'] : null;
    $stmt->close();
    
    if ($exists) {
        // UPDATE existing record
        $fields = [];
        $values = [];
        $types = '';
        
        foreach ($_POST as $key => $value) {
            if (!in_array($key, ['learnerID', 'ofo_code', 'unit_standards'])) {
                $fields[] = "$key = ?";
                $values[] = $value;
                $types .= is_numeric($value) && strpos($value, '.') === false ? 'i' : 's';
            }
        }
        
        $values[] = $learnerID;
        $types .= 'i';
        
        $sql = "UPDATE arpl_appendix_d SET " . implode(", ", $fields) . ", updated_at = NOW() WHERE learnerID = ?";
        $stmt = $conn->prepare($sql);
        
        if ($stmt) {
            $stmt->bind_param($types, ...$values);
            $stmt->execute();
            $stmt->close();
        } else {
            throw new Exception("Failed to update gap analysis: " . $conn->error);
        }
    } else {
        // INSERT new record
        $cols = ['learnerID', 'ofo_code'];
        $placeholders = ['?', '?'];
        $values = [$learnerID, $ofo_code];
        $types = 'is';
        
        foreach ($_POST as $key => $value) {
            if (!in_array($key, ['learnerID', 'ofo_code', 'unit_standards'])) {
                $cols[] = $key;
                $placeholders[] = '?';
                $values[] = $value;
                $types .= is_numeric($value) && strpos($value, '.') === false ? 'i' : 's';
            }
        }
        
        $sql = "INSERT INTO arpl_appendix_d (" . implode(", ", $cols) . ", created_at) VALUES (" . implode(", ", $placeholders) . ", NOW())";
        $stmt = $conn->prepare($sql);
        
        if ($stmt) {
            $stmt->bind_param($types, ...$values);
            $stmt->execute();
            $response['gap_analysis_id'] = $conn->insert_id;
            $existing_id = $conn->insert_id;
            $stmt->close();
        } else {
            throw new Exception("Failed to save gap analysis: " . $conn->error);
        }
    }
    
    // Save unit standards if provided
    if (!empty($unit_standards) && $existing_id) {
        // Clear existing unit standards for this learner
        $stmt = $conn->prepare("DELETE FROM arpl_gap_analysis_unit_standards WHERE learnerID = ?");
        $stmt->bind_param("i", $learnerID);
        $stmt->execute();
        $stmt->close();
        
        // Insert new unit standards
        $stmt = $conn->prepare("
            INSERT INTO arpl_gap_analysis_unit_standards 
            (learnerID, unit_standard_id, unit_standard_title, status, created_at) 
            VALUES (?, ?, ?, ?, NOW())
        ");
        
        foreach ($unit_standards as $us) {
            $us_id = $us['id'] ?? $us['unit_standard_id'] ?? null;
            $us_title = $us['title'] ?? $us['unit_standard_title'] ?? '';
            $us_status = $us['status'] ?? 'pending';
            
            if ($us_id) {
                $stmt->bind_param("isss", $learnerID, $us_id, $us_title, $us_status);
                $stmt->execute();
            }
        }
        $stmt->close();
    }
    
    $response['status'] = 'success';
    $response['message'] = 'Gap analysis saved successfully';
    $response['unit_standards_saved'] = count($unit_standards);

} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in save_arpl_gap_analysis.php: " . $e->getMessage());
}

echo json_encode($response);
?>
