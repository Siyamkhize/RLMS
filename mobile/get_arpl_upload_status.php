<?php
/**
 * ARPL Upload Status Endpoint
 * 
 * Retrieves all uploaded ARPL papers for a learner from the arpl_poe table
 * Called by Flutter app to check which papers have already been uploaded
 * 
 * Expected parameters:
 *   - learnerID (POST or GET): The learner's ID
 * 
 * Returns:
 *   - Array of uploaded papers with format:
 *     {
 *       "status": "success",
 *       "uploaded_papers": [
 *         {
 *           "ofo_number": "9964",
 *           "paper_number": 1,
 *           "section_type": "theory",
 *           "paper_title": "Apply health and safety...",
 *           "question_count": 15,
 *           "upload_status": "uploaded"
 *         }
 *       ]
 *     }
 */

ob_start();
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', 'debug.log');

try {
    // Include database connection
    include('connection.php');
    $conn = new mysqli($servername, $username, $password, $dbname);
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }

    header('Content-Type: application/json; charset=UTF-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'GET') {
        echo json_encode(['error' => 'Invalid request method. Use POST or GET.']);
        exit;
    }

    // Get learnerID from POST or GET
    $learnerID = ($_SERVER['REQUEST_METHOD'] == 'POST') ? 
                 (isset($_POST['learnerID']) ? intval($_POST['learnerID']) : 0) : 
                 (isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0);

    if ($learnerID <= 0) {
        echo json_encode([
            'status' => 'error',
            'error' => 'Invalid or missing learnerID.',
            'debug' => ['request_method' => $_SERVER['REQUEST_METHOD'], 'get_params' => $_GET, 'post_params' => $_POST]
        ]);
        exit;
    }

    error_log("=== GET_ARPL_UPLOAD_STATUS: Starting for learnerID=$learnerID ===");

    // Query the arpl_poe table for all uploaded papers for this learner
    $stmt = $conn->prepare("
        SELECT 
            id,
            ofo_number,
            paper_title,
            paper_number,
            section_type,
            question_count,
            file_name,
            combined_pdf_path,
            upload_status,
            created_at
        FROM arpl_poe
        WHERE learnerID = ?
        ORDER BY ofo_number, paper_number, section_type
    ");
    
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param("i", $learnerID);
    if (!$stmt->execute()) {
        throw new Exception("Execute failed: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $uploaded_papers = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    error_log("Found " . count($uploaded_papers) . " uploaded ARPL papers for learnerID=$learnerID");
    
    // Log each paper found
    foreach ($uploaded_papers as $paper) {
        error_log("Paper: OFO={$paper['ofo_number']}, Title={$paper['paper_title']}, Section={$paper['section_type']}, Questions={$paper['question_count']}");
    }

    // Return success with uploaded papers
    echo json_encode([
        'status' => 'success',
        'learnerID' => $learnerID,
        'uploaded_papers' => $uploaded_papers,
        'count' => count($uploaded_papers)
    ]);

} catch (Exception $e) {
    error_log("Error in get_arpl_upload_status.php: " . $e->getMessage());
    echo json_encode([
        'status' => 'error',
        'error' => 'Database query failed: ' . $e->getMessage(),
        'debug' => ['learnerID' => $learnerID ?? 'unknown']
    ]);
}

if (isset($conn)) {
    $conn->close();
}
ob_end_flush();
?>
