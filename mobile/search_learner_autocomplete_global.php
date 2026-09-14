<?php
/**
 * Ultra-Fast Autocomplete Search (Optimized for Large Datasets)
 * - Prefix search only (index friendly)
 * - Smart detection: ID vs Name
 * - No full table scan
 * - Hard limit protection
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

// -----------------------------
// 1️⃣ Get & Validate Inputs
// -----------------------------
$query = isset($_GET['q']) ? trim($_GET['q']) : '';
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 10;

// Protect against abuse
$limit = min(max($limit, 1), 20);

if (empty($query) || strlen($query) < 2) {
    echo json_encode([
        'success' => false,
        'suggestions' => []
    ]);
    exit;
}

try {

    // -----------------------------
    // 2️⃣ Smart Search Routing
    // -----------------------------
    // If numeric → prioritize ID search
    if (ctype_digit($query)) {

        $sql = "
            SELECT 
                LearnerID as learner_id,
                Name as name,
                Surname as surname,
                IDNumber as id_number,
                classID as class_id
            FROM learnerdetails
            WHERE IDNumber LIKE ?
            ORDER BY IDNumber
            LIMIT ?
        ";

        $searchParam = $query . '%';

        $stmt = $conn->prepare($sql);
        $stmt->bind_param('si', $searchParam, $limit);

    } else {

        // Name / Surname prefix search
        $sql = "
            SELECT 
                LearnerID as learner_id,
                Name as name,
                Surname as surname,
                IDNumber as id_number,
                classID as class_id
            FROM learnerdetails
            WHERE Surname LIKE ?
               OR Name LIKE ?
            ORDER BY Surname, Name
            LIMIT ?
        ";

        $searchParam = $query . '%';

        $stmt = $conn->prepare($sql);
        $stmt->bind_param('ssi', $searchParam, $searchParam, $limit);
    }

    // -----------------------------
    // 3️⃣ Execute Query
    // -----------------------------
    $stmt->execute();
    $result = $stmt->get_result();

    $suggestions = [];

    while ($row = $result->fetch_assoc()) {
        $suggestions[] = [
            'learner_id' => $row['learner_id'],
            'name' => $row['name'],
            'surname' => $row['surname'],
            'id_number' => $row['id_number'],
            'class_id' => $row['class_id'],
            'display' => $row['surname'] . ', ' . $row['name'] . ' (' . $row['id_number'] . ')'
        ];
    }

    $stmt->close();

    echo json_encode([
        'success' => true,
        'suggestions' => $suggestions,
        'count' => count($suggestions)
    ]);

} catch (Exception $e) {

    echo json_encode([
        'success' => false,
        'suggestions' => []
    ]);
}

$conn->close();
?>