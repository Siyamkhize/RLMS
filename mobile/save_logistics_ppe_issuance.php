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
    $required_fields = ['LearnerID', 'ppe_type', 'size', 'quantity'];
    foreach ($required_fields as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }

    // Prepare data
    $learner_id = $data['LearnerID'];
    $learner_name = $data['learner_name'] ?? '';
    $ppe_type = $data['ppe_type'];
    $size = $data['size'];
    $quantity = intval($data['quantity']);
    $class_name = $data['class_name'] ?? '';
    $logistics_name = $data['logistics_name'] ?? 'Logistics';
    $issued_date = $data['issued_date'] ?? date('Y-m-d H:i:s');

    // Get learner's IDNumber AND internal LearnerID from learnerdetails table
    $student_id_number = '';
    $internal_learner_id = 0;
    
    $learner_query = "SELECT IDNumber, LearnerID FROM learnerdetails WHERE LearnerID = ?";
    $learner_stmt = $conn->prepare($learner_query);
    $learner_stmt->bind_param('s', $learner_id); // Use string binding for large numbers
    $learner_stmt->execute();
    $learner_result = $learner_stmt->get_result()->fetch_assoc();
    
    if ($learner_result) {
        $student_id_number = $learner_result['IDNumber'];
        $internal_learner_id = intval($learner_result['LearnerID']);
    } else {
        throw new Exception("Learner not found with LearnerID: $learner_id");
    }
    $learner_stmt->close();

    // Save to material_receipt_form for unified tracking
    $sub_description = "$ppe_type: $size";
    // Representative is the logistics user who issued the PPE
    $representative = !empty($logistics_name) ? $logistics_name : 'Logistics';
    
    // Check if record exists
    $check_receipt_sql = "SELECT id, sub_description, quantity FROM material_receipt_form 
                          WHERE student_id_number = ? AND description = 'PPE'";
    $check_receipt_stmt = $conn->prepare($check_receipt_sql);
    $check_receipt_stmt->bind_param('s', $student_id_number);
    $check_receipt_stmt->execute();
    $check_receipt_result = $check_receipt_stmt->get_result();

    if ($check_receipt_result->num_rows > 0) {
        // Update existing record - append to sub_description
        $existing = $check_receipt_result->fetch_assoc();
        $existing_sub = $existing['sub_description'] ?? '';
        $existing_qty = intval($existing['quantity']);
        
        // Check if this PPE type already exists in sub_description
        if (strpos($existing_sub, $ppe_type) !== false) {
            // Replace the existing PPE type with new size
            $pattern = '/' . preg_quote($ppe_type, '/') . ':\s*[^,]+/';
            $new_sub_description = preg_replace($pattern, $sub_description, $existing_sub);
        } else {
            // Append new PPE type
            $new_sub_description = !empty($existing_sub) ? $existing_sub . ", " . $sub_description : $sub_description;
        }
        
        $new_quantity = $existing_qty + $quantity;
        
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
        // Types: student_full_name (s), class_name (s), quantity (i),
        // sub_description (s), representative_name (s), student_id_number (s)
        $update_receipt_stmt->bind_param(
            'ssisss',
            $learner_name,
            $class_name,
            $new_quantity,
            $new_sub_description,
            $representative,
            $student_id_number
        );
        
        if (!$update_receipt_stmt->execute()) {
            error_log("Warning: Failed to update material_receipt_form: " . $update_receipt_stmt->error);
        }
        $update_receipt_stmt->close();
    } else {
        // Insert new record
        $insert_receipt_sql = "INSERT INTO material_receipt_form 
                               (student_id_number, student_full_name, class_name, received, quantity, 
                                description, sub_description, date_received, representative_name, 
                                date_aor_created, synced, created_at)
                               VALUES (?, ?, ?, ?, ?, ?, ?, CURDATE(), ?, CURDATE(), 0, CURRENT_TIMESTAMP)";
        
        $insert_receipt_stmt = $conn->prepare($insert_receipt_sql);
        // Types: student_id_number (s), student_full_name (s), class_name (s),
        // received (s), quantity (i), description (s), sub_description (s),
        // representative_name (s)
        $insert_receipt_stmt->bind_param(
            'ssssisss',
            $student_id_number,      // student_id_number (string)
            $learner_name,           // student_full_name (string)
            $class_name,             // class_name (string)
            'Yes',                   // received (string)
            $quantity,               // quantity (integer)
            'PPE',                   // description (string)
            $sub_description,        // sub_description (string)
            $representative          // representative_name (string)
        );
        
        if (!$insert_receipt_stmt->execute()) {
            error_log("Warning: Failed to insert to material_receipt_form: " . $insert_receipt_stmt->error);
        }
        $insert_receipt_stmt->close();
    }
    $check_receipt_stmt->close();

    // Save to poe_sizes table - CRITICAL: Use internal LearnerID (small integer)
    // poe_sizes.learner_id = learnerdetails.LearnerID (NOT IDNumber!)
    if ($internal_learner_id > 0) {
        $check_poe_sql = "SELECT id, conti_suits_size, safety_boots_size FROM poe_sizes WHERE learner_id = ?";
        $check_poe_stmt = $conn->prepare($check_poe_sql);
        
        if (!$check_poe_stmt) {
            error_log("Failed to prepare poe_sizes check: " . $conn->error);
        } else {
            $check_poe_stmt->bind_param('i', $internal_learner_id);
            $check_poe_stmt->execute();
            $check_poe_result = $check_poe_stmt->get_result();

            if ($check_poe_result->num_rows > 0) {
                // Update existing record
                $existing_poe = $check_poe_result->fetch_assoc();
                $conti_suits_size = $existing_poe['conti_suits_size'];
                $safety_boots_size = $existing_poe['safety_boots_size'];
                
                // Update the appropriate field based on PPE type
                if (stripos($ppe_type, 'conti') !== false || stripos($ppe_type, 'suit') !== false) {
                    $conti_suits_size = $size;
                } elseif (stripos($ppe_type, 'boot') !== false || stripos($ppe_type, 'safety') !== false) {
                    $safety_boots_size = $size;
                }
                
                $update_poe_sql = "UPDATE poe_sizes 
                                   SET conti_suits_size = ?,
                                       safety_boots_size = ?,
                                       updated_at = CURRENT_TIMESTAMP
                                   WHERE learner_id = ?";
                
                $update_poe_stmt = $conn->prepare($update_poe_sql);
                if ($update_poe_stmt) {
                    $update_poe_stmt->bind_param('ssi',
                        $conti_suits_size,
                        $safety_boots_size,
                        $internal_learner_id
                    );
                    if (!$update_poe_stmt->execute()) {
                        error_log("Failed to update poe_sizes: " . $update_poe_stmt->error);
                    } else {
                        error_log("Successfully updated poe_sizes for learner_id: $internal_learner_id");
                    }
                    $update_poe_stmt->close();
                } else {
                    error_log("Failed to prepare poe_sizes update: " . $conn->error);
                }
            } else {
                // Insert new record
                $conti_suits_size = null;
                $safety_boots_size = null;
                
                if (stripos($ppe_type, 'conti') !== false || stripos($ppe_type, 'suit') !== false) {
                    $conti_suits_size = $size;
                } elseif (stripos($ppe_type, 'boot') !== false || stripos($ppe_type, 'safety') !== false) {
                    $safety_boots_size = $size;
                }
                
                $insert_poe_sql = "INSERT INTO poe_sizes 
                                   (learner_id, conti_suits_size, safety_boots_size, created_at)
                                   VALUES (?, ?, ?, CURRENT_TIMESTAMP)";
                
                $insert_poe_stmt = $conn->prepare($insert_poe_sql);
                if ($insert_poe_stmt) {
                    $insert_poe_stmt->bind_param('iss',
                        $internal_learner_id,
                        $conti_suits_size,
                        $safety_boots_size
                    );
                    if (!$insert_poe_stmt->execute()) {
                        error_log("Failed to insert to poe_sizes: " . $insert_poe_stmt->error);
                    } else {
                        error_log("Successfully inserted to poe_sizes for learner_id: $internal_learner_id");
                    }
                    $insert_poe_stmt->close();
                } else {
                    error_log("Failed to prepare poe_sizes insert: " . $conn->error);
                }
            }
            $check_poe_stmt->close();
        }
    } else {
        error_log("WARNING: Cannot save to poe_sizes - no valid internal learner_id");
    }

    echo json_encode([
        'status' => 'success',
        'message' => $message,
        'data' => [
            'learner_id' => $learner_id,
            'ppe_type' => $ppe_type,
            'size' => $size,
            'quantity' => $quantity,
        ]
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
