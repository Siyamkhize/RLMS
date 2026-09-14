<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Database configuration
include'connection.php';
// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Connection failed: ' . $conn->connect_error]);
    exit;
}

try {
    // Read JSON input from the request body
    $input = json_decode(file_get_contents('php://input'), true);

    // Validate input
    if (!isset($input['classID']) || empty(trim($input['classID']))) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'classID is required']);
        exit;
    }

    $classID = trim($input['classID']);

    // Prepare and execute query to fetch learners
    $stmt = $conn->prepare('SELECT classID, LearnerID, Name, Surname,IDNumber,Age,Gender
                           FROM learnerdetails 
                           WHERE classID = ?');
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }

    $stmt->bind_param('s', $classID);
    $stmt->execute();
    $result = $stmt->get_result();

    // Fetch all learners as an associative array
    $learners = [];
    while ($row = $result->fetch_assoc()) {
        $learners[] = [
            'classID' => $row['classID'] ?? '',
            'LearnerID' => $row['LearnerID'] ?? 0,
            'Name' => $row['Name'] ?? '',
            'Surname' => $row['Surname'] ?? '',
            'IDNumber' => $row['IDNumber'] ?? '',
            'Age' => $row['Age'] ?? '',
            'Gender' => $row['Gender'] ?? '',
        ];
    }

    $stmt->close();

    // Return success response with learners
    echo json_encode([
        'success' => true,
        'learners' => $learners
    ]);

} catch (Exception $e) {
    // Handle errors
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Server error: ' . $e->getMessage()]);
} finally {
    $conn->close();
}
?>