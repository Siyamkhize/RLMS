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
    $start_time = microtime(true);
    
    // Get parameters
    $sdp_id = $_GET['sdp_id'] ?? null;
    $sdp_name = $_GET['sdp_name'] ?? null;
    $search = trim($_GET['search'] ?? '');
    $limit = min(10, max(5, intval($_GET['limit'] ?? 8))); // Between 5-10 suggestions

    // Validate SDP identifier
    if (!$sdp_id && !$sdp_name) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'sdp_id or sdp_name parameter is required']);
        exit;
    }

    // Must have search term
    if (empty($search)) {
        echo json_encode([
            'status' => 'success',
            'suggestions' => [],
            'meta' => [
                'search_query' => '',
                'result_count' => 0,
                'query_time_ms' => 0
            ]
        ]);
        exit;
    }

    // Build the WHERE clause for SDP filtering
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

    // Clean search input - remove brackets and extra spaces
    $cleanSearch = preg_replace('/[^\w\s]/', '', $search);
    $cleanSearch = trim($cleanSearch);
    
    // Build search conditions with smart matching
    $search_conditions = [];
    
    if (is_numeric($cleanSearch)) {
        // Numeric search - prioritize ID number matches
        $search_conditions[] = "(l.IDNumber LIKE ? OR l.PhoneNumber LIKE ? OR l.Name LIKE ? OR l.Surname LIKE ?)";
        $exact_search = $cleanSearch . '%';
        $fuzzy_search = '%' . $cleanSearch . '%';
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
        $search_conditions[] = "(l.Name LIKE ? OR l.Surname LIKE ? OR CONCAT(l.Name, ' ', l.Surname) LIKE ? OR l.IDNumber LIKE ?)";
        $prefix_search = $cleanSearch . '%';
        $fuzzy_search = '%' . $cleanSearch . '%';
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
                        WHEN l.Name LIKE '$fuzzy_search' THEN 4
                        WHEN l.Surname LIKE '$fuzzy_search' THEN 5
                        ELSE 6
                    END, l.Name, l.Surname";
    }

    // Combine all conditions
    $where_clause = $sdp_condition . " AND " . implode(" AND ", $search_conditions);

    // Get autocomplete suggestions
    $sql = "SELECT DISTINCT
                l.LearnerID,
                l.Name,
                l.Surname,
                l.IDNumber,
                l.classID,
                c.className,
                si.siteName
             FROM learnerdetails l
             LEFT JOIN class c ON l.classID = c.classID
             LEFT JOIN sites si ON c.siteID = si.siteID
             LEFT JOIN sdp s ON si.sdp_id = s.sdp_id
             WHERE $where_clause
             ORDER BY $order_by
             LIMIT ?";

    // Add limit parameter
    $params[] = $limit;
    $types .= 'i';

    $stmt = $conn->prepare($sql);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();

    $suggestions = [];
    while ($row = $result->fetch_assoc()) {
        // Clean up data
        $idNumber = preg_replace('/[^\d]/', '', $row['IDNumber'] ?? '');
        $idNumber = trim($idNumber);
        $name = trim($row['Name'] ?? '');
        $surname = trim($row['Surname'] ?? '');
        $className = trim($row['className'] ?? 'N/A');
        $siteName = trim($row['siteName'] ?? 'N/A');
        
        // Create display text: "Surname Name (ID Number)"
        $displayText = "$surname $name ($idNumber)";
        
        // Create shorter version if too long
        if (strlen($displayText) > 50) {
            $shortSiteName = strlen($siteName) > 15 ? substr($siteName, 0, 15) . '...' : $siteName;
            $displayText = "$surname $name ($idNumber)";
        }
        
        $suggestion = [
            'id' => $row['LearnerID'],
            'display_text' => $displayText,
            'search_value' => $idNumber, // This is what gets put in search field when clicked
            'name' => $name,
            'surname' => $surname,
            'id_number' => $idNumber,
            'class_name' => $className,
            'site_name' => $siteName,
            'match_type' => is_numeric($cleanSearch) ? 'id' : 'name'
        ];
        
        $suggestions[] = $suggestion;
    }

    $query_time = round((microtime(true) - $start_time) * 1000, 2);

    echo json_encode([
        'status' => 'success',
        'suggestions' => $suggestions,
        'meta' => [
            'search_query' => $cleanSearch,
            'original_search' => $search,
            'search_type' => is_numeric($cleanSearch) ? 'numeric' : 'text',
            'result_count' => count($suggestions),
            'query_time_ms' => $query_time,
            'limit' => $limit
        ]
    ]);

    $stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error', 
        'message' => 'Server error: ' . $e->getMessage(),
        'meta' => [
            'query_time_ms' => round((microtime(true) - ($start_time ?? microtime(true))) * 1000, 2)
        ]
    ]);
}

$conn->close();
?>