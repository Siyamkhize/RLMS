<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'connection.php';

try {
    $projectId = $_GET['projectId'] ?? '';
    $search = $_GET['search'] ?? '';
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 100;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;
    
    if (empty($projectId)) {
        throw new Exception('Project ID is required');
    }

    // Build search condition
    $searchCondition = '';
    $searchParams = [];
    $paramTypes = 'i'; // projectId is integer
    $paramValues = [$projectId];
    
    if (!empty($search)) {
        $searchTerm = '%' . $search . '%';
        $searchCondition = " AND (
            ld.Name LIKE ? 
            OR ld.Surname LIKE ? 
            OR ld.IDNumber LIKE ?
            OR ld.PhoneNumber LIKE ?
            OR ld.Email LIKE ?
            OR CONCAT(ld.Name, ' ', ld.Surname) LIKE ?
            OR CONCAT(ld.Surname, ' ', ld.Name) LIKE ?
        )";
        
        // Add search params (7 times for each LIKE)
        $searchParams = array_fill(0, 7, $searchTerm);
        $paramTypes .= str_repeat('s', 7);
        $paramValues = array_merge($paramValues, $searchParams);
    }

    // Get learners who are IN learner_assignments for this project but NOT assigned to a class
    $sql = "
        SELECT DISTINCT
            ld.LearnerID,
            ld.Name,
            ld.Surname,
            ld.IDNumber,
            ld.PhoneNumber,
            ld.Email
        FROM learnerdetails ld
        INNER JOIN learner_assignments ls 
            ON ld.LearnerID = ls.LearnerID
        WHERE ls.projectID = ?
        AND ld.classID IS NULL
        $searchCondition
        ORDER BY ld.Surname ASC, ld.Name ASC
        LIMIT ? OFFSET ?
    ";

    $stmt = $conn->prepare($sql);
    
    // Add limit and offset
    $paramTypes .= 'ii';
    $paramValues[] = $limit;
    $paramValues[] = $offset;
    
    // Bind parameters dynamically
    $stmt->bind_param($paramTypes, ...$paramValues);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $learners = [];
    while ($row = $result->fetch_assoc()) {
        $learners[] = $row;
    }
    
    $stmt->close();

    echo json_encode([
        'success' => true,
        'learners' => $learners,
        'count' => count($learners),
        'search' => $search,
        'limit' => $limit,
        'offset' => $offset
    ]);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
