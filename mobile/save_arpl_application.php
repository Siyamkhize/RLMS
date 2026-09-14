<?php
/**
 * ARPL Endpoint: Save Application Form Data (Appendix A)
 * Saves application form data to arpl_applications_v4
 */

require_once 'connection.php';
header('Content-Type: application/json');

$response = [
    'status' => 'error',
    'message' => '',
    'application_id' => null
];

try {
    $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : 0;
    $ofo_code = isset($_POST['ofo_code']) ? trim($_POST['ofo_code']) : '';
    
    if ($learnerID <= 0) {
        throw new Exception("Valid learnerID required");
    }
    
    // Get all other POST fields
    $fields = [];
    $placeholders = [];
    $values = [];
    $types = '';
    
    $fields['learnerID'] = $learnerID;
    $fields['ofo_code'] = $ofo_code;
    
    // Add any other fields from POST
    foreach ($_POST as $key => $value) {
        if (!in_array($key, ['learnerID', 'ofo_code'])) {
            $fields[$key] = $value;
        }
    }
    
    // Check if application exists
    $stmt = $conn->prepare("SELECT id FROM arpl_applications_v4 WHERE learnerID = ? LIMIT 1");
    $stmt->bind_param("i", $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    $exists = $result->num_rows > 0;
    $stmt->close();
    
    if ($exists) {
        // UPDATE existing record
        $setClauses = [];
        $types = '';
        $values = [];
        
        foreach ($fields as $key => $value) {
            if ($key !== 'learnerID') {
                $setClauses[] = "$key = ?";
                $values[] = $value;
                $types .= is_numeric($value) && strpos($value, '.') === false ? 'i' : 's';
            }
        }
        $values[] = $learnerID;
        $types .= 'i';
        
        $sql = "UPDATE arpl_applications_v4 SET " . implode(", ", $setClauses) . ", updated_at = NOW() WHERE learnerID = ?";
        $stmt = $conn->prepare($sql);
        if ($stmt) {
            $stmt->bind_param($types, ...$values);
            $stmt->execute();
            $stmt->close();
            $response['status'] = 'success';
            $response['message'] = 'Application form updated successfully';
        } else {
            throw new Exception("Failed to update application: " . $conn->error);
        }
    } else {
        // INSERT new record
        $cols = [];
        $placeholders = [];
        $types = '';
        $values = [];
        
        foreach ($fields as $key => $value) {
            $cols[] = $key;
            $placeholders[] = "?";
            $values[] = $value;
            $types .= is_numeric($value) && strpos($value, '.') === false ? 'i' : 's';
        }
        
        $sql = "INSERT INTO arpl_applications_v4 (" . implode(", ", $cols) . ", created_at) VALUES (" . implode(", ", $placeholders) . ", NOW())";
        $stmt = $conn->prepare($sql);
        if ($stmt) {
            $stmt->bind_param($types, ...$values);
            $stmt->execute();
            $response['application_id'] = $conn->insert_id;
            $stmt->close();
            $response['status'] = 'success';
            $response['message'] = 'Application form saved successfully';
        } else {
            throw new Exception("Failed to save application: " . $conn->error);
        }
    }

} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in save_arpl_application.php: " . $e->getMessage());
}

echo json_encode($response);
?>
