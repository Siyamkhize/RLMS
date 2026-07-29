<?php
/**
 * Get Complete ARPL Data for PDF Generation
 * Aggregates all learner data from mobile ARPL tables for portfolio PDF
 * 
 * Endpoint: POST web/api/get_arpl_complete_data.php
 * 
 * Request:
 * {
 *   "learnerID": 20286,
 *   "ofo_code": "671101",  // Trade OFO code
 *   "trade": "electrician"  // Optional: Helps with trade-specific table routing
 * }
 * 
 * Response:
 * {
 *   "status": "success",
 *   "learner": {...},
 *   "class_info": {...},
 *   "appendixA": {...},
 *   "appendixB": [...],
 *   "appendixD": {...},
 *   "appendixE": [...],
 *   "appendixF": {...},
 *   "appendixG": {...},
 *   "appendixH": {...},
 *   "appendixI": {...},
 *   "documents": {...},
 *   "assessor": {...}
 * }
 */

// Set headers FIRST before any output
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Suppress error messages from showing in output
ini_set('display_errors', 0);
error_reporting(E_ALL);

// LOAD CONNECTION - One level up from api/
$root_conn_file = __DIR__ . '/../connection.php';
if (!file_exists($root_conn_file)) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Connection file not found at: ' . $root_conn_file
    ]);
    exit;
}

@require_once $root_conn_file;

// Helper function to determine trade from OFO code
function getTradeName($ofoCode) {
    $ofoMapping = [
        '671101' => 'electrician',    // Correct OFO for Electrician
        '642601' => 'plumbing',       // FIXED from 671102 to 642601
        '641201' => 'bricklaying'     // FIXED from 671103 to 641201
    ];
    return isset($ofoMapping[$ofoCode]) ? $ofoMapping[$ofoCode] : null;
}

// Helper function to get trade-specific table name
function getTradeTable($baseTable, $trade) {
    if ($trade === 'electrician') {
        return $baseTable;  // Standard table name for electrician
    } elseif ($trade === 'bricklaying') {
        return str_replace('_', '_' . $trade . '_', $baseTable);  // e.g., arpl_appendix_a_bricklaying
    } elseif ($trade === 'plumbing') {
        return str_replace('_', '_' . $trade . '_', $baseTable);
    }
    return $baseTable;
}

try {
    // Get request data
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON request');
    }
    
    $learnerID = isset($data['learnerID']) ? intval($data['learnerID']) : 0;
    $ofo_code = isset($data['ofo_code']) ? trim($data['ofo_code']) : '';
    $trade = isset($data['trade']) ? trim($data['trade']) : getTradeName($ofo_code);
    
    if ($learnerID <= 0 || empty($ofo_code)) {
        throw new Exception('Missing learnerID or ofo_code');
    }
    
    // Verify connection exists
    if (!isset($conn) || !$conn) {
        throw new Exception('Database connection failed');
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD LEARNER DETAILS
    // ══════════════════════════════════════════════════════════
    $learner = null;
    $stmt = $conn->prepare("
        SELECT 
            LearnerID, Title, Name, Surname, IDNumber, DateOfBirth,
            PhoneNumber, Email, Gender, Race, Language,
            AddressLine1, AddressLine2, AddressLine3, PostalCode,
            SchoolName, SchoolCompletion, SchoolGrade
        FROM learnerdetails
        WHERE LearnerID = ?
    ");
    if ($stmt) {
        $stmt->bind_param('i', $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();
        $learner = $result->fetch_assoc();
        $stmt->close();
    }
    
    if (!$learner) {
        throw new Exception('Learner not found: ' . $learnerID);
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD ASSESSOR DETAILS & CERTIFICATE
    // ══════════════════════════════════════════════════════════
    $assessor = null;
    // Try to get assessor from enrollment (class facilitator)
    $stmt = $conn->prepare("
        SELECT DISTINCT f.FacilitatorID, f.Name, f.Surname, f.Email, f.PhoneNumber
        FROM enrollment e
        INNER JOIN class c ON e.classID = c.classID
        LEFT JOIN facilitator f ON c.FacilitatorID = f.FacilitatorID
        WHERE e.LearnerID = ?
        LIMIT 1
    ");
    if ($stmt) {
        $stmt->bind_param('i', $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($row = $result->fetch_assoc()) {
            $assessor = [
                'facilitatorID' => $row['FacilitatorID'],
                'name' => ($row['Name'] ?? '') . ' ' . ($row['Surname'] ?? ''),
                'email' => $row['Email'] ?? '',
                'phone' => $row['PhoneNumber'] ?? '',
                'artisan_certificate' => null  // To be fetched if available
            ];
        }
        $stmt->close();
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD CLASS INFO
    // ══════════════════════════════════════════════════════════
    $classInfo = null;
    $stmt = $conn->prepare("
        SELECT DISTINCT 
            c.classID, c.className, c.trade, c.ofoNumber,
            s.siteName, s.siteID
        FROM enrollment e
        INNER JOIN class c ON e.classID = c.classID
        LEFT JOIN sites s ON c.siteID = s.siteID
        WHERE e.LearnerID = ? AND c.ofoNumber = ?
        LIMIT 1
    ");
    if ($stmt) {
        $stmt->bind_param('is', $learnerID, $ofo_code);
        $stmt->execute();
        $result = $stmt->get_result();
        $classInfo = $result->fetch_assoc();
        $stmt->close();
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD LEARNER DOCUMENTS
    // (ID, CV, Qualifications, Service Letters, Workplace Photos)
    // ══════════════════════════════════════════════════════════
    $documents = [
        'id_copy' => null,
        'cv' => null,
        'qualifications' => [],
        'service_letters' => [],
        'workplace_photos' => [],
        'theory_papers' => [],
        'practical_papers' => []
    ];
    
    // Get documents from learner_document table
    $stmt = $conn->prepare("
        SELECT 
            document_id, learner_id, document_type, file_path, 
            file_name, uploaded_at, document_date
        FROM learner_document
        WHERE learner_id = ?
        ORDER BY document_type ASC, uploaded_at DESC
    ");
    if ($stmt) {
        $stmt->bind_param('i', $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();
        while ($doc = $result->fetch_assoc()) {
            $docType = strtolower($doc['document_type']);
            if ($docType === 'id' || $docType === 'id copy') {
                $documents['id_copy'] = $doc;
            } elseif ($docType === 'cv' || $docType === 'curriculum vitae') {
                $documents['cv'] = $doc;
            } elseif (strpos($docType, 'qualification') !== false || strpos($docType, 'certificate') !== false) {
                $documents['qualifications'][] = $doc;
            } elseif (strpos($docType, 'service') !== false || strpos($docType, 'letter') !== false) {
                $documents['service_letters'][] = $doc;
            } elseif (strpos($docType, 'photo') !== false || strpos($docType, 'image') !== false || strpos($docType, 'workplace') !== false) {
                $documents['workplace_photos'][] = $doc;
            }
        }
        $stmt->close();
    }
    
    // Get POE documents (theory and practical papers)
    $stmt = $conn->prepare("
        SELECT 
            id, learner_id, subject_title, file_path, file_name,
            poe_type, uploaded_at
        FROM poe
        WHERE learner_id = ? AND ofo_code = ?
        ORDER BY poe_type ASC, uploaded_at DESC
    ");
    if ($stmt) {
        $stmt->bind_param('is', $learnerID, $ofo_code);
        $stmt->execute();
        $result = $stmt->get_result();
        while ($paper = $result->fetch_assoc()) {
            $poeType = strtolower($paper['poe_type']);
            if (strpos($poeType, 'theory') !== false) {
                $documents['theory_papers'][] = $paper;
            } elseif (strpos($poeType, 'practical') !== false || strpos($poeType, 'trade') !== false) {
                $documents['practical_papers'][] = $paper;
            }
        }
        $stmt->close();
    }
    
    // ══════════════════════════════════════════════════════════
    // LOAD APPENDIX DATA
    // For now, return placeholder structure - data already loaded from mobile
    // ══════════════════════════════════════════════════════════
    $appendixData = [
        'appendixA' => null,  // Application form
        'appendixB' => [],    // Theory activities
        'appendixC' => null,  // Curriculum (empty as per spec)
        'appendixD' => null,  // Practical skills
        'appendixE' => [],    // Workplace activities
        'appendixF' => null,  // Practical assessment
        'appendixG' => null,  // Appeals form
        'appendixH' => null,  // Access recommendations & gap closure
        'appendixI' => null   // Statement of results
    ];
    
    // Note: Full appendix data should be loaded using the mobile endpoint pattern
    // For this portfolio generator, we'll keep it lightweight and reference
    // the mobile get_*_toolkit_data.php endpoints if needed for detail
    
    // ══════════════════════════════════════════════════════════
    // BUILD RESPONSE
    // ══════════════════════════════════════════════════════════
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'learnerID' => $learnerID,
        'trade' => $trade,
        'ofo_code' => $ofo_code,
        'learner' => $learner,
        'class_info' => $classInfo,
        'assessor' => $assessor,
        'documents' => $documents,
        'appendices' => $appendixData,
        'generated_at' => date('Y-m-d H:i:s'),
        'note' => 'Use mobile toolkit endpoint for complete appendix data'
    ], JSON_UNESCAPED_SLASHES);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_SLASHES);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>
