<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

// Suppress ALL output except our JSON
error_reporting(0);
ini_set('display_errors', 0);
ini_set('log_errors', 0);

// Start output buffering to catch any unwanted output
ob_start();

session_start();

try {
    // Include database connection
    include('connection.php');
    
    // Set timezone
    date_default_timezone_set('Africa/Johannesburg');
    
    // Handle POST for marking individual learners as received (from poe_collection.php)
    if (isset($_POST['mark_received'])) {
        $classID = (int)$_POST['classID'];
        $receivedLearners = $_POST['received_learners'] ?? [];
        
        if (empty($receivedLearners)) {
            throw new Exception("No learners selected.");
        }
        
        // Fetch className
        $classNameSql = "SELECT className FROM class WHERE classID = ?";
        $classNameStmt = $conn->prepare($classNameSql);
        if (!$classNameStmt) {
            throw new Exception("Error preparing class query: " . $conn->error);
        }
        $classNameStmt->bind_param("i", $classID);
        if (!$classNameStmt->execute()) {
            throw new Exception("Error executing class query: " . $classNameStmt->error);
        }
        $classNameResult = $classNameStmt->get_result();
        $classRow = $classNameResult->fetch_assoc();
        $className = $classRow ? $classRow['className'] : 'Unknown';
        $classNameStmt->close();

        $successCount = 0;
        foreach ($receivedLearners as $encoded) {
            $parts = explode('|', $encoded, 2);
            if (count($parts) !== 2) continue;
            $idNumber = trim($parts[0]);
            $fullName = trim($parts[1]);
            if (empty($idNumber) || empty($fullName)) continue;
            
            // Check if already exists
            $checkSql = "SELECT id FROM material_receipt_form WHERE student_id_number = ? AND class_name = ? AND description = 'POE Submission'";
            $checkStmt = $conn->prepare($checkSql);
            if ($checkStmt) {
                $checkStmt->bind_param("ss", $idNumber, $className);
                $checkStmt->execute();
                $checkResult = $checkStmt->get_result();
                
                if ($checkResult->num_rows > 0) {
                    // Update existing record
                    $updateSql = "UPDATE material_receipt_form SET date_received = NOW(), received = 'Yes', quantity = 1 WHERE student_id_number = ? AND class_name = ? AND description = 'POE Submission'";
                    $updateStmt = $conn->prepare($updateSql);
                    if ($updateStmt) {
                        $updateStmt->bind_param("ss", $idNumber, $className);
                        if ($updateStmt->execute()) {
                            $successCount++;
                        }
                        $updateStmt->close();
                    }
                } else {
                    // Insert new record
                    $insertSql = "INSERT INTO material_receipt_form (student_full_name, student_id_number, class_name, date_received, received, quantity, description) VALUES (?, ?, ?, NOW(), 'Yes', 1, 'POE Submission')";
                    $insertStmt = $conn->prepare($insertSql);
                    if ($insertStmt) {
                        $insertStmt->bind_param("sss", $fullName, $idNumber, $className);
                        if ($insertStmt->execute()) {
                            $successCount++;
                        }
                        $insertStmt->close();
                    }
                }
                $checkStmt->close();
            }
        }
        
        // Clear any unwanted output
        ob_clean();
        
        echo json_encode([
            'success' => true,
            'message' => "$successCount learner(s) marked as POE received successfully.",
            'count' => $successCount
        ]);
        
    } elseif (isset($_POST['save_poe'])) {
        // Handle POE form submission (from poe_collection.php)
        $classID = (int)$_POST['classID'];
        $facilitator_full_name = trim($_POST['facilitator_full_name'] ?? '');
        $representative_full_name = trim($_POST['representative_full_name'] ?? '');
        $description = 'POE Submission';
        $quantity = (int)($_POST['quantity'] ?? 1);
        $facilitator_signature = trim($_POST['facilitator_signature'] ?? '');
        $representative_signature = trim($_POST['representative_signature'] ?? '');
        $submission_id = isset($_POST['submission_id']) && !empty($_POST['submission_id']) ? (int)$_POST['submission_id'] : 0;
        $is_synced = 0;

        // Fetch className for qualification_name
        $classNameSql = "SELECT className FROM class WHERE classID = ?";
        $classNameStmt = $conn->prepare($classNameSql);
        if (!$classNameStmt) {
            throw new Exception("Error preparing class query: " . $conn->error);
        }
        $classNameStmt->bind_param("i", $classID);
        if (!$classNameStmt->execute()) {
            throw new Exception("Error executing class query: " . $classNameStmt->error);
        }
        $classNameResult = $classNameStmt->get_result();
        $classRow = $classNameResult->fetch_assoc();
        $qualification_name = $classRow ? $classRow['className'] : 'Unknown';
        $classNameStmt->close();

        if ($submission_id > 0) {
            // Update existing record
            $updateSql = "UPDATE material_forms SET facilitator_full_name = ?, representative_full_name = ?, qualification_name = ?, facilitator_signature = ?, representative_signature = ?, quantity = ? WHERE id = ?";
            $updateStmt = $conn->prepare($updateSql);
            if ($updateStmt) {
                $updateStmt->bind_param("sssssii", $facilitator_full_name, $representative_full_name, $qualification_name, $facilitator_signature, $representative_signature, $quantity, $submission_id);
                if ($updateStmt->execute()) {
                    $message = $updateStmt->affected_rows > 0 ? "POE Submission updated successfully." : "No changes made or record not found.";
                } else {
                    throw new Exception("Error updating POE submission: " . $updateStmt->error);
                }
                $updateStmt->close();
            } else {
                throw new Exception("Error preparing update query: " . $conn->error);
            }
        } else {
            // Insert new record
            $insertSql = "INSERT INTO material_forms (classID, facilitator_full_name, representative_full_name, qualification_name, facilitator_signature, representative_signature, description, quantity, is_synced) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
            $insertStmt = $conn->prepare($insertSql);
            if ($insertStmt) {
                $insertStmt->bind_param("issssssii", $classID, $facilitator_full_name, $representative_full_name, $qualification_name, $facilitator_signature, $representative_signature, $description, $quantity, $is_synced);
                if ($insertStmt->execute()) {
                    $message = "POE Submission recorded successfully.";
                } else {
                    throw new Exception("Error saving POE submission: " . $insertStmt->error);
                }
                $insertStmt->close();
            } else {
                throw new Exception("Error preparing save query: " . $conn->error);
            }
        }
        
        // Clear any unwanted output
        ob_clean();
        
        echo json_encode([
            'success' => true,
            'message' => $message ?? 'POE form processed successfully.'
        ]);
        
    } else {
        throw new Exception("Invalid request method or missing parameters.");
    }

} catch (Exception $e) {
    // Clear any unwanted output
    ob_clean();
    
    // Output only clean JSON error
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

// End output buffering
ob_end_flush();
?>