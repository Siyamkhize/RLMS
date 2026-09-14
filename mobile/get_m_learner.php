<?php
// Set headers for JSON response and CORS
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Include database connection file
include('connection.php');

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    error_log("Connection failed: " . $conn->connect_error);
    die(json_encode(["error" => "Connection failed: " . $conn->connect_error]));
}

// Retrieve query parameters
$classID = isset($_GET['classID']) ? $_GET['classID'] : '';
$selectedItem = isset($_GET['selectedItem']) ? $_GET['selectedItem'] : 'Select';

// Validate classID
if (empty($classID)) {
    error_log("classID is required");
    echo json_encode(["error" => "classID is required"]);
    exit;
}

// Start building the query
$sql = "
SELECT 
    ld.LearnerID,
    ld.IDNumber,
    ld.PhoneNumber,
    CONCAT(ld.Name, ' ', ld.Surname) AS full_name,
    ld.IDNumber AS LearnerIDNumber,
    p.Project_name,
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '$[0].name')), 'Unknown') AS pathway_name,
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '$[0].qual_types[0].qualification.name')), 'Unknown') AS qualification_name,
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '$[0].qual_types[0].qualification.id')), 'Unknown') AS qualification_id,
    CONCAT(f.firstName, ' ', f.lastName) AS FacilitatorFullName,
    c.className AS ClassName
FROM learnerdetails ld
JOIN class c ON ld.classID = c.classID
JOIN sites site ON c.siteID = site.siteID
JOIN project p ON site.project_id = p.project_id
LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
JOIN facilitator f ON c.classID = f.classID
JOIN learner_clocking lc ON lc.LearnerID = ld.LearnerID
LEFT JOIN material_receipt_form mr ON mr.student_id_number = ld.IDNumber AND mr.class_name = c.className
WHERE ld.classID = ?
  AND f.role = 'Facilitator'
  AND lc.clock_in_time IS NOT NULL
  AND DATE(lc.clock_date) = CURDATE()
";

// Add dynamic conditions based on the selected item
if ($selectedItem !== 'Select') {
    $sql .= " AND NOT EXISTS (
                SELECT 1 
                FROM material_receipt_form mrf 
                WHERE mrf.student_id_number = ld.IDNumber 
                  AND mrf.class_name = c.className 
                  AND mrf.description = ?
              )";
}

// Prepare the statement
$stmt = $conn->prepare($sql);
if (!$stmt) {
    error_log("Prepare failed: " . $conn->error);
    echo json_encode(["error" => "Prepare failed: " . $conn->error]);
    exit;
}

// Bind parameters
if ($selectedItem === 'Select') {
    $stmt->bind_param("s", $classID);
} else {
    $stmt->bind_param("ss", $classID, $selectedItem);
}

// Execute query
if (!$stmt->execute()) {
    error_log("Query execution failed: " . $stmt->error);
    echo json_encode(["error" => "Query execution failed: " . $stmt->error]);
    exit;
}

$result = $stmt->get_result();

// Initialize learners array
$learners = [];

if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $learners[] = $row;
    }
} else {
    error_log("No learners found for classID: $classID, selectedItem: $selectedItem");
}

// Close the statement and connection
$stmt->close();
$conn->close();

// Return the learners data as JSON
echo json_encode($learners);
?>