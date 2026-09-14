<?php
/**
 * Send OTP for Agreement Portal Access
 */
header('Content-Type: application/json');
error_reporting(E_ALL);
ini_set('display_errors', 0); // Don't display errors in output, only log them
ini_set('log_errors', 1);

$response = ['success' => false, 'message' => ''];

try {
    require_once '../connection.php';
} catch (Exception $e) {
    $response['message'] = 'Database connection failed. Please contact administrator.';
    $response['error'] = $e->getMessage();
    echo json_encode($response);
    exit;
}

try {
    $smsConfig = include('../sms_config.php');
    if (!isset($smsConfig['credentials']['token_id'])) {
        throw new Exception('SMS configuration is invalid');
    }
} catch (Exception $e) {
    $response['message'] = 'SMS configuration error. Please contact administrator.';
    $response['error'] = $e->getMessage();
    echo json_encode($response);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id_number = trim($_POST['id_number'] ?? '');
    
    // Validate ID Number
    if (empty($id_number) || !preg_match('/^[0-9]{13}$/', $id_number)) {
        $response['message'] = 'Invalid ID Number format.';
        echo json_encode($response);
        exit;
    }
    
    // Check if learner exists and get phone number
    $stmt = $conn->prepare("
        SELECT LearnerID, Name, Surname, PhoneNumber 
        FROM learnerdetails 
        WHERE IDNumber = ? 
        LIMIT 1
    ");
    
    $stmt->bind_param('s', $id_number);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        $response['message'] = 'No learner found with this ID Number.';
        echo json_encode($response);
        exit;
    }
    
    $learner = $result->fetch_assoc();
    $learner_id = $learner['LearnerID'];
    $phone = $learner['PhoneNumber'];
    
    // Validate phone number
    if (empty($phone)) {
        $response['message'] = 'No phone number on record. Please contact administrator.';
        echo json_encode($response);
        exit;
    }
    
    // Format phone number (ensure it starts with country code)
    $phone = preg_replace('/[^0-9]/', '', $phone);
    if (substr($phone, 0, 1) === '0') {
        $phone = '27' . substr($phone, 1);
    }
    
    // Check if there's an existing unexpired OTP for this learner
    $existing_otp_stmt = $conn->prepare("
        SELECT id, otp_code, expires_at, created_at
        FROM seda_otp_verification 
        WHERE learner_id = ? 
        AND verified = 0 
        AND expires_at > NOW()
        ORDER BY created_at DESC 
        LIMIT 1
    ");
    
    $existing_otp_stmt->bind_param('i', $learner_id);
    $existing_otp_stmt->execute();
    $existing_result = $existing_otp_stmt->get_result();
    
    if ($existing_result->num_rows > 0) {
        // Unexpired OTP already exists
        $existing_otp = $existing_result->fetch_assoc();
        $minutes_left = ceil((strtotime($existing_otp['expires_at']) - time()) / 60);
        
        $response['success'] = true;
        $response['message'] = 'OTP already sent to ' . substr($phone, 0, 4) . '****' . substr($phone, -3);
        $response['masked_phone'] = substr($phone, 0, 4) . '****' . substr($phone, -3);
        $response['existing_otp'] = true;
        $response['minutes_left'] = $minutes_left;
        echo json_encode($response);
        exit;
    }
    
    // Generate 6-digit OTP
    $otp = str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);
    
    // Store OTP in database - use MySQL DATE_ADD to avoid timezone issues
    $insert_stmt = $conn->prepare("
        INSERT INTO seda_otp_verification (learner_id, phone_number, otp_code, expires_at) 
        VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE))
    ");
    
    $insert_stmt->bind_param('iss', $learner['LearnerID'], $phone, $otp);
    
    if (!$insert_stmt->execute()) {
        $response['message'] = 'Failed to generate OTP. Please try again.';
        echo json_encode($response);
        exit;
    }
    
    // Send SMS
    $message = "Your RLMS Agreement Portal OTP is: $otp. Valid for 10 minutes. Do not share this code.";
    
    try {
        $ch = curl_init();
        $url = 'https://api.bulksms.com/v1/messages';
        
        $data = [
            'to' => $phone,
            'body' => $message
        ];
        
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Authorization: Basic ' . base64_encode($smsConfig['credentials']['token_id'] . ':' . $smsConfig['credentials']['token_secret'])
        ]);
        
        $result = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 201) {
            $response['success'] = true;
            $response['message'] = 'OTP sent to ' . substr($phone, 0, 4) . '****' . substr($phone, -3);
            $response['masked_phone'] = substr($phone, 0, 4) . '****' . substr($phone, -3);
        } else {
            $response['message'] = 'Failed to send OTP. Please try again.';
        }
        
    } catch (Exception $e) {
        $response['message'] = 'Error sending OTP: ' . $e->getMessage();
    }
}

echo json_encode($response);
?>
