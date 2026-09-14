<?php
/**
 * Save ARPL Appendix I: Statement of Results
 * Endpoint: POST mobile/save_arpl_appendix_i.php
 * 
 * Saves assessment results including knowledge, practical, and workplace competency
 * evaluations, along with overall competency rating and assessor details.
 */

header('Content-Type: application/json');
require_once 'connection.php';

try {
    // Read JSON input
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!isset($data['learnerID']) || !isset($data['ofoNumber'])) {
        throw new Exception('Missing learnerID or ofoNumber');
    }
    
    $learnerID = intval($data['learnerID']);
    $ofoNumber = $data['ofoNumber'];
    
    // Extract form fields
    $providerType = isset($data['provider_type']) ? $data['provider_type'] : 'Skills Development Provider';
    $knowledgeResult = isset($data['knowledge_result']) ? $data['knowledge_result'] : null;
    $practicalResult = isset($data['practical_result']) ? $data['practical_result'] : null;
    $workplaceResult = isset($data['workplace_result']) ? $data['workplace_result'] : null;
    $overallCompetencyRating = isset($data['overall_competency_rating']) ? intval($data['overall_competency_rating']) : null;
    $assessorName = isset($data['assessor_name']) ? $data['assessor_name'] : null;
    $assessorRegNumber = isset($data['assessor_reg_number']) ? $data['assessor_reg_number'] : null;
    $certificationDate = isset($data['certification_date']) ? $data['certification_date'] : null;
    $additionalNotes = isset($data['additional_notes']) ? $data['additional_notes'] : null;
    
    // Validate provider type
    $validProviders = ['Assessment Centre', 'Skills Development Provider'];
    if (!in_array($providerType, $validProviders)) {
        $providerType = 'Skills Development Provider';
    }
    
    // Validate result values
    $validResults = ['Competent', 'Not Yet Competent'];
    if ($knowledgeResult && !in_array($knowledgeResult, $validResults)) {
        $knowledgeResult = null;
    }
    if ($practicalResult && !in_array($practicalResult, $validResults)) {
        $practicalResult = null;
    }
    if ($workplaceResult && !in_array($workplaceResult, $validResults)) {
        $workplaceResult = null;
    }
    
    // Validate rating (1-5)
    if ($overallCompetencyRating !== null && ($overallCompetencyRating < 1 || $overallCompetencyRating > 5)) {
        $overallCompetencyRating = null;
    }
    
    // Check if record exists
    $stmt = $conn->prepare("SELECT id FROM arpl_appendix_i WHERE learnerID = ? AND ofo_number = ?");
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    $result = $stmt->get_result();
    $exists = $result->fetch_assoc();
    $stmt->close();
    
    if ($exists) {
        // UPDATE existing record
        $stmt = $conn->prepare("
            UPDATE arpl_appendix_i SET
                provider_type = ?,
                knowledge_result = ?,
                practical_result = ?,
                workplace_result = ?,
                overall_competency_rating = ?,
                assessor_name = ?,
                assessor_reg_number = ?,
                certification_date = ?,
                additional_notes = ?
            WHERE learnerID = ? AND ofo_number = ?
        ");
        
        $stmt->bind_param(
            'ssssissssis',
            $providerType,
            $knowledgeResult,
            $practicalResult,
            $workplaceResult,
            $overallCompetencyRating,
            $assessorName,
            $assessorRegNumber,
            $certificationDate,
            $additionalNotes,
            $learnerID,
            $ofoNumber
        );
        
        $message = 'Appendix I results updated successfully';
    } else {
        // INSERT new record
        $stmt = $conn->prepare("
            INSERT INTO arpl_appendix_i 
            (learnerID, ofo_number, provider_type, knowledge_result, practical_result, 
             workplace_result, overall_competency_rating, assessor_name, assessor_reg_number, 
             certification_date, additional_notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        
        $stmt->bind_param(
            'isssssisss',
            $learnerID,
            $ofoNumber,
            $providerType,
            $knowledgeResult,
            $practicalResult,
            $workplaceResult,
            $overallCompetencyRating,
            $assessorName,
            $assessorRegNumber,
            $certificationDate,
            $additionalNotes
        );
        
        $message = 'Appendix I results created successfully';
    }
    
    if ($stmt->execute()) {
        echo json_encode([
            'status' => 'success',
            'message' => $message,
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
