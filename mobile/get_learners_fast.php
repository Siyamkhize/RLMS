<?php
include 'connection.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    // Get parameters
    $classID = $_GET['classID'] ?? $_POST['classID'] ?? null;
    $page = (int)($_GET['page'] ?? $_POST['page'] ?? 1);
    $limit = (int)($_GET['limit'] ?? $_POST['limit'] ?? 50);
    $fields = $_GET['fields'] ?? $_POST['fields'] ?? 'basic'; // basic, full, minimal
    $search = $_GET['search'] ?? $_POST['search'] ?? '';
    
    if (!$classID) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'classID parameter is required']);
        exit;
    }

    $offset = ($page - 1) * $limit;
    
    // Define field sets for different use cases
    $fieldSets = [
        'minimal' => 'l.LearnerID, l.Name, l.Surname, l.IDNumber, l.classID',
        'basic' => 'l.LearnerID, l.Name, l.Surname, l.IDNumber, l.PhoneNumber, l.Email, l.classID, l.synced',
        'full' => 'l.LearnerID, l.Title, l.Name, l.Surname, l.IDNumber, l.DateOfBirth, l.PhoneNumber, l.Email, l.Age, l.Gender, l.classID, l.synced, l.profile_image, l.signature'
    ];
    
    $selectedFields = $fieldSets[$fields] ?? $fieldSets['basic'];
    
    // Build base query
    $baseQuery = "FROM learnerdetails l WHERE l.classID = ?";
    $params = [$classID];
    $types = 's';
    
    // Add search filter if provided
    if (!empty($search)) {
        $baseQuery .= " AND (l.IDNumber LIKE ? OR l.Name LIKE ? OR l.Surname LIKE ? OR CONCAT(l.Name, ' ', l.Surname) LIKE ?)";
        $searchPattern = '%' . $search . '%';
        $params = array_merge($params, [$searchPattern, $searchPattern, $searchPattern, $searchPattern]);
        $types .= 'ssss';
    }
    
    // Main query with pagination
    $query = "SELECT $selectedFields $baseQuery ORDER BY l.LearnerID LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= 'ii';
    
    $startTime = microtime(true);
    $stmt = $conn->prepare($query);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    $queryTime = round((microtime(true) - $startTime) * 1000, 2);
    
    $learners = [];
    while ($row = $result->fetch_assoc()) {
        $learners[] = $row;
    }
    
    // Get total count only if needed for pagination
    $totalCount = 0;
    if ($page === 1 || !empty($learners)) {
        $countParams = array_slice($params, 0, -2); // Remove limit and offset
        $countTypes = substr($types, 0, -2);
        
        $countQuery = "SELECT COUNT(*) as total $baseQuery";
        $countStmt = $conn->prepare($countQuery);
        $countStmt->bind_param($countTypes, ...$countParams);
        $countStmt->execute();
        $countResult = $countStmt->get_result();
        $totalCount = $countResult->fetch_assoc()['total'];
        $countStmt->close();
    }
    
    $stmt->close();
    
    // Calculate pagination info
    $totalPages = $totalCount > 0 ? ceil($totalCount / $limit) : 0;
    $hasNext = $page < $totalPages;
    $hasPrev = $page > 1;
    
    echo json_encode([
        'status' => 'success',
        'data' => $learners,
        'pagination' => [
            'page' => $page,
            'limit' => $limit,
            'total' => (int)$totalCount,
            'total_pages' => $totalPages,
            'has_next' => $hasNext,
            'has_prev' => $hasPrev
        ],
        'meta' => [
            'fields' => $fields,
            'search' => $search,
            'query_time_ms' => $queryTime,
            'result_count' => count($learners)
        ]
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error', 
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>