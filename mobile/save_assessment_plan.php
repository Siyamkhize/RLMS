<?php
include 'connection.php'; // Ensure database connection is included only once
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json; charset=UTF-8');

// Handle preflight OPTIONS request
if ($_SERVER["REQUEST_METHOD"] == "OPTIONS") {
    http_response_code(200);
    exit;
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Get raw JSON input from Flutter
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    // Check if JSON decoding was successful
    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid JSON input: ' . json_last_error_msg()]);
        exit;
    }

    // Extract data from JSON payload
    $assessment_date = $data['assessment_date'] ?? null;
    $start_date = $data['start_date'] ?? null;
    $end_date = $data['end_date'] ?? null;
    $venue = $data['venue'] ?? null;
    $contact_person = $data['contact_person'] ?? null;
    $language_medium = $data['language_medium'] ?? null;
    $assessment_method = $data['assessment_method'] ?? null;
    $facilitator_id = $data['facilitator_id'] ?? null;
    $unitstandard_id = $data['unitstandard_id'] ?? null;

    // Validate required fields
    if (!$assessment_date || !$start_date || !$end_date || !$venue || !$contact_person || !$language_medium || !$assessment_method || !$facilitator_id || !$unitstandard_id) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Missing required fields']);
        exit;
    }

    // Check if combination already exists
    $check_query = "SELECT COUNT(*) as count FROM assessment_plan WHERE unitstandard_id = ? AND facilitator_id = ?";
    $check_stmt = $conn->prepare($check_query);
    if (!$check_stmt) {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Check prepare failed: ' . $conn->error]);
        exit;
    }
    $check_stmt->bind_param("ss", $unitstandard_id, $facilitator_id);
    $check_stmt->execute();
    $result = $check_stmt->get_result();
    $row = $result->fetch_assoc();
    $check_stmt->close();

    if ($row['count'] > 0) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => "Record with unitstandard_id $unitstandard_id and facilitator_id $facilitator_id already exists"]);
        exit;
    }

    // Prepare SQL statement
    $sql = "INSERT INTO assessment_plan (assessment_date, start_date, end_date, venue, contact_person, language_medium, assessment_method, facilitator_id, unitstandard_id) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";

    if ($stmt = $conn->prepare($sql)) {
        $stmt->bind_param("sssssssss", $assessment_date, $start_date, $end_date, $venue, $contact_person, $language_medium, $assessment_method, $facilitator_id, $unitstandard_id);

        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'Assessment plan saved successfully']);
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Error: Unable to save data - ' . $stmt->error]);
        }

        $stmt->close();
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $conn->error]);
    }
} else {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
}

$conn->close();
?>