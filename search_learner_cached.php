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
require_once 'search_cache.php';

try {
    // Get search parameters
    $searchTerm = isset($_GET['search']) ? trim($_GET['search']) : '';
    $classID = isset($_GET['classID']) ? trim($_GET['classID']) : '';
    $searchType = isset($_GET['type']) ? trim($_GET['type']) : 'id';
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

    // Create cache parameters
    $cacheParams = [
        'search' => $searchTerm,
        'classID' => $classID,
        'type' => $searchType,
        'limit' => $limit,
        'offset' => $offset
    ];

    // Use cached search with callback
    $result = getCachedSearchResults($cacheParams, function() use ($conn, $searchTerm, $classID, $searchType, $limit, $offset) {
        $startTime = microtime(true);
        
        // Optimized query based on search type
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
        
        // Add search conditions with optimized patterns
        switch ($searchType) {
            case 'id':
                // Use exact match first for better performance
                if (is_numeric($searchTerm)) {
                    $whereConditions[] = "l.IDNumber = ?";
                    $params[] = $searchTerm;
                    $types .= 's';
                } else {
                    $whereConditions[] = "l.IDNumber LIKE ?";
                    $params[] = $searchTerm . '%';
                    $types .= 's';
                }
                $orderBy = "ORDER BY l.IDNumber";
                break;
                
            case 'name':
                $whereConditions[] = "(l.Name LIKE ? OR l.Surname LIKE ?)";
                $searchPattern = $searchTerm . '%';
                $params[] = $searchPattern;
                $params[] = $searchPattern;
                $types .= 'ss';
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
                    l.PhoneNumber LIKE ?
                )";
                $searchPattern = $searchTerm . '%';
                $params[] = $searchPattern;
                $params[] = $searchPattern;
                $params[] = $searchPattern;
                $params[] = '%' . $searchTerm . '%';
                $types .= 'ssss';
                $orderBy = "ORDER BY 
                    (l.IDNumber = ?) DESC,
                    (l.Name LIKE ?) DESC,
                    l.Name, l.Surname";
                $params[] = $searchTerm;
                $params[] = $searchTerm . '%';
                $types .= 'ss';
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
        
        $stmt->close();
        
        return [
            'success' => true,
            'data' => $learners,
            'meta' => [
                'search_term' => $searchTerm,
                'search_type' => $searchType,
                'class_id' => $classID,
                'query_time_ms' => $queryTime,
                'result_count' => count($learners),
                'cached' => false
            ]
        ];
    });
    
    // Add cache indicator
    if (!isset($result['meta']['cached'])) {
        $result['meta']['cached'] = true;
    }
    
    echo json_encode($result);
    
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