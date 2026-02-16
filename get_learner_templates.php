<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

// Suppress ALL output except our JSON
error_reporting(0);
ini_set('display_errors', 0);
ini_set('log_errors', 0);

// Start output buffering to catch any unwanted output
ob_start();

try {
    // Include database connection
    include('connection.php');
    
    $learnerID = isset($_GET['learnerID']) ? (int)$_GET['learnerID'] : 0;
    
    if ($learnerID <= 0) {
        throw new Exception("Invalid learner ID");
    }
    
    // Get learner fingerprint templates from learnerdetails table
    $sql = "SELECT 
                zkteco_left_template,
                zkteco_right_template,
                futronic_left_template,
                futronic_right_template
            FROM learnerdetails 
            WHERE LearnerID = ?";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param("i", $learnerID);
    if (!$stmt->execute()) {
        throw new Exception("Execute failed: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $templates = $result->fetch_assoc();
    
    if (!$templates) {
        throw new Exception("Learner not found");
    }
    
    $stmt->close();
    $conn->close();
    
    // Clear any unwanted output
    ob_clean();
    
    // Output only clean JSON
    echo json_encode([
        'success' => true,
        'templates' => [
            'zkteco_left_template' => $templates['zkteco_left_template'] ?? '',
            'zkteco_right_template' => $templates['zkteco_right_template'] ?? '',
            'futronic_left_template' => $templates['futronic_left_template'] ?? '',
            'futronic_right_template' => $templates['futronic_right_template'] ?? ''
        ]
    ]);

} catch (Exception $e) {
    // Clear any unwanted output
    ob_clean();
    
    // Output only clean JSON error
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

// End output buffering
ob_end_flush();
?>