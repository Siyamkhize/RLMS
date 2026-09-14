<?php
/**
 * Save ARPL Appendix A: Application Form
 * Endpoint: POST mobile/save_arpl_appendix_a.php
 * 
 * Handles employment history as JSON array
 */

header('Content-Type: application/json');
require_once '../connection.php';

try {
    // Read JSON input
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    // Get parameters
    $learnerID = isset($data['learnerID']) ? intval($data['learnerID']) : 0;
    $ofoNumber = isset($data['ofoNumber']) ? $data['ofoNumber'] : '';
    
    if ($learnerID <= 0 || empty($ofoNumber)) {
        throw new Exception('Missing learnerID or ofoNumber');
    }
    
    // Extract form data
    $specialization = isset($data['specialization']) ? $data['specialization'] : null;
    $postal_address1 = isset($data['postal_address1']) ? $data['postal_address1'] : null;
    $postal_address2 = isset($data['postal_address2']) ? $data['postal_address2'] : null;
    $postal_code = isset($data['postal_code']) ? $data['postal_code'] : null;
    $fax_number = isset($data['fax_number']) ? $data['fax_number'] : null;
    $currently_employed = isset($data['currently_employed']) ? ($data['currently_employed'] ? 'yes' : 'no') : null;
    $self_employed = isset($data['self_employed']) ? ($data['self_employed'] ? 'yes' : 'no') : null;
    $current_employer = isset($data['current_employer']) ? $data['current_employer'] : null;
    $position_job_title = isset($data['position_job_title']) ? $data['position_job_title'] : null;
    $employer_address = isset($data['employer_address']) ? $data['employer_address'] : null;
    $reference = isset($data['reference']) ? $data['reference'] : null;
    $employer_tel = isset($data['employer_tel']) ? $data['employer_tel'] : null;
    $employer_fax = isset($data['employer_fax']) ? $data['employer_fax'] : null;
    $employer_cell = isset($data['employer_cell']) ? $data['employer_cell'] : null;
    $employer_email = isset($data['employer_email']) ? $data['employer_email'] : null;
    $candidate_signature = isset($data['candidate_signature']) ? $data['candidate_signature'] : null;
    $signature_date = isset($data['signature_date']) ? $data['signature_date'] : null;
    
    // Handle employment history (array of objects)
    $employment_history = isset($data['employment_history']) ? json_encode($data['employment_history']) : null;
    
    // Check if record exists
    $stmt = $conn->prepare("SELECT id FROM arpl_appendix_a WHERE learnerID = ? AND ofo_number = ?");
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    $result = $stmt->get_result();
    $exists = $result->num_rows > 0;
    $stmt->close();
    
    if ($exists) {
        // UPDATE existing record
        $stmt = $conn->prepare("
            UPDATE arpl_appendix_a SET
                specialization = ?,
                postal_address1 = ?,
                postal_address2 = ?,
                postal_code = ?,
                fax_number = ?,
                currently_employed = ?,
                self_employed = ?,
                current_employer = ?,
                position_job_title = ?,
                employer_address = ?,
                reference = ?,
                employer_tel = ?,
                employer_fax = ?,
                employer_cell = ?,
                employer_email = ?,
                employment_history = ?,
                candidate_signature = ?,
                signature_date = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE learnerID = ? AND ofo_number = ?
        ");
        $stmt->bind_param('sssssssssssssssssis',
            $specialization, $postal_address1, $postal_address2, $postal_code,
            $fax_number, $currently_employed, $self_employed, $current_employer,
            $position_job_title, $employer_address, $reference, $employer_tel,
            $employer_fax, $employer_cell, $employer_email, $employment_history,
            $candidate_signature, $signature_date, $learnerID, $ofoNumber
        );
    } else {
        // INSERT new record
        $stmt = $conn->prepare("
            INSERT INTO arpl_appendix_a (
                learnerID, ofo_number, specialization, postal_address1, postal_address2,
                postal_code, fax_number, currently_employed, self_employed, current_employer,
                position_job_title, employer_address, reference, employer_tel, employer_fax,
                employer_cell, employer_email, employment_history, candidate_signature, signature_date
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->bind_param('isssssssssssssssssss',
            $learnerID, $ofoNumber, $specialization, $postal_address1, $postal_address2,
            $postal_code, $fax_number, $currently_employed, $self_employed, $current_employer,
            $position_job_title, $employer_address, $reference, $employer_tel, $employer_fax,
            $employer_cell, $employer_email, $employment_history, $candidate_signature, $signature_date
        );
    }
    
    if ($stmt->execute()) {
        echo json_encode([
            'status' => 'success',
            'message' => $exists ? 'Appendix A updated successfully' : 'Appendix A created successfully',
            'learnerID' => $learnerID,
            'ofoNumber' => $ofoNumber
        ]);
    } else {
        throw new Exception('Database error: ' . $stmt->error);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
