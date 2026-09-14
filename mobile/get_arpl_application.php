<?php
/**
 * ARPL Endpoint: Get Application Form Data (Appendix A)
 * Retrieves previously submitted application form data
 * Database: arpl_applications_v3, arpl_applications_v4
 */

require_once 'connection.php';
header('Content-Type: application/json');

/**
 * Securely load signature file and convert to base64 data URL
 * Prevents exposing file paths in API responses
 */
function loadSignatureSecurely($signature) {
    if (empty($signature)) {
        return null;
    }
    
    // Check if signature is a filename (ends with .png, .jpg, etc.)
    if (preg_match('/\.(png|jpg|jpeg|gif)$/i', $signature)) {
        // It's a filename - look for it in the mobile/signatures folder
        $mobilePath = __DIR__ . '/signatures/' . $signature;
        
        if (file_exists($mobilePath)) {
            $imageData = file_get_contents($mobilePath);
            $base64 = base64_encode($imageData);
            return 'data:image/png;base64,' . $base64;
        }
        
        // Try parent signatures folder
        $parentPath = dirname(__DIR__) . '/signatures/' . $signature;
        if (file_exists($parentPath)) {
            $imageData = file_get_contents($parentPath);
            $base64 = base64_encode($imageData);
            return 'data:image/png;base64,' . $base64;
        }
        
        // File not found
        return null;
    }
    
    // If it's already a data URL, use as-is
    if (strpos($signature, 'data:image') === 0) {
        return $signature;
    }
    
    // If it's just base64, prepend data URL prefix
    if (!empty($signature)) {
        return 'data:image/png;base64,' . $signature;
    }
    
    return null;
}

$response = [
    'status' => 'error',
    'message' => '',
    'application' => null
];

try {
    $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0);
    $ofo_code = isset($_POST['ofo_code']) ? trim($_POST['ofo_code']) : (isset($_GET['ofo_code']) ? trim($_GET['ofo_code']) : '');
    
    if ($learnerID <= 0) {
        throw new Exception("Valid learnerID required");
    }
    
    // Try v4 first, then v3 for backwards compatibility
    $tables = ['arpl_applications_v4', 'arpl_applications_v3'];
    $application = null;
    
    foreach ($tables as $table) {
        $result = $conn->query("SHOW TABLES LIKE '$table'");
        if ($result && $result->num_rows > 0) {
            $stmt = $conn->prepare("SELECT * FROM $table WHERE learnerID = ? ORDER BY created_at DESC LIMIT 1");
            if ($stmt) {
                $stmt->bind_param("i", $learnerID);
                $stmt->execute();
                $result = $stmt->get_result();
                if ($result->num_rows > 0) {
                    $application = $result->fetch_assoc();
                    
                    // Secure signature handling - never expose file URLs
                    if (!empty($application['candidate_signature'])) {
                        $application['candidate_signature'] = loadSignatureSecurely($application['candidate_signature']);
                    }
                    
                    $stmt->close();
                    break;
                }
                $stmt->close();
            }
        }
    }
    
    if ($application) {
        $response['status'] = 'success';
        $response['message'] = 'Application form data retrieved successfully';
        $response['application'] = $application;
    } else {
        $response['status'] = 'success';
        $response['message'] = 'No application form data found - form is new';
        $response['application'] = null;
    }

} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in get_arpl_application.php: " . $e->getMessage());
}

echo json_encode($response);
?>
