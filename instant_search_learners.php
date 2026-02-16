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
    $classID = $_GET['classID'] ?? $_POST['classID'] ?? null;
    $query = trim($_GET['q'] ?? $_POST['q'] ?? '');
    $limit = min((int)($_GET['limit'] ?? $_POST['limit'] ?? 10), 20); // Max 20 for instant search

    if (!$classID) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'classID parameter is required']);
        exit;
    }

    // Return empty results for very short queries to avoid too many results
    if (strlen($query) < 2) {
        echo json_encode([
            'status' => 'success',
            'data' => [],
            'meta' => [
                'query' => $query,
                'resultCount' => 0,
                'message' => 'Please enter at least 2 characters to search'
            ]
        ]);
        exit;
    }

    // Ultra-minimal fields for instant search - only what's needed for display
    $fields = "l.LearnerID, l.Name, l.Surname, l.IDNumber";

    // Optimized query with LIMIT to prevent large result sets
    $sql = "SELECT $fields
            FROM learnerdetails l
            WHERE l.classID = ? 
            AND (l.Name LIKE ? OR l.Surname LIKE ? OR l.IDNumber LIKE ?)
            ORDER BY 
                CASE 
                    WHEN l.IDNumber LIKE ? THEN 1
                    WHEN l.Name LIKE ? THEN 2
                    WHEN l.Surname LIKE ? THEN 3
                    ELSE 4
                END,
                l.Name, l.Surname
            LIMIT ?";

    $searchTerm = "%{$query}%";
    $exactStart = "{$query}%"; // For prioritizing results that start with the query
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssssssi", 
        $classID, 
        $searchTerm, $searchTerm, $searchTerm,  // Main search terms
        $exactStart, $exactStart, $exactStart,  // Priority ordering
        $limit
    );
    
    $stmt->execute();
    $result = $stmt->get_result();

    $suggestions = [];
    while ($row = $result->fetch_assoc()) {
        $suggestions[] = [
            'id' => $row['LearnerID'],
            'name' => trim(($row['Name'] ?? '') . ' ' . ($row['Surname'] ?? '')),
            'idNumber' => $row['IDNumber'] ?? '',
            'displayText' => trim(($row['Name'] ?? '') . ' ' . ($row['Surname'] ?? '')) . 
                           (($row['IDNumber'] ?? '') ? ' (' . $row['IDNumber'] . ')' : '')
        ];
    }

    $responseTime = round((microtime(true) - $startTime) * 1000, 2);

    echo json_encode([
        'status' => 'success',
        'data' => $suggestions,
        'meta' => [
            'query' => $query,
            'resultCount' => count($suggestions),
            'responseTime' => $responseTime . 'ms',
            'limit' => $limit
        ]
    ]);

    $stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error', 
        'message' => 'Search error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>