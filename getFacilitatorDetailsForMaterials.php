<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
include('connection.php');

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

$classID = isset($_GET['classID']) ? $_GET['classID'] : '';

// If classID is provided, fetch the learners for that class
if ($classID) {
    $sql = "SELECT 
                ld.LearnerID,
                ld.IDNumber,
                ld.PhoneNumber,
                CONCAT(ld.Name, ' ', ld.Surname) AS full_name,
                ld.IDNumber AS LearnerIDNumber,
                p.project_id,
                p.Project_name,
                JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '$[0].name')) AS pathway_name,
                JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '$[0].qual_types[0].qualification.name')) AS qualification_name,
                JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '$[0].qual_types[0].qualification.id')) AS qualification_id,
                CONCAT(f.firstName, ' ', f.lastName) AS FacilitatorFullName,
                c.className
            FROM learnerdetails ld
            JOIN class c ON ld.classID = c.classID
            JOIN sites site ON c.siteID = site.siteID
            JOIN project p ON site.project_id = p.project_id
            JOIN facilitator f ON c.classID = f.classID
            WHERE ld.classID = ?";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $classID);
    $stmt->execute();
    $result = $stmt->get_result();
} else {
    echo json_encode([
        'error' => 'No classID provided',
        'message' => "No data found for classID:" . $classID
    ]);
    exit;
}

$learners = [];
if ($result->num_rows > 0) {
    // Fetch each row and add to the $learners array
    while($row = $result->fetch_assoc()) {
        $learners[] = $row;
    }
}

// Close connection
$conn->close();

// Return the learners data as JSON
echo json_encode($learners);
?>