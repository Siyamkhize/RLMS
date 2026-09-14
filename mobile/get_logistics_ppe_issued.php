<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'connection.php';

try {
    // Get parameters
    $class_id = $_GET['classID'] ?? '';
    $ppe_type = $_GET['ppe_type'] ?? '';

    if (empty($class_id) || empty($ppe_type)) {
        throw new Exception('Missing required parameters: classID and ppe_type');
    }

    // Get learners who already received this PPE type from material_receipt_form
    // PPE records are stored with description='PPE' and sub_description contains the PPE type and size
    $sql = "SELECT DISTINCT 
                l.LearnerID,
                l.Name,
                l.Surname,
                l.IDNumber,
                m.sub_description as ppe_info,
                m.quantity,
                m.date_received as issued_date
            FROM material_receipt_form m
            INNER JOIN learnerdetails l ON m.student_id_number = l.IDNumber
            WHERE l.classID = ? 
            AND m.description = 'PPE'
            AND m.sub_description LIKE ?
            ORDER BY l.Surname, l.Name";

    $stmt = $conn->prepare($sql);
    $ppe_search = $ppe_type . '%'; // Search for PPE type at the start of sub_description
    $stmt->bind_param("ss", $class_id, $ppe_search);
    $stmt->execute();
    $result = $stmt->get_result();

    $issued_learners = [];
    while ($row = $result->fetch_assoc()) {
        // Parse ppe_info to extract ppe_type and size
        // Format is "PPE_TYPE: SIZE" (e.g., "Conti-Suit: 27")
        $ppe_parts = explode(':', $row['ppe_info']);
        $row['ppe_type'] = trim($ppe_parts[0] ?? $ppe_type);
        $row['size'] = trim($ppe_parts[1] ?? '');
        unset($row['ppe_info']); // Remove the temporary field
        
        $issued_learners[] = $row;
    }

    echo json_encode($issued_learners);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
