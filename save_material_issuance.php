<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

include('connection.php');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception("Invalid JSON input");
    }

    // Validate required fields
    $required_fields = ['classID', 'siteID', 'facilitator_name', 'issue_date', 'materials'];
    foreach ($required_fields as $field) {
        if (!isset($input[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }

    if (empty($input['materials']) || !is_array($input['materials'])) {
        throw new Exception("No materials provided");
    }

    // Start transaction
    $conn->autocommit(false);

    // Insert each material issuance separately
    $issuance_ids = [];
    
    foreach ($input['materials'] as $material) {
        // Insert into material_issuances table
        $sql = "INSERT INTO material_issuances (
                    material_id, classID, siteID, facilitator_name, recipient_name,
                    quantity_issued, issue_date, expected_return_date, purpose, notes,
                    issued_by, received_by, status, is_synced
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Issued', 0)";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception("Prepare failed: " . $conn->error);
        }

        // Calculate expected return date (30 days from issue date)
        $issue_date = $input['issue_date'];
        $expected_return_date = date('Y-m-d', strtotime($issue_date . ' + 30 days'));

        $stmt->bind_param(
            "iisssissssss",
            $material['material_id'],
            $input['classID'],
            $input['siteID'],
            $input['facilitator_name'],
            $input['recipient_name'] ?? $input['facilitator_name'],
            $material['quantity_requested'],
            $issue_date,
            $expected_return_date,
            $input['purpose'] ?? 'Training Materials',
            $input['notes'] ?? '',
            $input['issued_by'] ?? 'Logistics',
            $input['received_by'] ?? $input['facilitator_name']
        );

        if (!$stmt->execute()) {
            throw new Exception("Failed to insert issuance: " . $stmt->error);
        }

        $issuance_id = $conn->insert_id;
        $issuance_ids[] = $issuance_id;
        $stmt->close();

        // Update material inventory stock
        $sql_update = "UPDATE material_inventory 
                      SET current_stock = current_stock - ? 
                      WHERE inventory_id = ? AND current_stock >= ?";
        
        $stmt_update = $conn->prepare($sql_update);
        if (!$stmt_update) {
            throw new Exception("Prepare update failed: " . $conn->error);
        }

        $stmt_update->bind_param(
            "iii", 
            $material['quantity_requested'], 
            $material['material_id'], 
            $material['quantity_requested']
        );

        if (!$stmt_update->execute()) {
            throw new Exception("Failed to update stock for material ID: " . $material['material_id']);
        }

        if ($stmt_update->affected_rows == 0) {
            throw new Exception("Insufficient stock for material: " . $material['material_name']);
        }

        $stmt_update->close();
    }

    // Commit transaction
    $conn->commit();

    echo json_encode([
        'success' => true,
        'message' => 'Material issuance saved successfully',
        'issuance_ids' => $issuance_ids,
        'total_materials' => count($input['materials'])
    ]);

} catch (Exception $e) {
    // Rollback transaction on error
    if (isset($conn)) {
        $conn->rollback();
    }
    
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

if (isset($conn)) {
    $conn->autocommit(true);
    $conn->close();
}
?>