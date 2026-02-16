<?php
include 'connection.php';
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Get classID from GET or POST
$classID = null;
if (isset($_GET['classID'])) {
    $classID = $_GET['classID'];
} elseif (isset($_POST['classID'])) {
    $classID = $_POST['classID'];
}

if (!$classID) {
    echo json_encode([
        'error' => 'Invalid or missing classID parameter'
    ]);
    exit;
}

if (!$conn) {
    echo json_encode([
        'error' => 'Database connection failed'
    ]);
    exit;
}

try {
    // Query to get facilitator details for the class
    // facilitator table has classID linking to class table
    $query = "SELECT 
                c.classID,
                c.className,
                f.facilitator_id,
                f.firstName,
                f.lastName,
                f.IDNumber,
                f.email,
                f.phoneNumber,
                CONCAT(f.firstName, ' ', f.lastName) as FacilitatorFullName,
                s.siteName,
                pr.Project_name as qualification_name
              FROM class c
              LEFT JOIN facilitator f ON c.classID = f.classID
              LEFT JOIN sites s ON c.siteID = s.siteID
              LEFT JOIN project pr ON s.project_id = pr.project_id
              WHERE c.classID = ?";

    $stmt = $conn->prepare($query);
    $stmt->bind_param("s", $classID);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode([
            'error' => 'Class not found or no facilitator assigned',
            'classID' => $classID
        ]);
        exit;
    }
    
    $facilitatorDetails = [];
    while ($row = $result->fetch_assoc()) {
        $facilitatorDetails[] = [
            'classID' => $row['classID'],
            'className' => $row['className'] ?? 'Unknown Class',
            'facilitatorID' => $row['facilitator_id'],
            'firstName' => $row['firstName'] ?? 'Unknown',
            'lastName' => $row['lastName'] ?? 'Facilitator',
            'FacilitatorFullName' => $row['FacilitatorFullName'] ?? 'Unknown Facilitator',
            'IDNumber' => $row['IDNumber'] ?? '',
            'email' => $row['email'] ?? '',
            'phoneNumber' => $row['phoneNumber'] ?? '',
            'siteName' => $row['siteName'] ?? 'Unknown Site',
            'qualification_name' => $row['qualification_name'] ?? 'Unknown Qualification'
        ];
    }

    // Return the facilitator details array
    echo json_encode($facilitatorDetails);

} catch (Exception $e) {
    echo json_encode([
        'error' => 'Database query failed: ' . $e->getMessage(),
        'classID' => $classID
    ]);
}

$conn->close();
?>