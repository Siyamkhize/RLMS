<?php
require_once 'connection.php';

error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Use the connection from connection.php (already defined as $conn)

if (isset($_POST['learner_id']) && isset($_POST['field']) && isset($_POST['value'])) {
    $learner_id = trim($_POST['learner_id']);
    $field = $_POST['field'];
    $value = trim($_POST['value']);

    // Only allow specific fields to be updated
    $valid_fields = ['learner_initials', 'witness_initials'];
    if (!in_array($field, $valid_fields)) {
        error_log("Invalid field name: $field");
        echo json_encode(['success' => false, 'message' => 'Invalid field name']);
        $conn->close();
        exit();
    }

    // Check if learner exists
    $check_query = "SELECT 1 FROM learnerdetails WHERE LearnerID = ?";
    $check_stmt = $conn->prepare($check_query);
    $check_stmt->bind_param("i", $learner_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();

    if ($check_result->num_rows === 0) {
        echo json_encode(['success' => false, 'message' => 'Learner does not exist']);
        $check_stmt->close();
        $conn->close();
        exit();
    }
    $check_stmt->close();

    // Prepare update query
    $sql = "UPDATE learnerdetails SET $field = ? WHERE LearnerID = ?";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        echo json_encode(['success' => false, 'message' => 'Failed to prepare statement: ' . $conn->error]);
        $conn->close();
        exit();
    }

    $stmt->bind_param("si", $value, $learner_id);

    if ($stmt->execute()) {
        error_log("Initials saved: field=$field, value=$value, learner_id=$learner_id");
        echo json_encode(['success' => true, 'message' => "$field updated successfully", 'value' => $value]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Execution failed: ' . $stmt->error]);
    }

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'Invalid request: learner_id, field, or value missing']);
}

$conn->close();
?>
