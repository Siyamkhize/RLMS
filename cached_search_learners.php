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

// Simple file-based cache for search results
class SearchCache {
    private $cacheDir = 'cache/search/';
    private $cacheExpiry = 300; // 5 minutes
    
    public function __construct() {
        if (!is_dir($this->cacheDir)) {
            mkdir($this->cacheDir, 0755, true);
        }
    }
    
    private function getCacheKey($classID, $query, $page, $limit) {
        return md5($classID . '|' . strtolower(trim($query)) . '|' . $page . '|' . $limit);
    }
    
    private function getCacheFile($key) {
        return $this->cacheDir . $key . '.json';
    }
    
    public function get($classID, $query, $page, $limit) {
        $key = $this->getCacheKey($classID, $query, $page, $limit);
        $file = $this->getCacheFile($key);
        
        if (file_exists($file) && (time() - filemtime($file)) < $this->cacheExpiry) {
            $data = json_decode(file_get_contents($file), true);
            if ($data) {
                $data['meta']['cached'] = true;
                $data['meta']['cacheAge'] = time() - filemtime($file);
                return $data;
            }
        }
        
        return null;
    }
    
    public function set($classID, $query, $page, $limit, $data) {
        $key = $this->getCacheKey($classID, $query, $page, $limit);
        $file = $this->getCacheFile($key);
        
        $data['meta']['cached'] = false;
        $data['meta']['cachedAt'] = time();
        
        file_put_contents($file, json_encode($data));
    }
    
    public function clear($classID = null) {
        $files = glob($this->cacheDir . '*.json');
        foreach ($files as $file) {
            if ($classID === null || strpos(basename($file), md5($classID)) === 0) {
                unlink($file);
            }
        }
    }
}

try {
    $startTime = microtime(true);
    $cache = new SearchCache();
    
    // Get parameters
    $classID = $_GET['classID'] ?? $_POST['classID'] ?? null;
    $searchQuery = trim($_GET['search'] ?? $_POST['search'] ?? '');
    $page = (int)($_GET['page'] ?? $_POST['page'] ?? 1);
    $limit = min((int)($_GET['limit'] ?? $_POST['limit'] ?? 20), 50);
    $forceRefresh = ($_GET['refresh'] ?? $_POST['refresh'] ?? 'false') === 'true';

    if (!$classID) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'classID parameter is required']);
        exit;
    }

    // Try to get from cache first (unless force refresh)
    if (!$forceRefresh && !empty($searchQuery)) {
        $cachedResult = $cache->get($classID, $searchQuery, $page, $limit);
        if ($cachedResult) {
            echo json_encode($cachedResult);
            exit;
        }
    }

    // Calculate offset for pagination
    $offset = ($page - 1) * $limit;

    // Essential fields for search results
    $fields = [
        'l.LearnerID', 'l.Name', 'l.Surname', 'l.IDNumber', 
        'l.PhoneNumber', 'l.Email', 'l.Gender', 'l.Age', 'l.synced'
    ];
    $fieldList = implode(', ', $fields);

    // Build search query
    $whereClause = "l.classID = ?";
    $params = [$classID];
    $paramTypes = "s";

    if (!empty($searchQuery)) {
        // Use more efficient search strategy
        if (is_numeric($searchQuery)) {
            // Numeric search - prioritize ID number
            $whereClause .= " AND (l.IDNumber LIKE ? OR l.PhoneNumber LIKE ?)";
            $params[] = "%{$searchQuery}%";
            $params[] = "%{$searchQuery}%";
            $paramTypes .= "ss";
        } else {
            // Text search - prioritize names
            $whereClause .= " AND (l.Name LIKE ? OR l.Surname LIKE ? OR l.IDNumber LIKE ?)";
            $params[] = "%{$searchQuery}%";
            $params[] = "%{$searchQuery}%";
            $params[] = "%{$searchQuery}%";
            $paramTypes .= "sss";
        }
    }

    // Main query with smart ordering
    $orderBy = "l.Name, l.Surname";
    if (!empty($searchQuery)) {
        $orderBy = "CASE 
                        WHEN l.IDNumber LIKE '{$searchQuery}%' THEN 1
                        WHEN l.Name LIKE '{$searchQuery}%' THEN 2
                        WHEN l.Surname LIKE '{$searchQuery}%' THEN 3
                        ELSE 4
                    END, l.Name, l.Surname";
    }

    $sql = "SELECT $fieldList
            FROM learnerdetails l
            WHERE $whereClause
            ORDER BY $orderBy
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
        // Clean up data and only include non-empty values
        $learner = [];
        foreach ($row as $key => $value) {
            if ($value !== null && $value !== '') {
                $learner[$key] = $value;
            } elseif (in_array($key, ['LearnerID', 'Name', 'Surname', 'IDNumber', 'classID'])) {
                $learner[$key] = $value ?? '';
            }
        }
        $learners[] = $learner;
    }

    // Get total count for pagination (only when needed)
    $totalLearners = 0;
    $totalPages = 0;
    
    if (!empty($searchQuery) || $page === 1) {
        $countSql = "SELECT COUNT(*) as total FROM learnerdetails l WHERE $whereClause";
        $countStmt = $conn->prepare($countSql);
        
        $countParams = array_slice($params, 0, -2);
        $countParamTypes = substr($paramTypes, 0, -2);
        
        $countStmt->bind_param($countParamTypes, ...$countParams);
        $countStmt->execute();
        $countResult = $countStmt->get_result();
        $totalLearners = $countResult->fetch_assoc()['total'];
        $totalPages = ceil($totalLearners / $limit);
        $countStmt->close();
    }

    $responseTime = round((microtime(true) - $startTime) * 1000, 2);

    // Build response
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
            'resultCount' => count($learners),
            'responseTime' => $responseTime . 'ms',
            'cached' => false
        ]
    ];

    // Cache the result if it's a search query
    if (!empty($searchQuery)) {
        $cache->set($classID, $searchQuery, $page, $limit, $response);
    }

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