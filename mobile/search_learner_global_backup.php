<?php
/**
 * Global Learner Search Endpoint
 * Searches across ALL learners (no SDP filter)
 * Supports pagination for large result sets
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

// Get search parameters
$search = isset($_GET['search']) ? trim($_GET['search']) : '';
$idNumber = $search; // Alias for clarity
$page = isset($_GET['page']) ? max(1, (int)$_GET['page']) : 1;
$limit = isset($_GET['limit']) ? min(100, max(1, (int)$_GET['limit'])) : 50;

if (empty($search)) {
    echo json_encode([
        'success' => false,
        'message' => 'Search parameter is required',
        'learners' => []
    ]);
    exit;
}

try {
    $offset = ($page - 1) * $limit;
    
    // Search query with three-tier matching:
    // 1. Exact match on IDNumber
    // 2. Cleaned match (removes spaces/dashes)
    // 3. LIKE search for partial matches
    
    $sql = "
        SELECT 
            l.LearnerID as learner_id,
            l.Name as name,
            l.Surname as surname,
            l.IDNumber as id_number,
            l.classID as class_id,
            c.ClassName as class_name,
            c.SiteID as site_id,
            s.SiteName as site_name
        FROM learnerdetails l
        LEFT JOIN class c ON l.classID = c.ClassID
        LEFT JOIN sites s ON c.SiteID = s.SiteID
        WHERE 
            l.IDNumber = ? OR
            REPLACE(REPLACE(l.IDNumber, ' ', ''), '-', '') = ? OR
            l.IDNumber LIKE ?
        ORDER BY 
            CASE 
                WHEN l.IDNumber = ? THEN 1
                WHEN REPLACE(REPLACE(l.IDNumber, ' ', ''), '-', '') = ? THEN 2
                ELSE 3
            END,
            l.Surname, l.Name
        LIMIT ? OFFSET ?
    ";
    
    $stmt = $conn->prepare($sql);
    
    // Clean the search term (remove spaces and dashes)
    $cleanedSearch = str_replace([' ', '-'], '', $idNumber);
    $likeSearch = '%' . $idNumber . '%';
    
    $stmt->bind_param('sssssii', 
        $idNumber,      // Exact match
        $cleanedSearch, // Cleaned match
        $likeSearch,    // LIKE search
        $idNumber,      // ORDER BY exact
        $cleanedSearch, // ORDER BY cleaned
        $limit, 
        $offset
    );
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $learners = [];
    while ($row = $result->fetch_assoc()) {
        $learners[] = [
            'learner_id' => $row['learner_id'],
            'name' => $row['name'],
            'surname' => $row['surname'],
            'id_number' => $row['id_number'],
            'class_id' => $row['class_id'],
            'class_name' => $row['class_name'],
            'site_id' => $row['site_id'],
            'site_name' => $row['site_name']
        ];
    }
    
    $stmt->close();
    
    // Get total count for pagination
    $countSql = "
        SELECT COUNT(*) as total
        FROM learnerdetails
        WHERE 
            IDNumber = ? OR
            REPLACE(REPLACE(IDNumber, ' ', ''), '-', '') = ? OR
            IDNumber LIKE ?
    ";
    
    $countStmt = $conn->prepare($countSql);
    $countStmt->bind_param('sss', $idNumber, $cleanedSearch, $likeSearch);
    $countStmt->execute();
    $countResult = $countStmt->get_result();
    $totalRow = $countResult->fetch_assoc();
    $total = (int)$totalRow['total'];
    $countStmt->close();
    
    $totalPages = ceil($total / $limit);
    $hasMore = $page < $totalPages;
    
    echo json_encode([
        'success' => true,
        'learners' => $learners,
        'count' => count($learners),
        'total' => $total,
        'page' => $page,
        'limit' => $limit,
        'total_pages' => $totalPages,
        'has_more' => $hasMore
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage(),
        'learners' => []
    ]);
}

$conn->close();
?>
