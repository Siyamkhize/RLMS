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
    $searchQuery = trim($_GET['search'] ?? $_POST['search'] ?? '');
    $page = (int)($_GET['page'] ?? $_POST['page'] ?? 1);
    $limit = min((int)($_GET['limit'] ?? $_POST['limit'] ?? 20), 50); // Max 50 per page
    $searchType = $_GET['type'] ?? $_POST['type'] ?? 'all'; // 'id', 'name', 'all'

    if (!$classID) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'classID parameter is required']);
        exit;
    }

    // Calculate offset for pagination
    $offset = ($page - 1) * $limit;

    // Essential fields only for fast search results
    $fields = [
        'l.LearnerID', 'l.Name', 'l.Surname', 'l.IDNumber', 
        'l.PhoneNumber', 'l.Email', 'l.Gender', 'l.classID', 'l.synced'
    ];
    $fieldList = implode(', ', $fields);

    // Build optimized search query based on search type
    $whereClause = "l.classID = ?";
    $params = [$classID];
    $paramTypes = "s";

    if (!empty($searchQuery)) {
        switch ($searchType) {
            case 'id':
                $whereClause .= " AND l.IDNumber LIKE ?";
                $params[] = "%{$searchQuery}%";
                $paramTypes .= "s";
                break;
            case 'name':
                $whereClause .= " AND (l.Name LIKE ? OR l.Surname LIKE ?)";
                $params[] = "%{$searchQuery}%";
                $params[] = "%{$searchQuery}%";
                $paramTypes .= "ss";
                break;
            case 'all':
            default:
                $whereClause .= " AND (l.Name LIKE ? OR l.Surname LIKE ? OR l.IDNumber LIKE ? OR l.PhoneNumber LIKE ?)";
                $params[] = "%{$searchQuery}%";
                $params[] = "%{$searchQuery}%";
                $params[] = "%{$searchQuery}%";
                $params[] = "%{$searchQuery}%";
                $paramTypes .= "ssss";
                break;
        }
    }

    // Main query with optimized structure
    $sql = "SELECT $fieldList
            FROM learnerdetails l
            WHERE $whereClause
            ORDER BY l.Name, l.Surname
            LIMIT ? OFFSET ?";

    $params[] = $limit;
    $params[] = $offset;
    $paramTypes .= "ii";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param($paramTypes, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();

    $learners = [];
    while ($row = $result->fetch_assoc()) {
        // Only include non-null values to reduce payload size
        $learner = [];
        foreach ($row as $key => $value) {
            if ($value !== null && $value !== '') {
                $learner[$key] = $value;
            } elseif (in_array($key, ['LearnerID', 'Name', 'Surname', 'IDNumber', 'classID'])) {
                // Always include essential fields
                $learner[$key] = $value ?? '';
            }
        }
        $learners[] = $learner;
    }

    // Get total count for pagination (only if we have search results)
    $totalLearners = 0;
    $totalPages = 0;
    
    if (!empty($searchQuery) || $page === 1) {
        $countSql = "SELECT COUNT(*) as total FROM learnerdetails l WHERE $whereClause";
        $countStmt = $conn->prepare($countSql);
        
        // Remove limit and offset params for count query
        $countParams = array_slice($params, 0, -2);
        $countParamTypes = substr($paramTypes, 0, -2);
        
        $countStmt->bind_param($countParamTypes, ...$countParams);
        $countStmt->execute();
        $countResult = $countStmt->get_result();
        $totalLearners = $countResult->fetch_assoc()['total'];
        $totalPages = ceil($totalLearners / $limit);
        $countStmt->close();
    }

    // Return optimized response
    $response = [
        'status' => 'success',
        'data' => $learners,
        'pagination' => [
            'page' => $page,
            'limit' => $limit,
            'total' => (int)$totalLearners,
            'totalPages' => $totalPages,
            'hasNext' => $page < $totalPages,
            'hasPrev' => $page > 1
        ],
        'meta' => [
            'searchQuery' => $searchQuery,
            'searchType' => $searchType,
            'resultCount' => count($learners),
            'responseTime' => round((microtime(true) - $_SERVER['REQUEST_TIME_FLOAT']) * 1000, 2) . 'ms'
        ]
    ];

    echo json_encode($response);
    $stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error', 
        'message' => 'Server error: ' . $e->getMessage(),
        'code' => $e->getCode()
    ]);
}

$conn->close();
?>