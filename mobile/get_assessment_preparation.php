<?php
// Enable error reporting for debugging (disable display in production)
error_reporting(E_ALL);
ini_set('display_errors', 0); // Set to 1 for debugging, 0 for production
ini_set('log_errors', 1);
ini_set('error_log', '/path/to/your/error.log'); // Update to a valid path

// Set content type to JSON
header('Content-Type: application/json; charset=UTF-8');

// Include database connection
require_once 'connection.php'; // Ensure this sets up $conn (e.g., mysqli_connect)

// Start try-catch for error handling
try {
    // Validate facilitator_id
    $facilitator_id = $_GET['facilitator_id'] ?? null;
    if (!$facilitator_id) {
        throw new Exception('Missing facilitator_id parameter');
    }

    // Verify database connection
    if ($conn->connect_error) {
        throw new Exception('Database connection failed: ' . $conn->connect_error);
    }

    // SQL query to retrieve Project_pathway JSON
    $query = "
        SELECT DISTINCT 
            c.classID,
            p.Project_pathway
        FROM 
            facilitator f
        CROSS JOIN 
            (
                SELECT n + 1 AS n
                FROM (
                    SELECT a.N + b.N * 10 + c.N * 100 AS n
                    FROM 
                        (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 
                         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
                        (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 
                         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b,
                        (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 
                         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c
                ) numbers
                WHERE n <= (
                    SELECT MAX(LENGTH(classID) - LENGTH(REPLACE(classID, ',', '')) + 1) 
                    FROM facilitator
                )
            ) AS num
        LEFT JOIN 
            class c ON TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(f.classID, ',', num.n), ',', -1)) = c.classID
        LEFT JOIN 
            sites s ON c.siteID = s.siteID
        LEFT JOIN 
            project p ON s.project_id = p.project_id
        WHERE 
            f.facilitator_id = ?
            AND p.Project_pathway IS NOT NULL
        GROUP BY 
            c.classID, p.Project_pathway;
    ";

    // Prepare statement
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }

    // Bind facilitator_id (assuming string; use "i" if integer)
    $stmt->bind_param('s', $facilitator_id);

    // Execute query
    if (!$stmt->execute()) {
        throw new Exception('Query execution failed: ' . $stmt->error);
    }

    // Fetch results
    $result = $stmt->get_result();
    $unitStandards = [];

    // Process JSON in PHP
    while ($row = $result->fetch_assoc()) {
        if (!empty($row['Project_pathway'])) {
            $pathwayData = json_decode($row['Project_pathway'], true);
            if (json_last_error() !== JSON_ERROR_NONE) {
                throw new Exception('Invalid JSON in Project_pathway: ' . json_last_error_msg());
            }

            // Extract unit standards from JSON
            foreach ($pathwayData as $pathway) {
                if (isset($pathway['qual_types']) && is_array($pathway['qual_types'])) {
                    foreach ($pathway['qual_types'] as $qualType) {
                        if (isset($qualType['qualification']['unitStandards']) && is_array($qualType['qualification']['unitStandards'])) {
                            foreach ($qualType['qualification']['unitStandards'] as $unitStandard) {
                                if (isset($unitStandard['id'], $unitStandard['name'])) {
                                    $unitStandards[] = [
                                        'unitstandard_id' => $unitStandard['id'],
                                        'unitstandard_name' => $unitStandard['name'] ?? 'Unknown Unit Standard'
                                    ];
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Remove duplicates
    $unitStandards = array_values(array_unique($unitStandards, SORT_REGULAR));

    // Return response
    echo json_encode([
        'status' => 'success',
        'data' => $unitStandards,
        'message' => empty($unitStandards) ? 'No unit standards found for this facilitator' : null
    ]);

    // Clean up
    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    // Set HTTP response code for client errors
    http_response_code(400);

    // Log error
    error_log('Error in get_assessment_preparation.php: ' . $e->getMessage());

    // Return error response
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);

    // Clean up if applicable
    if (isset($stmt)) {
        $stmt->close();
    }
    if (isset($conn) && $conn->ping()) {
        $conn->close();
    }
}
?>