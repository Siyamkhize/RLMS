<?php
/**
 * ARPL Endpoint: Get Statement of Results (Appendix J)
 * Retrieves final results and marks for learner
 * Database: arpl_appendix_j_bricklayer, arpl_appendix_j_plumber (or generic arpl_appendix_j)
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
    'results' => null
];

try {
    $learnerID = isset($_POST['learnerID']) ? intval($_POST['learnerID']) : (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0);
    $ofo_code = isset($_POST['ofo_code']) ? trim($_POST['ofo_code']) : (isset($_GET['ofo_code']) ? trim($_GET['ofo_code']) : '');
    
    if ($learnerID <= 0) {
        throw new Exception("Valid learnerID required");
    }
    
    // Determine table based on trade
    $tables = [];
    
    if ($ofo_code === '641201') {
        $tables[] = 'arpl_appendix_j_bricklayer';
    } elseif ($ofo_code === '642601') {
        $tables[] = 'arpl_appendix_j_plumber';
    }
    
    // Also check generic table
    $tables[] = 'arpl_appendix_j';
    
    $results = null;
    
    foreach ($tables as $table) {
        $result = $conn->query("SHOW TABLES LIKE '$table'");
        
        if ($result && $result->num_rows > 0) {
            $stmt = $conn->prepare("SELECT * FROM $table WHERE learnerID = ? ORDER BY created_at DESC LIMIT 1");
            if ($stmt) {
                $stmt->bind_param("i", $learnerID);
                $stmt->execute();
                $result = $stmt->get_result();
                
                if ($result->num_rows > 0) {
                    $results = $result->fetch_assoc();
                    
                    // Secure signature handling - never expose file URLs
                    if (!empty($results['candidate_signature'])) {
                        $results['candidate_signature'] = loadSignatureSecurely($results['candidate_signature']);
                    }
                    if (!empty($results['witness_signature'])) {
                        $results['witness_signature'] = loadSignatureSecurely($results['witness_signature']);
                    }
                    
                    $stmt->close();
                    break;
                }
                $stmt->close();
            }
        }
    }
    
    $response['status'] = 'success';
    
    if ($results) {
        $response['results'] = $results;
        $response['message'] = 'Statement of results retrieved successfully';
    } else {
        $response['message'] = 'No statement of results found for this learner';
        $response['results'] = null;
    }

} catch (Exception $e) {
    $response['message'] = $e->getMessage();
    error_log("Error in get_arpl_statement_of_results.php: " . $e->getMessage());
}

echo json_encode($response);
?>
