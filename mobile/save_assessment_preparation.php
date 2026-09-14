<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json; charset=UTF-8');

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', 'C:/Apache24/logs/php_errors.log');

if ($_SERVER["REQUEST_METHOD"] == "OPTIONS") {
    http_response_code(200);
    exit;
}

if ($_SERVER["REQUEST_METHOD"] != "POST") {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit;
}

// Helper function to create references (defined outside try block)
function ref(&$val) {
    return $val;
}

try {
    if (!file_exists('connection.php')) {
        throw new Exception("connection.php not found");
    }
    include 'connection.php';
    error_log("Connection file included");

    if (!$conn || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn ? $conn->connect_error : "No connection object"));
    }
    error_log("Database connection successful");

    $input = file_get_contents("php://input");
    error_log("Raw input: " . $input);

    $data = json_decode($input, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Invalid JSON input: ' . json_last_error_msg());
    }
    error_log("Decoded payload: " . json_encode($data));

    $unitstandard_id = $data['unitstandard_id'] ?? null;
    $facilitator_id = $data['facilitator_id'] ?? null;
    if (!$unitstandard_id || !$facilitator_id) {
        throw new Exception('Missing unitstandard_id or facilitator_id');
    }

    // Check if combination already exists
    $check_query = "SELECT COUNT(*) as count FROM assessment_preparation WHERE unitstandard_id = ? AND facilitator_id = ?";
    $check_stmt = $conn->prepare($check_query);
    if (!$check_stmt) {
        throw new Exception("Check prepare failed: " . $conn->error);
    }
    $check_stmt->bind_param("ss", $unitstandard_id, $facilitator_id);
    $check_stmt->execute();
    $result = $check_stmt->get_result();
    $row = $result->fetch_assoc();
    $check_stmt->close();

    if ($row['count'] > 0) {
        throw new Exception("Record with unitstandard_id $unitstandard_id and facilitator_id $facilitator_id already exists");
    }

    $agree_meeting_purpose = isset($data['agree_meeting_purpose']) ? ($data['agree_meeting_purpose'] ? 1 : 0) : 0;
    $agree_assessment_plan = isset($data['agree_assessment_plan']) ? ($data['agree_assessment_plan'] ? 1 : 0) : 0;
    $agree_assessment_process = isset($data['agree_assessment_process']) ? ($data['agree_assessment_process'] ? 1 : 0) : 0;
    $agree_role_players = isset($data['agree_role_players']) ? ($data['agree_role_players'] ? 1 : 0) : 0;
    $agree_evidence = isset($data['agree_evidence']) ? ($data['agree_evidence'] ? 1 : 0) : 0;
    $agree_judgment = isset($data['agree_judgment']) ? ($data['agree_judgment'] ? 1 : 0) : 0;
    $agree_summative_task = isset($data['agree_summative_task']) ? ($data['agree_summative_task'] ? 1 : 0) : 0;
    $agree_bring_requirements = isset($data['agree_bring_requirements']) ? ($data['agree_bring_requirements'] ? 1 : 0) : 0;
    $agree_understands_procedures = isset($data['agree_understands_procedures']) ? ($data['agree_understands_procedures'] ? 1 : 0) : 0;
    $agree_understands_assessment = isset($data['agree_understands_assessment']) ? ($data['agree_understands_assessment'] ? 1 : 0) : 0;
    $action_meeting_purpose = $data['action_meeting_purpose'] ?? '';
    $action_assessment_plan = $data['action_assessment_plan'] ?? '';
    $action_assessment_process = $data['action_assessment_process'] ?? '';
    $action_role_players = $data['action_role_players'] ?? '';
    $action_evidence = $data['action_evidence'] ?? '';
    $action_judgment = $data['action_judgment'] ?? '';
    $action_summative_task = $data['action_summative_task'] ?? '';
    $action_bring_requirements = $data['action_bring_requirements'] ?? '';
    $action_understands_procedures = $data['action_understands_procedures'] ?? '';
    $action_understands_assessment = $data['action_understands_assessment'] ?? '';

    $query = "
        INSERT INTO assessment_preparation (
            unitstandard_id, facilitator_id, agree_meeting_purpose, agree_assessment_plan, 
            agree_assessment_process, agree_role_players, agree_evidence, agree_judgment, 
            agree_summative_task, agree_bring_requirements, agree_understands_procedures, 
            agree_understands_assessment, action_meeting_purpose, action_assessment_plan, 
            action_assessment_process, action_role_players, action_evidence, action_judgment, 
            action_summative_task, action_bring_requirements, action_understands_procedures, 
            action_understands_assessment
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ";
    error_log("Query: $query");

    $stmt = $conn->prepare($query);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    error_log("Statement prepared");

    $types = "ssiiiiiiiiisssssssssss";
    $params = [
        &$unitstandard_id,
        &$facilitator_id,
        &$agree_meeting_purpose,
        &$agree_assessment_plan,
        &$agree_assessment_process,
        &$agree_role_players,
        &$agree_evidence,
        &$agree_judgment,
        &$agree_summative_task,
        &$agree_bring_requirements,
        &$agree_understands_procedures,
        &$agree_understands_assessment,
        &$action_meeting_purpose,
        &$action_assessment_plan,
        &$action_assessment_process,
        &$action_role_players,
        &$action_evidence,
        &$action_judgment,
        &$action_summative_task,
        &$action_bring_requirements,
        &$action_understands_procedures,
        &$action_understands_assessment
    ];
    error_log("Binding parameters - Types: $types, Params count: " . count($params));

    $bindResult = call_user_func_array([$stmt, 'bind_param'], array_merge([$types], $params));
    if ($bindResult === false) {
        throw new Exception("Bind param failed: " . $stmt->error);
    }
    error_log("Parameters bound successfully");

    if ($stmt->execute()) {
        echo json_encode(['status' => 'success', 'message' => 'Form saved successfully']);
        error_log("Form saved successfully");
    } else {
        throw new Exception("Execute failed: " . $stmt->error);
    }

    $stmt->close();
    $conn->close();
} catch (Exception $e) {
    http_response_code(500);
    $errorMessage = "Error: " . $e->getMessage();
    error_log($errorMessage);
    echo json_encode(['status' => 'error', 'message' => $errorMessage]);
} catch (Error $e) {
    http_response_code(500);
    $errorMessage = "Fatal error: " . $e->getMessage();
    error_log($errorMessage);
    echo json_encode(['status' => 'error', 'message' => $errorMessage]);
} finally {
    if (isset($stmt) && $stmt instanceof mysqli_stmt) $stmt->close();
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) $conn->close();
}

exit;
?>