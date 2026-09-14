<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'connection.php';

try {
    // Get search parameters
    $searchTerm = isset($_GET['search']) ? trim($_GET['search']) : '';
    $classID = isset($_GET['classID']) ? trim($_GET['classID']) : '';
    $searchType = isset($_GET['type']) ? trim($_GET['type']) : 'id'; // id, name, all
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 20;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;
    
    if (empty($searchTerm)) {
        echo json_encode([
            'success' => false,
            'message' => 'Search term is required',
            'data' => []
        ]);
        exit;
    }

    // Build optimized query based on search type
    $baseQuery = "
        SELECT 
            l.LearnerID,
            l.Name,
            l.Surname,
            l.IDNumber,
            l.PhoneNumber,
            l.Email,
            l.classID,
            c.ClassName,
            l.synced
        FROM learnerdetails l
        LEFT JOIN class c ON l.classID = c.classID
    ";
    
    $whereConditions = [];
    $params = [];
    $types = '';
    
    // Add class filter if provided
    if (!empty($classID)) {
        $whereConditions[] = "l.classID = ?";
        $params[] = $classID;
        $types .= 's';
    }
    
    // Add search conditions based on type
    switch ($searchType) {
        case 'id':
            // Exact match first, then partial match for ID numbers
            $whereConditions[] = "(l.IDNumber = ? OR l.IDNumber LIKE ?)";
            $params[] = $searchTerm;
            $params[] = '%' . $searchTerm . '%';
            $types .= 'ss';
            $orderBy = "ORDER BY (l.IDNumber = ?) DESC, l.IDNumber";
            $params[] = $searchTerm;
            $types .= 's';
            break;
            
        case 'name':
            $whereConditions[] = "(l.Name LIKE ? OR l.Surname LIKE ? OR CONCAT(l.Name, ' ', l.Surname) LIKE ?)";
            $searchPattern = '%' . $searchTerm . '%';
            $params[] = $searchPattern;
            $params[] = $searchPattern;
            $params[] = $searchPattern;
            $types .= 'sss';
            $orderBy = "ORDER BY l.Name, l.Surname";
            break;
            
        case 'phone':
            $whereConditions[] = "l.PhoneNumber LIKE ?";
            $params[] = '%' . $searchTerm . '%';
            $types .= 's';
            $orderBy = "ORDER BY l.PhoneNumber";
            break;
            
        default: // 'all'
            $whereConditions[] = "(
                l.IDNumber LIKE ? OR 
                l.Name LIKE ? OR 
                l.Surname LIKE ? OR 
                l.PhoneNumber LIKE ? OR 
                l.Email LIKE ? OR
                CONCAT(l.Name, ' ', l.Surname) LIKE ?
            )";
            $searchPattern = '%' . $searchTerm . '%';
            for ($i = 0; $i < 6; $i++) {
                $params[] = $searchPattern;
                $types .= 's';
            }
            $orderBy = "ORDER BY 
                (l.IDNumber = ?) DESC,
                (l.Name LIKE ?) DESC,
                (l.Surname LIKE ?) DESC,
                l.Name, l.Surname";
            $params[] = $searchTerm;
            $params[] = $searchTerm . '%';
            $params[] = $searchTerm . '%';
            $types .= 'sss';
            break;
    }
    
    // Combine query parts
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    $query = "$baseQuery $whereClause $orderBy LIMIT ? OFFSET ?";
    
    // Add limit and offset parameters
    $params[] = $limit;
    $params[] = $offset;
    $types .= 'ii';
    
    // Execute query
    $stmt = $conn->prepare($query);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    
    $startTime = microtime(true);
    $stmt->execute();
    $result = $stmt->get_result();
    $queryTime = round((microtime(true) - $startTime) * 1000, 2);
    
    $learners = [];
    while ($row = $result->fetch_assoc()) {
        $learners[] = [
            'learner_id' => $row['LearnerID'],
            'name' => $row['Name'],
            'surname' => $row['Surname'],
            'id_number' => $row['IDNumber'],
            'phone_number' => $row['PhoneNumber'],
            'email' => $row['Email'],
            'class_id' => $row['classID'],
            'class_name' => $row['ClassName'],
            'synced' => $row['synced']
        ];
    }
    
    // Get total count for pagination (only if we have results)
    $totalCount = 0;
    if (!empty($learners) || $offset > 0) {
        $countQuery = str_replace($baseQuery, "SELECT COUNT(DISTINCT l.LearnerID) as total FROM learnerdetails l LEFT JOIN class c ON l.classID = c.classID", $query);
        $countQuery = preg_replace('/ORDER BY.*?LIMIT.*?OFFSET.*?$/', '', $countQuery);
        
        $countStmt = $conn->prepare($countQuery);
        $countParams = array_slice($params, 0, -2); // Remove limit and offset
        $countTypes = substr($types, 0, -2);
        
        if (!empty($countParams)) {
            $countStmt->bind_param($countTypes, ...$countParams);
        }
        $countStmt->execute();
        $countResult = $countStmt->get_result();
        $totalCount = $countResult->fetch_assoc()['total'];
        $countStmt->close();
    }
    
    $stmt->close();
    
    echo json_encode([
        'success' => true,
        'data' => $learners,
        'pagination' => [
            'total' => (int)$totalCount,
            'limit' => $limit,
            'offset' => $offset,
            'has_more' => count($learners) === $limit
        ],
        'meta' => [
            'search_term' => $searchTerm,
            'search_type' => $searchType,
            'class_id' => $classID,
            'query_time_ms' => $queryTime,
            'result_count' => count($learners)
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Search error: ' . $e->getMessage(),
        'data' => []
    ]);
}

$conn->close();
?>