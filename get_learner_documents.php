<?php
/**
 * Helper script to fetch sick notes and manual registers for a learner
 * Used during bulk report generation
 */

// Include database connection
require_once 'connection.php';

/**
 * Get sick notes for a learner within a date range
 * 
 * @param mysqli $conn Database connection
 * @param int $learnerID Learner ID
 * @param string $startDate Start date (Y-m-d)
 * @param string $endDate End date (Y-m-d)
 * @return array Array of sick note records
 */
function getSickNotes($conn, $learnerID, $startDate, $endDate) {
    $sickNotes = [];
    
    $query = "SELECT 
                note_id,
                learner_id,
                document_path,
                practice_name,
                medical_practitioner,
                practitioner_name,
                date_from,
                date_to,
                upload_date,
                status,
                rejection_reason
              FROM sick_note
              WHERE learner_id = ?
              AND (
                  (date_from BETWEEN ? AND ?)
                  OR (date_to BETWEEN ? AND ?)
                  OR (date_from <= ? AND date_to >= ?)
              )
              ORDER BY date_from ASC";
    
    $stmt = $conn->prepare($query);
    if ($stmt) {
        $stmt->bind_param('issssss', $learnerID, $startDate, $endDate, $startDate, $endDate, $startDate, $endDate);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            // Normalize the file path
            $filePath = $row['document_path'];
            
            // Check various possible locations for the sick note
            // Prioritize the most common paths based on your server structure
            $possiblePaths = [
                'mobile/sicknotes/' . basename($filePath), // Most common - relative to script
                'sicknotes/' . basename($filePath), // Alternative location
                $filePath, // Original path from database
                __DIR__ . '/mobile/sicknotes/' . basename($filePath),
                __DIR__ . '/sicknotes/' . basename($filePath),
                str_replace('/public_html/', '', $filePath),
                $_SERVER['DOCUMENT_ROOT'] . '/mobile/sicknotes/' . basename($filePath)
            ];
            
            $actualPath = null;
            foreach ($possiblePaths as $path) {
                if (file_exists($path)) {
                    $actualPath = $path;
                    break;
                }
            }
            
            $row['actual_path'] = $actualPath;
            $row['file_exists'] = !is_null($actualPath);
            $sickNotes[] = $row;
        }
        
        $stmt->close();
    }
    
    return $sickNotes;
}

/**
 * Get manual registers for a learner within a date range
 * 
 * @param mysqli $conn Database connection
 * @param int $learnerID Learner ID
 * @param string $startDate Start date (Y-m-d)
 * @param string $endDate End date (Y-m-d)
 * @return array Array of manual register records
 */
function getManualRegisters($conn, $learnerID, $startDate, $endDate) {
    $manualRegisters = [];
    
    // Try with LearnerID first (most common)
    $query = "SELECT 
                manual_id,
                clocking_id,
                LearnerID,
                clock_date,
                clock_in_time,
                clock_out_time,
                contact_time,
                manual_reason,
                fdp_document,
                status,
                reviewed_by,
                reviewed_at,
                is_manual_attendance
              FROM manual_clocking
              WHERE LearnerID = ?
              AND clock_date BETWEEN ? AND ?
              ORDER BY clock_date ASC";
    
    $stmt = $conn->prepare($query);
    if ($stmt) {
        $stmt->bind_param('iss', $learnerID, $startDate, $endDate); 
        $stmt->execute();
        $result = $stmt->get_result();
        
        error_log("Manual registers query found " . $result->num_rows . " records for learner $learnerID");
        
        while ($row = $result->fetch_assoc()) {
            // Only include if fdp_document is not empty
            if (empty($row['fdp_document'])) {
                error_log("Skipping manual register {$row['manual_id']} - no fdp_document");
                continue;
            }
            
            // Normalize the file path
            $filePath = $row['fdp_document'];
            
            // Check various possible locations for the manual register
            // Prioritize the most common paths based on your server structure
            $possiblePaths = [
                'uploads/' . basename($filePath), // Most common - relative to script
                $filePath, // Original path from database
                __DIR__ . '/uploads/' . basename($filePath),
                'mobile/uploads/' . basename($filePath),
                __DIR__ . '/mobile/uploads/' . basename($filePath),
                str_replace('/public_html/', '', $filePath),
                $_SERVER['DOCUMENT_ROOT'] . '/uploads/' . basename($filePath)
            ];
            
            $actualPath = null;
            foreach ($possiblePaths as $path) {
                if (file_exists($path)) {
                    $actualPath = $path;
                    error_log("Found manual register file at: $path");
                    break;
                }
            }
            
            if (!$actualPath) {
                error_log("Manual register file not found. Tried paths: " . implode(', ', $possiblePaths));
            }
            
            $row['actual_path'] = $actualPath;
            $row['file_exists'] = !is_null($actualPath);
            $manualRegisters[] = $row;
        }
        
        $stmt->close();
    } else {
        error_log("Failed to prepare manual registers query: " . $conn->error);
    }
    
    return $manualRegisters;
}

/**
 * Get all documents (sick notes + manual registers) for a learner
 * 
 * @param mysqli $conn Database connection
 * @param int $learnerID Learner ID
 * @param string $startDate Start date (Y-m-d)
 * @param string $endDate End date (Y-m-d)
 * @return array Array with 'sick_notes' and 'manual_registers' keys
 */
function getLearnerDocuments($conn, $learnerID, $startDate, $endDate) {
    return [
        'sick_notes' => getSickNotes($conn, $learnerID, $startDate, $endDate),
        'manual_registers' => getManualRegisters($conn, $learnerID, $startDate, $endDate)
    ];
}

// If called directly (for testing)
if (basename(__FILE__) == basename($_SERVER['SCRIPT_FILENAME'])) {
    header('Content-Type: application/json');
    
    $learnerID = isset($_GET['learner_id']) ? intval($_GET['learner_id']) : 0;
    $startDate = isset($_GET['start_date']) ? $_GET['start_date'] : date('Y-m-01');
    $endDate = isset($_GET['end_date']) ? $_GET['end_date'] : date('Y-m-t');
    
    if ($learnerID > 0) {
        $documents = getLearnerDocuments($conn, $learnerID, $startDate, $endDate);
        echo json_encode([
            'success' => true,
            'learner_id' => $learnerID,
            'date_range' => ['start' => $startDate, 'end' => $endDate],
            'documents' => $documents
        ], JSON_PRETTY_PRINT);
    } else {
        echo json_encode([
            'success' => false,
            'error' => 'Invalid learner_id parameter'
        ]);
    }
}
