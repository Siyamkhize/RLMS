<?php
/**
 * ARPL Endpoint: Get Practical Assessment Data (Appendix F)
 * Retrieves practical assessment and workplace observation data
 * Database: arpl_appendix_f*, arpl_appendix_f_practical_tasks*, arpl_appendix_f_workplace_observations*
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
    'assessment' => null,
    'practical_tasks' => [],
    'workplace_observations' => []
];

try {
    $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0);
    $ofo_code = isset($_POST['ofo_code']) ? trim($_POST['ofo_code']) : (isset($_GET['ofo_code']) ? trim($_GET['ofo_code']) : '');
    
    if ($learnerID <= 0) {
        throw new Exception("Valid learnerID required");
    }
    
    // Determine table suffix based on trade
    $suffix = ''; // Default (Electrician)
    
    if ($ofo_code === '641201') {
        $suffix = '_bricklayer';
    } elseif ($ofo_code === '642601') {
        $suffix = '_plumber';
    }
    
    // Get main assessment data
    $table = 'arpl_appendix_f' . $suffix;
    $result = $conn->query("SHOW TABLES LIKE '$table'");
    
    if ($result && $result->num_rows > 0) {
        $stmt = $conn->prepare("SELECT * FROM $table WHERE learnerID = ? ORDER BY created_at DESC LIMIT 1");
        if ($stmt) {
            $stmt->bind_param("i", $learnerID);
            $stmt->execute();
            $result = $stmt->get_result();
            
            if ($result->num_rows > 0) {
                $assessment = $result->fetch_assoc();
                
                // Secure signature handling - never expose file URLs
                if (!empty($assessment['candidate_signature'])) {
                    $assessment['candidate_signature'] = loadSignatureSecurely($assessment['candidate_signature']);
                }
                if (!empty($assessment['assessor_signature'])) {
                    $assessment['assessor_signature'] = loadSignatureSecurely($assessment['assessor_signature']);
                }
                
                $response['assessment'] = $assessment;
            }
            $stmt->close();
        }
    }
    
    // Get practical tasks
    $table = 'arpl_appendix_f_practical_tasks' . $suffix;
    $result = $conn->query("SHOW TABLES LIKE '$table'");
    
    if ($result && $result->num_rows > 0) {
        $stmt = $conn->prepare("SELECT * FROM $table WHERE learnerID = ? ORDER BY task_id ASC");
        if ($stmt) {
            $stmt->bind_param("i", $learnerID);
            $stmt->execute();
            $result = $stmt->get_result();
            
            while ($row = $result->fetch_assoc()) {
                $response['practical_tasks'][] = $row;
            }
            $stmt->close();
        }
    }
    
    // Get workplace observations
    $table = 'arpl_appendix_f_workplace_observations' . $suffix;
    $result = $conn->query("SHOW TABLES LIKE '$table'");
    
    if ($result && $result->num_rows > 0) {
        $stmt = $conn->prepare("SELECT * FROM $table WHERE learnerID = ? ORDER BY observation_id ASC");
        if ($stmt) {
            $stmt->bind_param("i", $learnerID);
            $stmt->execute();
            $result = $stmt->get_result();
            
            while ($row = $result->fetch_assoc()) {
                $response['workplace_observations'][] = $row;
            }
            $stmt->close();
        }
    }
    
    $response['status'] = 'success';
    $response['message'] = 'Practical assessment data retrieved successfully';
    $response['practical_tasks_count'] = count($response['practical_tasks']);
    $response['observations_count'] = count($response['workplace_observations']);

} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in get_arpl_appendix_f.php: " . $e->getMessage());
}

echo json_encode($response);
?>
