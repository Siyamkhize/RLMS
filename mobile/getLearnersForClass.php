<?php
// Database connection parameters
include 'connection.php';

// Getting the siteID from the GET request
$siteID = isset($_GET['siteID']) ? $_GET['siteID'] : null;

if ($siteID) {
    // Establishing connection to the database
    try {
        $pdo = new PDO("mysql:host=$host;dbname=$dbname", $username, $password);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

        // Query to fetch learners based on siteID
        $sql = "SELECT learnerID, firstName, lastName, classID FROM learners WHERE siteID = :siteID";
        $stmt = $pdo->prepare($sql);
        $stmt->bindParam(':siteID', $siteID, PDO::PARAM_INT);
        $stmt->execute();

        // Fetching all results
        $learners = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Return response in JSON format
        echo json_encode($learners);

    } catch (PDOException $e) {
        // Catch any errors and return an error message
        echo json_encode(['error' => 'Database connection failed: ' . $e->getMessage()]);
    }
} else {
    echo json_encode(['error' => 'SiteID is required']);
}
?>
