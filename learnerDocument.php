<?php
header('Content-Type: application/json');

include('connection.php');

$response = ['success' => false, 'error' => '', 'message' => '', 'redirect' => ''];

// Validate form inputs
if (!isset($_POST['documentName']) || empty($_POST['documentName'])) {
    $response['error'] = 'Document name is required.';
    echo json_encode($response);
    exit;
}

if (!isset($_POST['LearnerID']) || empty($_POST['LearnerID'])) {
    $response['error'] = 'Learner ID is required.';
    echo json_encode($response);
    exit;
}

if (!isset($_POST['uploadedFileName']) || empty($_POST['uploadedFileName'])) {
    $response['error'] = 'Uploaded file name is required.';
    echo json_encode($response);
    exit;
}

$documentName = $_POST['documentName'];
$otherDocumentName = isset($_POST['otherDocumentName']) ? $_POST['otherDocumentName'] : '';
$learnerID = $_POST['LearnerID'];
$fileName = basename($_POST['uploadedFileName']);
$finalDocumentName = ($documentName === 'Other' && !empty($otherDocumentName)) ? $otherDocumentName : $documentName;

// Sanitize inputs
$learnerID = mysqli_real_escape_string($conn, $learnerID);
$finalDocumentName = mysqli_real_escape_string($conn, $finalDocumentName);
$fileName = mysqli_real_escape_string($conn, $fileName);

// Check for existing record
$checkSql = "SELECT * FROM learner_document 
             WHERE learner_id = '$learnerID' 
             AND documentName = '$finalDocumentName'";
$result = $conn->query($checkSql);

if ($result !== false && $result->num_rows > 0) {
    // If record exists, perform an UPDATE
    $updateSql = "UPDATE learner_document 
                  SET learner_document = '$fileName', upload_date = NOW() ,status='Pending' 
                  WHERE learner_id = '$learnerID' AND documentName = '$finalDocumentName'";

    if ($conn->query($updateSql) === TRUE) {
        $response['success'] = true;
        $response['message'] = 'Document updated successfully.';
        $response['redirect'] = "sdp_learnerView.php?LearnerID=$learnerID";
    } else {
        $response['error'] = 'Failed to update document: ' . $conn->error;
    }
} else {
    // If no record exists, perform an INSERT
    $insertSql = "INSERT INTO learner_document (learner_id, documentName, learner_document, status, upload_date) 
                  VALUES ('$learnerID', '$finalDocumentName', '$fileName', 'Pending', NOW())";

    if ($conn->query($insertSql) === TRUE) {
        $response['success'] = true;
        $response['message'] = 'Document uploaded and saved successfully.';
        $response['redirect'] = "sdp_learnerView.php?LearnerID=$learnerID";
    } else {
        $response['error'] = 'Failed to save document to database: ' . $conn->error;
    }
}

$conn->close();
echo json_encode($response);
exit;
?>