<?php
/**
 * Get Trade Information from Class ID
 * 
 * Endpoint: GET/POST mobile/get_class_trade_info.php
 * 
 * Request Parameters:
 *   - classID: The class ID to look up (required)
 * 
 * Response:
 * {
 *   "status": "success",
 *   "classID": 783,
 *   "trade_id": 4,
 *   "trade_name": "Bricklaying",
 *   "ofo_number": "671103"
 * }
 */

header('Content-Type: application/json');
require_once 'connection.php';

try {
    // Get classID from request
    $classID = null;
    
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Try JSON input first
        $input = file_get_contents('php://input');
        $data = json_decode($input, true);
        
        if ($data && isset($data['classID'])) {
            $classID = intval($data['classID']);
        } else {
            // Try POST parameters
            $classID = isset($_POST['classID']) ? intval($_POST['classID']) : null;
        }
    } else {
        // GET parameters
        $classID = isset($_GET['classID']) ? intval($_GET['classID']) : null;
    }
    
    if (!$classID || $classID <= 0) {
        throw new Exception('Missing or invalid classID parameter');
    }
    
    // Query: class → sites (for Project_pathway) → trade
    // Note: Project_pathway is in the SITES table, not class table
    $stmt = $conn->prepare("
        SELECT 
            c.classID,
            c.className,
            c.trade_id,
            c.siteID,
            s.siteName,
            s.Project_pathway,
            t.trade_name,
            t.ofo_number
        FROM class c
        LEFT JOIN sites s ON c.siteID = s.siteID
        LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
        WHERE c.classID = ?
        LIMIT 1
    ");
    
    if (!$stmt) {
        throw new Exception('Database error: ' . $conn->error);
    }
    
    $stmt->bind_param('i', $classID);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        $stmt->close();
        throw new Exception('Class not found with ID: ' . $classID);
    }
    
    $classData = $result->fetch_assoc();
    $stmt->close();
    
    // Get OFO with fallback chain:
    // 1. From arpl_trades table (via trade_id JOIN)
    // 2. From Project_pathway JSON in SITES table
    // 3. Default to electrician
    $ofo = $classData['ofo_number'] ?? null;
    $trade = $classData['trade_name'] ?? null;
    
    // If no OFO from arpl_trades, try Project_pathway JSON from SITES table
    if (empty($ofo) && !empty($classData['Project_pathway'])) {
        try {
            $pathway = json_decode($classData['Project_pathway'], true);
            if ($pathway && is_array($pathway) && isset($pathway[0]['ofo_code'])) {
                $ofo = $pathway[0]['ofo_code'];
                $trade = $pathway[0]['name'] ?? $trade;
            }
        } catch (Exception $e) {
            // JSON decode failed, continue with fallback
        }
    }
    
    // Final fallback if still no OFO
    if (empty($ofo)) {
        $ofo = '671101';
        $trade = $trade ?? 'Electrician';
    }
    
    // Return response
    $response = [
        'status' => 'success',
        'classID' => intval($classData['classID']),
        'className' => $classData['className'],
        'trade_id' => intval($classData['trade_id'] ?? 1),
        'trade_name' => $trade,
        'ofo_number' => $ofo,
        'siteName' => $classData['siteName']
    ];
    
    http_response_code(200);
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
