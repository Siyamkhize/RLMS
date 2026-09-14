<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

// Database connection
require_once 'connection.php';

// Get learner_id from query parameter
$learnerID = isset($_GET['learner_id']) ? intval($_GET['learner_id']) : 0;

if ($learnerID <= 0) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid learner_id'
    ]);
    exit;
}

try {
    // Fetch guardian details
    $sql = "SELECT * FROM guardian_details WHERE learner_id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $guardianData = $result->fetch_assoc();
        
        // Build full URLs for signature images
        $protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http';
        $host = $_SERVER['HTTP_HOST'];
        $baseUrl = $protocol . '://' . $host . dirname($_SERVER['PHP_SELF']);
        
        // Add full URLs for signatures if they exist
        if (!empty($guardianData['signature'])) {
            $guardianData['signature_url'] = $baseUrl . '/signatures/' . $guardianData['signature'];
        }
        if (!empty($guardianData['witness_signature'])) {
            $guardianData['witness_signature_url'] = $baseUrl . '/signatures/' . $guardianData['witness_signature'];
        }
        
        echo json_encode([
            'success' => true,
            'data' => $guardianData
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'No guardian data found for this learner'
        ]);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
