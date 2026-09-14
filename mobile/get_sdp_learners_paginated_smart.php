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
    $startTime = microtime(true);
    
    // Get parameters
    $sdp_id = $_GET['sdp_id'] ?? null;
    $sdp_name = $_GET['sdp_name'] ?? null;
    $page = max(1, intval($_GET['page'] ?? 1));
    $limit = min(100, max(10, intval($_GET['limit'] ?? 50))); // Between 10-100 records per page
    $search = trim($_GET['search'] ?? '');
    $site_filter = $_GET['site'] ?? '';
    $class_filter = $_GET['class'] ?? '';
    
    $offset = ($page - 1) * $limit;

    // Validate SDP identifier
    if (!$sdp_id && !$sdp_name) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'sdp_id or sdp_name parameter is required']);
        exit;
    }

    // Build the WHERE clause for SDP filtering
    // Note: Learners are linked to SDPs through sites, not directly
    $sdp_condition = '';
    $params = [];
    $types = '';
    
    if ($sdp_id) {
        $sdp_condition = "si.sdp_id = ?";
        $params[] = $sdp_id;
        $types .= 'i';
    } else {
        $sdp_condition = "s.sdp_name = ?";
        $params[] = $sdp_name;
        $types .= 's';
    }

    // Build additional filters with smart search optimization
    $additional_conditions = [];
    $order_by = "l.Surname, l.Name"; // Default ordering
    
    if (!empty($search)) {
        // Smart search with relevance ranking
        if (is_numeric($search)) {
            // Numeric search - prioritize ID number matches
            $additional_conditions[] = "(l.IDNumber LIKE ? OR l.PhoneNumber LIKE ? OR l.Name LIKE ? OR l.Surname LIKE ?)";
            $exact_search = $search . '%'; // Prefix match for better performance
            $fuzzy_search = '%' . $search . '%';
            $params[] = $exact_search;
            $params[] = $fuzzy_search;
            $params[] = $fuzzy_search;
            $params[] = $fuzzy_search;
            $types .= 'ssss';
            
            // Smart ordering for numeric search
            $order_by = "CASE 
                            WHEN l.IDNumber LIKE '$exact_search' THEN 1
                            WHEN l.IDNumber LIKE '$fuzzy_search' THEN 2
                            WHEN l.PhoneNumber LIKE '$fuzzy_search' THEN 3
                            ELSE 4
                         END, l.Surname, l.Name";
        } else {
            // Text search - prioritize name matches
            $additional_conditions[] = "(l.Name LIKE ? OR l.Surname LIKE ? OR CONCAT(l.Name, ' ', l.Surname) LIKE ? OR l.IDNumber LIKE ?)";
            $prefix_search = $search . '%';
            $fuzzy_search = '%' . $search . '%';
            $params[] = $prefix_search;
            $params[] = $prefix_search;
            $params[] = $fuzzy_search;
            $params[] = $fuzzy_search;
            $types .= 'ssss';
            
            // Smart ordering for text search
            $order_by = "CASE 
                            WHEN l.Name LIKE '$prefix_search' THEN 1
                            WHEN l.Surname LIKE '$prefix_search' THEN 2
                            WHEN CONCAT(l.Name, ' ', l.Surname) LIKE '$prefix_search' THEN 3
                            ELSE 4
                         END, l.Name, l.Surname";
        }
    }
    
    if (!empty($site_filter)) {
        $additional_conditions[] = "si.siteName = ?";
        $params[] = $site_filter;
        $types .= 's';
    }
    
    if (!empty($class_filter)) {
        $additional_conditions[] = "c.className = ?";
        $params[] = $class_filter;
        $types .= 's';
    }

    // Combine all conditions
    $where_clause = $sdp_condition;
    if (!empty($additional_conditions)) {
        $where_clause .= " AND " . implode(" AND ", $additional_conditions);
    }

    // First, get the total count (only when needed for performance)
    $total_records = 0;
    $total_pages = 0;
    
    if ($page === 1 || !empty($search)) {
        $count_sql = "SELECT COUNT(DISTINCT l.LearnerID) as total
                      FROM learnerdetails l
                      LEFT JOIN class c ON l.classID = c.classID
                      LEFT JOIN sites si ON c.siteID = si.siteID
                      LEFT JOIN sdp s ON si.sdp_id = s.sdp_id
                      WHERE $where_clause";

        $count_stmt = $conn->prepare($count_sql);
        if (!empty($params)) {
            $count_stmt->bind_param($types, ...$params);
        }
        $count_stmt->execute();
        $count_result = $count_stmt->get_result();
        $total_records = $count_result->fetch_assoc()['total'];
        $total_pages = ceil($total_records / $limit);
        $count_stmt->close();
    }

    // Now get the paginated data with smart ordering
    $data_sql = "SELECT DISTINCT
                    l.LearnerID,
                    l.Name,
                    l.Surname,
                    l.IDNumber,
                    l.classID,
                    c.className,
                    si.siteName,
                    s.sdp_name,
                    l.PhoneNumber,
                    l.Email,
                    l.synced
                 FROM learnerdetails l
                 LEFT JOIN class c ON l.classID = c.classID
                 LEFT JOIN sites si ON c.siteID = si.siteID
                 LEFT JOIN sdp s ON si.sdp_id = s.sdp_id
                 WHERE $where_clause
                 ORDER BY $order_by
                 LIMIT ? OFFSET ?";

    // Add limit and offset parameters
    $params[] = $limit;
    $params[] = $offset;
    $types .= 'ii';

    $data_stmt = $conn->prepare($data_sql);
    if (!empty($params)) {
        $data_stmt->bind_param($types, ...$params);
    }
    $data_stmt->execute();
    $data_result = $data_stmt->get_result();

    $learners = [];
    while ($row = $data_result->fetch_assoc()) {
        // Clean up null values and ensure consistent data format
        $learner = [];
        foreach ($row as $key => $value) {
            $learner[$key] = $value ?? '';
        }
        $learners[] = $learner;
    }

    // Get available filter options for the current SDP (cached for performance)
    $available_sites = [];
    $available_classes = [];
    
    if ($page === 1) { // Only fetch filter options on first page load
        $sites_sql = "SELECT DISTINCT si.siteName
                      FROM learnerdetails l
                      LEFT JOIN class c ON l.classID = c.classID
                      LEFT JOIN sites si ON c.siteID = si.siteID
                      LEFT JOIN sdp s ON si.sdp_id = s.sdp_id
                      WHERE $sdp_condition AND si.siteName IS NOT NULL
                      ORDER BY si.siteName";

        $sites_stmt = $conn->prepare($sites_sql);
        if ($sdp_id) {
            $sites_stmt->bind_param('i', $sdp_id);
        } else {
            $sites_stmt->bind_param('s', $sdp_name);
        }
        $sites_stmt->execute();
        $sites_result = $sites_stmt->get_result();
        
        while ($row = $sites_result->fetch_assoc()) {
            $available_sites[] = $row['siteName'];
        }

        $classes_sql = "SELECT DISTINCT c.className
                        FROM learnerdetails l
                        LEFT JOIN class c ON l.classID = c.classID
                        LEFT JOIN sites si ON c.siteID = si.siteID
                        LEFT JOIN sdp s ON si.sdp_id = s.sdp_id
                        WHERE $sdp_condition AND c.className IS NOT NULL
                        ORDER BY c.className";

        $classes_stmt = $conn->prepare($classes_sql);
        if ($sdp_id) {
            $classes_stmt->bind_param('i', $sdp_id);
        } else {
            $classes_stmt->bind_param('s', $sdp_name);
        }
        $classes_stmt->execute();
        $classes_result = $classes_stmt->get_result();
        
        while ($row = $classes_result->fetch_assoc()) {
            $available_classes[] = $row['className'];
        }
        
        $sites_stmt->close();
        $classes_stmt->close();
    }

    $queryTime = round((microtime(true) - $startTime) * 1000, 2);

    // Return enhanced paginated response with smart search metadata
    echo json_encode([
        'status' => 'success',
        'data' => $learners,
        'pagination' => [
            'current_page' => $page,
            'total_pages' => $total_pages,
            'total_records' => $total_records,
            'per_page' => $limit,
            'has_next' => $page < $total_pages,
            'has_prev' => $page > 1
        ],
        'filters' => [
            'available_sites' => $available_sites,
            'available_classes' => $available_classes
        ],
        'search' => [
            'query' => $search,
            'is_smart_search' => !empty($search),
            'search_type' => !empty($search) ? (is_numeric($search) ? 'numeric' : 'text') : null,
            'result_count' => count($learners)
        ],
        'meta' => [
            'query_time_ms' => $queryTime,
            'smart_search_enabled' => true,
            'version' => '2.0'
        ]
    ]);

    $data_stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error', 
        'message' => 'Server error: ' . $e->getMessage(),
        'meta' => [
            'smart_search_enabled' => false,
            'error_code' => $e->getCode()
        ]
    ]);
}

$conn->close();
?>