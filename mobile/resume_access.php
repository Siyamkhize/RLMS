<?php
/**
 * Resume Access - Set session for learner with valid 24-hour access
 * This allows learners to return within 24 hours without new OTP
 */
header('Content-Type: application/json');
session_start();
require_once '../connection.php';

$response = ['success' => false, 'message' => ''];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id_number = trim($_POST['id_number'] ?? '');
    
    // Validate ID Number
    if (empty($id_number) || !preg_match('/^[0-9]{13}$/', $id_number)) {
        $response['message'] = 'Invalid ID Number format.';
        echo json_encode($response);
        exit;
    }
    
    // Check database for valid access
    $access_stmt = $conn->prepare("
        SELECT 
            o.id,
            o.access_expires_at,
            l.LearnerID,
            l.IDNumber
        FROM seda_otp_verification o
        JOIN learnerdetails l ON o.learner_id = l.LearnerID
        WHERE l.IDNumber = ?
        AND o.verified = 1
        AND o.access_expires_at IS NOT NULL
        AND o.access_expires_at > NOW()
        ORDER BY o.verified_at DESC
        LIMIT 1
    ");
    
    $access_stmt->bind_param('s', $id_number);
    $access_stmt->execute();
    $access_result = $access_stmt->get_result();
    
    if ($access_result->num_rows > 0) {
        // Valid access found
        $access_data = $access_result->fetch_assoc();
        
        // Create/update session
        $_SESSION['agreement_portal_verified'] = true;
        $_SESSION['agreement_portal_id'] = $id_number;
        $_SESSION['agreement_portal_expiry'] = strtotime($access_data['access_expires_at']);
        $_SESSION['agreement_portal_otp_id'] = $access_data['id'];
        
        $response['success'] = true;
        $response['message'] = 'Access restored successfully!';
    } else {
        $response['message'] = 'No valid access found. Please request OTP.';
    }
    
    $access_stmt->close();
}

echo json_encode($response);
?>
