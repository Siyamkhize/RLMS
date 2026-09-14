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
    $query = isset($_GET['q']) ? trim($_GET['q']) : '';
    $classID = isset($_GET['classID']) ? trim($_GET['classID']) : '';
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 10;
    
    if (strlen($query) < 2) {
        echo json_encode([
            'success' => true,
            'suggestions' => []
        ]);
        exit;
    }
    
    // Build autocomplete query - optimized for speed
    $sql = "
        SELECT DISTINCT
            l.LearnerID,
            l.Name,
            l.Surname,
            l.IDNumber,
            CONCAT(l.Name, ' ', l.Surname) as full_name
        FROM learnerdetails l
        WHERE 1=1
    ";
    
    $params = [];
    $types = '';
    
    // Add class filter if provided
    if (!empty($classID)) {
        $sql .= " AND l.classID = ?";
        $params[] = $classID;
        $types .= 's';
    }
    
    // Add search conditions - prioritize exact matches
    $sql .= " AND (
        l.IDNumber LIKE ? OR
        l.Name LIKE ? OR
        l.Surname LIKE ? OR
        CONCAT(l.Name, ' ', l.Surname) LIKE ?
    )";
    
    $searchPattern = $query . '%'; // Prefix search for better performance
    $params = array_merge($params, [$searchPattern, $searchPattern, $searchPattern, $searchPattern]);
    $types .= 'ssss';
    
    // Order by relevance - exact matches first
    $sql .= " ORDER BY
        (l.IDNumber = ?) DESC,
        (l.Name = ?) DESC,
        (l.Surname = ?) DESC,
        LENGTH(l.Name),
        l.Name,
        l.Surname
        LIMIT ?";
    
    $params = array_merge($params, [$query, $query, $query, $limit]);
    $types .= 'sssi';
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $suggestions = [];
    while ($row = $result->fetch_assoc()) {
        $suggestions[] = [
            'id' => $row['LearnerID'],
            'text' => $row['full_name'] . ' (' . $row['IDNumber'] . ')',
            'name' => $row['Name'],
            'surname' => $row['Surname'],
            'id_number' => $row['IDNumber']
        ];
    }
    
    $stmt->close();
    
    echo json_encode([
        'success' => true,
        'suggestions' => $suggestions,
        'query' => $query
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Autocomplete error: ' . $e->getMessage(),
        'suggestions' => []
    ]);
}

$conn->close();
?>