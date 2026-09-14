<?php
// Set content type to JSON
header('Content-Type: application/json');

// Database connection settings
$host = 'localhost'; // Your database host
$dbname = 'your_database_name'; // Your database name
$username = 'your_database_user'; // Your database username
$password = 'your_database_password'; // Your database password

// Create a connection to the database
$conn = new mysqli($host, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Connection failed: " . $conn->connect_error]));
}

// Get raw POST data
$rawData = file_get_contents("php://input");

// Decode JSON data
$data = json_decode($rawData, true);

// Check if data is valid
if ($data === null) {
    echo json_encode(["status" => "error", "message" => "Invalid JSON data"]);
    exit();
}

// Assuming the unsynced data is passed as an array of records
foreach ($data as $record) {
    // Example: Insert each record into the 'unsynced_data' table
    // Modify this query based on your table structure and required fields
    $field1 = $conn->real_escape_string($record['field1']);
    $field2 = $conn->real_escape_string($record['field2']);
    // Add other fields as necessary

    $query = "INSERT INTO unsynced_data (field1, field2) VALUES ('$field1', '$field2')";

    if ($conn->query($query) !== TRUE) {
        echo json_encode(["status" => "error", "message" => "Failed to insert data: " . $conn->error]);
        exit();
    }
}

// If data was successfully inserted, send a success response
echo json_encode(["status" => "success", "message" => "Unsynced data synced successfully"]);

// Close the database connection
$conn->close();
?>
