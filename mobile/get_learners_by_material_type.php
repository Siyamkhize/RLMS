<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');

require_once 'connection.php';

try {
    $materialType = $_GET['materialType'] ?? '';

    if (empty($materialType)) {
        echo json_encode(['success' => false, 'error' => 'Material type is required']);
        exit;
    }

    error_log("Getting learners by material type: $materialType");

    $learners = [];

    if ($materialType === 'Learning Material') {
        // For Learning Material, ONLY show learners with COMPLETE unit standards
        // A unit standard is complete when it has ALL 4 material types:
        // Unit Standard, Learner Guide, Formative, Summative
        // Learners with 0 complete unit standards will NOT appear in the list
        $query = "
            SELECT 
                cs.learner_id AS LearnerID,
                l.IDNumber AS IDNumber,
                COALESCE(l.Name, SUBSTRING_INDEX(cs.learner_name, ' ', 1)) AS Name,
                COALESCE(l.Surname, SUBSTRING_INDEX(cs.learner_name, ' ', -1)) AS Surname,
                cs.issued_date,
                cs.complete_count AS unit_standards_count
            FROM (
                SELECT 
                    learner_id,
                    MAX(learner_name) as learner_name,
                    MIN(created_at) as issued_date,
                    COUNT(DISTINCT unit_standard_id) as complete_count
                FROM (
                    SELECT learner_id, learner_name, unit_standard_id, created_at
                    FROM learner_issued_unit_standards
                    WHERE material_type IN ('Unit Standard', 'Learner Guide', 'Formative', 'Summative')
                      AND unit_standard_id IS NOT NULL 
                      AND unit_standard_id != ''
                    GROUP BY learner_id, learner_name, unit_standard_id, created_at
                    HAVING COUNT(DISTINCT material_type) = 4
                ) AS complete_us
                GROUP BY learner_id
            ) AS cs
            LEFT JOIN learnerdetails l ON l.LearnerID = cs.learner_id
            ORDER BY Surname, Name
        ";

        $result = $conn->query($query);
        
    } elseif ($materialType === 'PPE') {
        // For PPE, check poe_sizes table OR material_receipt_form where description='PPE'
        $query = "
            SELECT DISTINCT
                l.LearnerID,
                l.IDNumber,
                l.Name,
                l.Surname,
                MIN(COALESCE(ps.created_at, mrf.created_at)) AS issued_date
            FROM learnerdetails l
            LEFT JOIN poe_sizes ps ON l.LearnerID = ps.learner_id
            LEFT JOIN material_receipt_form mrf ON l.IDNumber = mrf.student_id_number AND mrf.description = 'PPE'
            WHERE ps.learner_id IS NOT NULL OR mrf.student_id_number IS NOT NULL
            GROUP BY l.LearnerID, l.IDNumber, l.Name, l.Surname
            ORDER BY l.Surname, l.Name
        ";
        $result = $conn->query($query);
        
    } elseif ($materialType === 'ToolKit' || $materialType === 'Consumables') {
        // For ToolKit and Consumables, check material_receipt_form
        $query = "
            SELECT DISTINCT
                l.LearnerID,
                l.IDNumber,
                l.Name,
                l.Surname,
                MIN(mrf.created_at) AS issued_date
            FROM learnerdetails l
            INNER JOIN material_receipt_form mrf ON l.IDNumber = mrf.student_id_number
            WHERE mrf.description = ?
            GROUP BY l.LearnerID, l.IDNumber, l.Name, l.Surname
            ORDER BY l.Surname, l.Name
        ";
        $stmt = $conn->prepare($query);
        $stmt->bind_param('s', $materialType);
        $stmt->execute();
        $result = $stmt->get_result();
        
    } else {
        echo json_encode([
            'success' => false, 
            'error' => 'Invalid material type: ' . $materialType
        ]);
        exit;
    }

    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $learners[] = $row;
        }
        error_log("Found " . count($learners) . " learners for material type: $materialType");
    } else {
        error_log("Query failed for material type: $materialType - Error: " . $conn->error);
    }

    echo json_encode([
        'success' => true,
        'learners' => $learners,
        'count' => count($learners),
        'materialType' => $materialType
    ]);

} catch (Exception $e) {
    error_log("Exception in get_learners_by_material_type.php: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'error' => 'Database error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>
