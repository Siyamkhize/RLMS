<?php
/**
 * Script to update pothole evidence image paths from old domain to new domain
 * Run this once to migrate from rlms.rlms.co.za to rlms.rlms.co.za
 */

header('Content-Type: application/json');
include('connection.php');

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die(json_encode(['status' => 'error', 'message' => 'Connection failed: ' . $conn->connect_error]));
}

// Old and new domains
$oldDomain = 'rlms.rlms.co.za';
$newDomain = 'rlms.rlms.co.za';

// First, let's see what needs to be updated
$checkSql = "SELECT COUNT(*) as count FROM poe 
             WHERE type = 'LogBook' 
             AND (exercise LIKE '%Pothole%' OR logbook_text LIKE '%pothole%')
             AND filePath LIKE ?";

$stmt = $conn->prepare($checkSql);
$searchPattern = "%$oldDomain%";
$stmt->bind_param('s', $searchPattern);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();
$recordsToUpdate = $row['count'];
$stmt->close();

if ($recordsToUpdate == 0) {
    echo json_encode([
        'status' => 'success',
        'message' => 'No records need updating',
        'records_checked' => 0,
        'records_updated' => 0
    ]);
    $conn->close();
    exit;
}

// Update the file paths
$updateSql = "UPDATE poe 
              SET filePath = REPLACE(filePath, ?, ?)
              WHERE type = 'LogBook' 
              AND (exercise LIKE '%Pothole%' OR logbook_text LIKE '%pothole%')
              AND filePath LIKE ?";

$stmt = $conn->prepare($updateSql);
$stmt->bind_param('sss', $oldDomain, $newDomain, $searchPattern);

if ($stmt->execute()) {
    $updatedRows = $stmt->affected_rows;
    
    echo json_encode([
        'status' => 'success',
        'message' => "Successfully updated $updatedRows record(s)",
        'records_found' => $recordsToUpdate,
        'records_updated' => $updatedRows,
        'old_domain' => $oldDomain,
        'new_domain' => $newDomain
    ]);
} else {
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to update records: ' . $stmt->error
    ]);
}

$stmt->close();
$conn->close();
?>
