<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

try {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);

    if (!$data || !isset($data['records']) || !is_array($data['records'])) {
        throw new Exception('Invalid data format');
    }

    $records = $data['records'];
    $synced_count = 0;
    $failed_count = 0;
    $errors = [];

    foreach ($records as $record) {
        try {
            // Validate required fields
            if (!isset($record['learner_id']) || !isset($record['conti_suits_size']) && !isset($record['safety_boots_size'])) {
                $failed_count++;
                $errors[] = "Missing required fields for learner_id: " . ($record['learner_id'] ?? 'unknown');
                continue;
            }

            $learner_id = intval($record['learner_id']);
            $conti_suits_size = $record['conti_suits_size'] ?? null;
            $safety_boots_size = $record['safety_boots_size'] ?? null;

            // Check if record exists
            $check_sql = "SELECT id, conti_suits_size, safety_boots_size FROM poe_sizes WHERE learner_id = ?";
            $check_stmt = $conn->prepare($check_sql);
            $check_stmt->bind_param('i', $learner_id);
            $check_stmt->execute();
            $existing = $check_stmt->get_result()->fetch_assoc();
            $check_stmt->close();

            if ($existing) {
                // Update existing record
                $update_sql = "UPDATE poe_sizes 
                               SET conti_suits_size = ?,
                                   safety_boots_size = ?,
                                   updated_at = CURRENT_TIMESTAMP
                               WHERE learner_id = ?";
                
                $update_stmt = $conn->prepare($update_sql);
                $update_stmt->bind_param('ssi',
                    $conti_suits_size,
                    $safety_boots_size,
                    $learner_id
                );
                
                if ($update_stmt->execute()) {
                    $synced_count++;
                } else {
                    $failed_count++;
                    $errors[] = "Failed to update learner_id $learner_id: " . $update_stmt->error;
                }
                $update_stmt->close();
            } else {
                // Insert new record
                $insert_sql = "INSERT INTO poe_sizes 
                               (learner_id, conti_suits_size, safety_boots_size, created_at)
                               VALUES (?, ?, ?, CURRENT_TIMESTAMP)";
                
                $insert_stmt = $conn->prepare($insert_sql);
                $insert_stmt->bind_param('iss',
                    $learner_id,
                    $conti_suits_size,
                    $safety_boots_size
                );
                
                if ($insert_stmt->execute()) {
                    $synced_count++;
                } else {
                    $failed_count++;
                    $errors[] = "Failed to insert learner_id $learner_id: " . $insert_stmt->error;
                }
                $insert_stmt->close();
            }
        } catch (Exception $e) {
            $failed_count++;
            $errors[] = "Error processing learner_id " . ($record['learner_id'] ?? 'unknown') . ": " . $e->getMessage();
        }
    }

    echo json_encode([
        'status' => 'success',
        'synced' => $synced_count,
        'failed' => $failed_count,
        'errors' => $errors,
        'message' => "Synced $synced_count records, $failed_count failed"
    ]);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
