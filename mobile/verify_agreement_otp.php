<?php
/**
 * Verify OTP for Agreement Portal Access
 */
header('Content-Type: application/json');
session_start();
require_once '../connection.php';

$response = ['success' => false, 'message' => ''];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id_number = trim($_POST['id_number'] ?? '');
    $otp = trim($_POST['otp'] ?? '');
    
    // Validate inputs
    if (empty($id_number) || empty($otp)) {
        $response['message'] = 'ID Number and OTP are required.';
        echo json_encode($response);
        exit;
    }
    
    // Get learner ID
    $learner_stmt = $conn->prepare("SELECT LearnerID FROM learnerdetails WHERE IDNumber = ? LIMIT 1");
    $learner_stmt->bind_param('s', $id_number);
    $learner_stmt->execute();
    $learner_result = $learner_stmt->get_result();
    
    if ($learner_result->num_rows === 0) {
        $response['message'] = 'Invalid ID Number.';
        echo json_encode($response);
        exit;
    }
    
    $learner = $learner_result->fetch_assoc();
    $learner_id = $learner['LearnerID'];
    
    // Debug logging (remove after testing)
    error_log("OTP Verification - Learner ID: $learner_id, ID Number: $id_number, OTP entered: $otp");
    
    // Check OTP
    $otp_stmt = $conn->prepare("
        SELECT id, attempts, expires_at, otp_code, created_at
        FROM seda_otp_verification 
        WHERE learner_id = ? 
        AND otp_code = ? 
        AND verified = 0 
        AND expires_at > NOW()
        ORDER BY created_at DESC 
        LIMIT 1
    ");
    
    $otp_stmt->bind_param('is', $learner_id, $otp);
    $otp_stmt->execute();
    $otp_result = $otp_stmt->get_result();
    
    // Debug: Check what OTPs exist for this learner
    $debug_stmt = $conn->prepare("
        SELECT id, otp_code, expires_at, verified, attempts, created_at
        FROM seda_otp_verification 
        WHERE learner_id = ? 
        ORDER BY created_at DESC 
        LIMIT 3
    ");
    $debug_stmt->bind_param('i', $learner_id);
    $debug_stmt->execute();
    $debug_result = $debug_stmt->get_result();
    $debug_otps = [];
    while ($row = $debug_result->fetch_assoc()) {
        $debug_otps[] = $row;
    }
    error_log("OTP Debug - All recent OTPs: " . json_encode($debug_otps));
    
    if ($otp_result->num_rows === 0) {
        // Check if OTP exists but expired or wrong
        $check_stmt = $conn->prepare("
            SELECT id, otp_code, attempts, expires_at, verified
            FROM seda_otp_verification 
            WHERE learner_id = ? 
            ORDER BY created_at DESC 
            LIMIT 1
        ");
        $check_stmt->bind_param('i', $learner_id);
        $check_stmt->execute();
        $check_result = $check_stmt->get_result();
        
        if ($check_result->num_rows > 0) {
            $check_row = $check_result->fetch_assoc();
            
            // Update attempts
            $update_stmt = $conn->prepare("UPDATE seda_otp_verification SET attempts = attempts + 1 WHERE id = ?");
            $update_stmt->bind_param('i', $check_row['id']);
            $update_stmt->execute();
            
            // Provide detailed error message for debugging
            if (strtotime($check_row['expires_at']) < time()) {
                $response['message'] = 'OTP has expired. Please request a new one.';
                $response['debug'] = 'OTP expired at: ' . $check_row['expires_at'];
            } elseif ($check_row['verified'] == 1) {
                $response['message'] = 'This OTP has already been used. Please request a new one.';
                $response['debug'] = 'OTP was already verified';
            } else {
                $response['message'] = 'Invalid OTP. Please try again.';
                $response['debug'] = 'Expected OTP: ' . substr($check_row['otp_code'], 0, 2) . '****. Entered: ' . substr($otp, 0, 2) . '****. Attempts: ' . ($check_row['attempts'] + 1);
            }
        } else {
            $response['message'] = 'No OTP found. Please request one first.';
            $response['debug'] = 'No OTP records found for this learner';
        }
        
        echo json_encode($response);
        exit;
    }
    
    $otp_data = $otp_result->fetch_assoc();
    
    // Check attempts (max 5)
    if ($otp_data['attempts'] >= 5) {
        $response['message'] = 'Too many failed attempts. Please request a new OTP.';
        echo json_encode($response);
        exit;
    }
    
    // Mark as verified and set 24-hour access expiry in database
    $access_expires_at = date('Y-m-d H:i:s', strtotime('+24 hours'));
    
    $verify_stmt = $conn->prepare("
        UPDATE seda_otp_verification 
        SET verified = 1, 
            verified_at = NOW(),
            access_expires_at = ?
        WHERE id = ?
    ");
    $verify_stmt->bind_param('si', $access_expires_at, $otp_data['id']);
    $verify_stmt->execute();
    
    // Create session - 24 hour expiry
    $_SESSION['agreement_portal_verified'] = true;
    $_SESSION['agreement_portal_id'] = $id_number;
    $_SESSION['agreement_portal_time'] = time();
    $_SESSION['agreement_portal_expiry'] = strtotime($access_expires_at);
    $_SESSION['agreement_portal_otp_id'] = $otp_data['id']; // Track which OTP granted access
    
    $response['success'] = true;
    $response['message'] = 'OTP verified successfully!';
}

echo json_encode($response);
?>
