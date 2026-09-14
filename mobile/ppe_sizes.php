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
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        // GET request - fetch PPE sizes for a learner
        if (!isset($_GET['learner_id']) || empty($_GET['learner_id'])) {
            throw new Exception('Missing required parameter: learner_id');
        }

        $learner_id = intval($_GET['learner_id']);

        // First, get learner's IDNumber
        $learner_query = "SELECT IDNumber FROM learnerdetails WHERE LearnerID = ?";
        $learner_stmt = $conn->prepare($learner_query);
        $learner_stmt->bind_param('i', $learner_id);
        $learner_stmt->execute();
        $learner_result = $learner_stmt->get_result()->fetch_assoc();
        $learner_stmt->close();
        
        $data = null;
        
        // Try to get from poe_sizes table first (primary source)
        $query = "SELECT * FROM poe_sizes WHERE learner_id = ? ORDER BY created_at DESC LIMIT 1";
        $stmt = $conn->prepare($query);
        $stmt->bind_param('i', $learner_id);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            $data = $result->fetch_assoc();
        } else if ($learner_result) {
            // If not in poe_sizes, try material_receipt_form (backup source)
            $student_id_number = $learner_result['IDNumber'];
            $receipt_query = "SELECT sub_description, date_received 
                             FROM material_receipt_form 
                             WHERE student_id_number = ? AND description = 'PPE' 
                             ORDER BY created_at DESC LIMIT 1";
            $receipt_stmt = $conn->prepare($receipt_query);
            $receipt_stmt->bind_param('s', $student_id_number);
            $receipt_stmt->execute();
            $receipt_result = $receipt_stmt->get_result();
            
            if ($receipt_result->num_rows > 0) {
                $receipt_data = $receipt_result->fetch_assoc();
                
                // Parse sub_description to extract sizes
                // Format: "Conti-Suit: 32, Safety Boots: 8"
                $sub_desc = $receipt_data['sub_description'];
                $conti_size = null;
                $boots_size = null;
                
                if (preg_match('/Conti-Suit:\s*(\d+)/', $sub_desc, $matches)) {
                    $conti_size = $matches[1];
                }
                if (preg_match('/Safety Boots:\s*(\d+)/', $sub_desc, $matches)) {
                    $boots_size = $matches[1];
                }
                
                $data = [
                    'learner_id' => $learner_id,
                    'conti_suits_size' => $conti_size,
                    'safety_boots_size' => $boots_size,
                    'created_at' => $receipt_data['date_received'],
                    'synced' => 1
                ];
            }
            $receipt_stmt->close();
        }
        
        $stmt->close();

        if ($data) {
            echo json_encode([
                'status' => 'success',
                'data' => $data
            ]);
        } else {
            echo json_encode([
                'status' => 'success',
                'data' => null,
                'message' => 'No PPE sizes found for this learner'
            ]);
        }

    } elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // POST request - save PPE sizes (redirect to save_learner_ppe.php logic)
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

        // Check if record exists for this learner in poe_sizes
        $check_sql = "SELECT id FROM poe_sizes WHERE learner_id = ?";
        $check_stmt = $conn->prepare($check_sql);
        $check_stmt->bind_param("i", $learner_id);
        $check_stmt->execute();
        $check_result = $check_stmt->get_result();

        if ($check_result->num_rows > 0) {
            // Update existing record in poe_sizes
            $update_sql = "UPDATE poe_sizes 
                           SET conti_suits_size = ?,
                               safety_boots_size = ?,
                               synced = 0
                           WHERE learner_id = ?";
            
            $update_stmt = $conn->prepare($update_sql);
            $update_stmt->bind_param(
                "ssi",
                $conti_suit_size,
                $boots_size,
                $learner_id
            );
            
            if (!$update_stmt->execute()) {
                throw new Exception("Error updating poe_sizes: " . $update_stmt->error);
            }
            
            $message = "PPE sizes updated successfully";
        } else {
            // Insert new record to poe_sizes
            $insert_sql = "INSERT INTO poe_sizes 
                           (learner_id, conti_suits_size, safety_boots_size, synced)
                           VALUES (?, ?, ?, 0)";
            
            $insert_stmt = $conn->prepare($insert_sql);
            $insert_stmt->bind_param(
                "iss",
                $learner_id,
                $conti_suit_size,
                $boots_size
            );
            
            if (!$insert_stmt->execute()) {
                throw new Exception("Error inserting poe_sizes: " . $insert_stmt->error);
            }
            
            $message = "PPE issued successfully";
        }

        // ALSO save to material_receipt_form for unified tracking
        // First, get the learner's IDNumber from learnerdetails table
        $learner_query = "SELECT IDNumber, FullName FROM learnerdetails WHERE LearnerID = ?";
        $learner_stmt = $conn->prepare($learner_query);
        $learner_stmt->bind_param('i', $learner_id);
        $learner_stmt->execute();
        $learner_result = $learner_stmt->get_result()->fetch_assoc();
        $learner_stmt->close();
        
        if (!$learner_result) {
            throw new Exception("Learner not found in learnerdetails table");
        }
        
        $student_id_number = $learner_result['IDNumber'];
        $student_full_name = $learner_result['FullName'];
        
        // Get class name
        $class_name = 'Unknown Class';
        if (!empty($class_id)) {
            $class_query = "SELECT className FROM class WHERE classID = ?";
            $class_stmt = $conn->prepare($class_query);
            $class_stmt->bind_param('s', $class_id);
            $class_stmt->execute();
            $class_result = $class_stmt->get_result()->fetch_assoc();
            if ($class_result) {
                $class_name = $class_result['className'];
            }
            $class_stmt->close();
        }

        // Combine both sizes into one sub_description
        $sub_description_parts = [];
        if (!empty($conti_suit_size)) {
            $sub_description_parts[] = "Conti-Suit: $conti_suit_size";
        }
        if (!empty($boots_size)) {
            $sub_description_parts[] = "Safety Boots: $boots_size";
        }
        
        $sub_description = implode(', ', $sub_description_parts);
        
        // Only save if at least one size is provided
        if (!empty($sub_description)) {
            // Check if PPE record already exists for this learner
            $check_sql = "SELECT id FROM material_receipt_form 
                          WHERE student_id_number = ? AND description = 'PPE'";
            $check_stmt = $conn->prepare($check_sql);
            $check_stmt->bind_param('s', $student_id_number);
            $check_stmt->execute();
            $check_result = $check_stmt->get_result();
            
            if ($check_result->num_rows > 0) {
                // UPDATE existing PPE record
                $existing = $check_result->fetch_assoc();
                $update_sql = "UPDATE material_receipt_form 
                               SET sub_description = ?,
                                   date_received = CURDATE(),
                                   representative_name = ?,
                                   synced = 0
                               WHERE id = ?";
                
                $update_stmt = $conn->prepare($update_sql);
                $update_stmt->bind_param('ssi', 
                    $sub_description,
                    $learner_name,
                    $existing['id']
                );
                $update_stmt->execute();
                $update_stmt->close();
            } else {
                // INSERT new PPE record
                $receipt_sql = "INSERT INTO material_receipt_form 
                                (student_id_number, student_full_name, class_name, received, quantity, 
                                 description, sub_description, date_received, representative_name, 
                                 date_aor_created, synced, created_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?, CURDATE(), ?, CURDATE(), 0, CURRENT_TIMESTAMP)";
                
                // PHP 8+ requires all bind_param arguments to be variables, not literals
                $received_status = 'Yes';
                $ppe_quantity = 1;
                $material_type = 'PPE';
                
                $receipt_stmt = $conn->prepare($receipt_sql);
                $receipt_stmt->bind_param('ssssisss',  // 8 parameters: 6 strings, 1 int, 1 string
                    $student_id_number,      // student_id_number (string)
                    $student_full_name,      // student_full_name (string)
                    $class_name,             // class_name (string)
                    $received_status,        // received (string) - MUST BE VARIABLE in PHP 8+
                    $ppe_quantity,           // quantity (integer) - MUST BE VARIABLE in PHP 8+
                    $material_type,          // description (string) - MUST BE VARIABLE in PHP 8+
                    $sub_description,        // sub_description (string)
                    $learner_name            // representative_name (string)
                );
                $receipt_stmt->execute();
                $receipt_stmt->close();
            }
            $check_stmt->close();
        }

        echo json_encode([
            'status' => 'success',
            'message' => $message,
            'data' => [
                'learner_id' => $learner_id,
                'conti_suit_size' => $conti_suit_size,
                'conti_suit_quantity' => $conti_suit_quantity,
                'boots_size' => $boots_size,
                'boots_quantity' => $boots_quantity,
            ]
        ]);
    } else {
        throw new Exception('Invalid request method');
    }

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
