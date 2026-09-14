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
    $sql = "SELECT Name, Surname, IDNumber FROM learnerdetails WHERE classID = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $classID);
    $stmt->execute();
    $result = $stmt->get_result();
} else {
    echo("No data found for classID:" . $classID);
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
