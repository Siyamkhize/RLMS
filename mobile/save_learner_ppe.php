<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

try {
    // Get JSON input
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);

    if (!$data) {
        throw new Exception('Invalid JSON data');
    }

    // Validate required fields
    if (!isset($data['LearnerID']) || empty($data['LearnerID'])) {
        throw new Exception("Missing required field: LearnerID");
    }

    // Prepare data
    $learner_id = intval($data['LearnerID']);
    $learner_name = $data['learner_name'] ?? '';
    $class_id = $data['classID'] ?? '';
    $conti_suit_size = $data['conti_suit_size'] ?? null;
    $conti_suit_quantity = intval($data['conti_suit_quantity'] ?? 0);
    $boots_size = $data['boots_size'] ?? null;
    $boots_quantity = intval($data['boots_quantity'] ?? 0);
    $issued_date = $data['issued_date'] ?? date('Y-m-d H:i:s');
    
    // Get the representative name (facilitator or logistics user who issued the PPE)
    $representative_name = $data['facilitator_name'] ?? $data['logistics_name'] ?? $data['issued_by'] ?? 'Facilitator';

    $message = "PPE issued successfully";

    // Get learner's IDNumber and class name from learnerdetails table
    $student_id_number = '';
    $class_name = 'Unknown Class';
    
    $learner_query = "SELECT l.IDNumber, c.className 
                      FROM learnerdetails l 
                      LEFT JOIN class c ON l.classID = c.classID 
                      WHERE l.LearnerID = ?";
    $learner_stmt = $conn->prepare($learner_query);
    $learner_stmt->bind_param('i', $learner_id);
    $learner_stmt->execute();
    $learner_result = $learner_stmt->get_result()->fetch_assoc();
    if ($learner_result) {
        $student_id_number = $learner_result['IDNumber'];
        $class_name = $learner_result['className'] ?? 'Unknown Class';
    }
    $learner_stmt->close();

    // Build combined sub_description for PPE items
    $ppe_items = [];
    if (!empty($conti_suit_size) && $conti_suit_quantity > 0) {
        $ppe_items[] = "Conti-Suit: $conti_suit_size";
    }
    if (!empty($boots_size) && $boots_quantity > 0) {
        $ppe_items[] = "Safety Boots: $boots_size";
    }

    // Only save if there are PPE items
    if (!empty($ppe_items)) {
        $combined_sub_description = implode(", ", $ppe_items);
        $total_quantity = $conti_suit_quantity + $boots_quantity;

        // Check if record exists in material_receipt_form
        $check_receipt_sql = "SELECT id FROM material_receipt_form 
                              WHERE student_id_number = ? AND description = 'PPE'";
        $check_receipt_stmt = $conn->prepare($check_receipt_sql);
        $check_receipt_stmt->bind_param('s', $student_id_number);
        $check_receipt_stmt->execute();
        $check_receipt_result = $check_receipt_stmt->get_result();

        if ($check_receipt_result->num_rows > 0) {
            // Update existing record
            $update_receipt_sql = "UPDATE material_receipt_form 
                                   SET student_full_name = ?,
                                       class_name = ?,
                                       quantity = ?,
                                       sub_description = ?,
                                       date_received = CURDATE(),
                                       representative_name = ?,
                                       updated_at = CURRENT_TIMESTAMP
                                   WHERE student_id_number = ? AND description = 'PPE'";
            
            $update_receipt_stmt = $conn->prepare($update_receipt_sql);
            $update_receipt_stmt->bind_param('ssiss',
                $learner_name,
                $class_name,
                $total_quantity,
                $combined_sub_description,
                $representative_name,  // Use facilitator/logistics name, NOT learner name
                $student_id_number
            );
            $update_receipt_stmt->execute();
            $update_receipt_stmt->close();
        } else {
            // Insert new record
            $insert_receipt_sql = "INSERT INTO material_receipt_form 
                                   (student_id_number, student_full_name, class_name, received, quantity, 
                                    description, sub_description, date_received, representative_name, 
                                    date_aor_created, synced, created_at)
                                   VALUES (?, ?, ?, ?, ?, ?, ?, CURDATE(), ?, CURDATE(), 0, CURRENT_TIMESTAMP)";
            
            // PHP 8+ requires all bind_param arguments to be variables, not literals
            $received_status = 'Yes';
            $material_type = 'PPE';
            
            $insert_receipt_stmt = $conn->prepare($insert_receipt_sql);
            $insert_receipt_stmt->bind_param('ssssisss',  // 8 parameters: 6 strings, 1 int, 1 string
                $student_id_number,          // student_id_number (string)
                $learner_name,               // student_full_name (string)
                $class_name,                 // class_name (string)
                $received_status,            // received (string) - MUST BE VARIABLE in PHP 8+
                $total_quantity,             // quantity (integer)
                $material_type,              // description (string) - MUST BE VARIABLE in PHP 8+
                $combined_sub_description,   // sub_description (string)
                $representative_name         // representative_name (string) - Use facilitator/logistics name, NOT learner name
            );
            $insert_receipt_stmt->execute();
            $insert_receipt_stmt->close();
        }
        $check_receipt_stmt->close();

        // Save to poe_sizes table
        $check_poe_sql = "SELECT id FROM poe_sizes WHERE learner_id = ?";
        $check_poe_stmt = $conn->prepare($check_poe_sql);
        $check_poe_stmt->bind_param('i', $learner_id);
        $check_poe_stmt->execute();
        $check_poe_result = $check_poe_stmt->get_result();

        if ($check_poe_result->num_rows > 0) {
            // Update existing record
            $update_poe_sql = "UPDATE poe_sizes 
                               SET conti_suits_size = ?,
                                   safety_boots_size = ?,
                                   updated_at = CURRENT_TIMESTAMP
                               WHERE learner_id = ?";
            
            $update_poe_stmt = $conn->prepare($update_poe_sql);
            $update_poe_stmt->bind_param('ssi',
                $conti_suit_size,
                $boots_size,
                $learner_id
            );
            $update_poe_stmt->execute();
            $update_poe_stmt->close();
        } else {
            // Insert new record
            $insert_poe_sql = "INSERT INTO poe_sizes 
                               (learner_id, conti_suits_size, safety_boots_size, created_at)
                               VALUES (?, ?, ?, CURRENT_TIMESTAMP)";
            
            $insert_poe_stmt = $conn->prepare($insert_poe_sql);
            $insert_poe_stmt->bind_param('iss',
                $learner_id,
                $conti_suit_size,
                $boots_size
            );
            $insert_poe_stmt->execute();
            $insert_poe_stmt->close();
        }
        $check_poe_stmt->close();
    }

    echo json_encode([
        'success' => true,
        'message' => $message,
        'data' => [
            'learner_id' => $learner_id,
            'conti_suit_size' => $conti_suit_size,
            'conti_suit_quantity' => $conti_suit_quantity,
            'boots_size' => $boots_size,
            'boots_quantity' => $boots_quantity,
        ]
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
