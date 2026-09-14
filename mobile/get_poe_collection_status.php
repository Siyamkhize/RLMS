<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

require_once 'connection.php';

try {
    // Get class ID from request
    $classID = $_GET['classID'] ?? '';
    
    if (empty($classID)) {
        echo json_encode([
            'success' => false,
            'error' => 'Class ID is required'
        ]);
        exit;
    }

    // Query to get learners with their POE collection status (using correct table structure)
    $query = "
        SELECT 
            l.LearnerID,
            l.IDNumber,
            l.Surname,
            CONCAT(l.Name, ' ', l.Surname) AS FullName,
            c.className,
            CASE 
                WHEN mrf_collect.student_id_number IS NOT NULL THEN 'Collected'
                WHEN mrf_submit.student_id_number IS NOT NULL THEN 'Ready for Collection'
                ELSE 'Not Submitted'
            END AS POEStatus,
            mrf_submit.date_received AS submission_date,
            mrf_collect.date_received AS collection_date,
            mrf_submit.created_at AS submission_created_at
        FROM learnerdetails l
        -- Join class to get class name
        LEFT JOIN class c ON l.classID = c.classID
        -- POE Submission
        LEFT JOIN material_receipt_form mrf_submit
            ON l.IDNumber = mrf_submit.student_id_number
            AND mrf_submit.description = 'POE Submission'
        -- POE Collection
        LEFT JOIN material_receipt_form mrf_collect
            ON l.IDNumber = mrf_collect.student_id_number
            AND mrf_collect.description = 'POE Collection'
        WHERE l.classID = ?
        ORDER BY l.Surname, l.Name
    ";

    $stmt = $conn->prepare($query);
    $stmt->bind_param("s", $classID);
    $stmt->execute();
    $result = $stmt->get_result();

    $learners = [];
    $statusCounts = [
        'not_submitted' => 0,
        'ready_for_collection' => 0,
        'collected' => 0
    ];

    while ($row = $result->fetch_assoc()) {
        $poeStatus = $row['POEStatus'];
        
        $learners[] = [
            'LearnerID' => $row['LearnerID'],
            'IDNumber' => $row['IDNumber'],
            'FullName' => $row['FullName'],
            'ClassName' => $row['className'],
            'FacilitatorFullName' => 'Unknown Facilitator',
            'qualification_name' => 'No qualification assigned',
            'POEStatus' => $poeStatus,
            'submission_date' => $row['submission_date'],
            'collection_date' => $row['collection_date'],
            'submission_created_at' => $row['submission_created_at'],
            // Add fields needed for POE Collection page
            'Received' => false,
            'Quantity' => '1',
            'Date' => date('Y-m-d'),
            'Description' => 'POE Submission',
            'Signature' => null
        ];

        // Count statuses
        if ($poeStatus === 'Collected') {
            $statusCounts['collected']++;
        } elseif ($poeStatus === 'Ready for Collection') {
            $statusCounts['ready_for_collection']++;
        } else {
            $statusCounts['not_submitted']++;
        }
    }

    echo json_encode([
        'success' => true,
        'learners' => $learners,
        'total_count' => count($learners),
        'status_counts' => $statusCounts,
        'class_id' => $classID
    ]);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => 'Database error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>