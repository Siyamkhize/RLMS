<?php
/**
 * Setup script for ARPL Appendix F tables and sample data
 * Run this once to initialize the tables
 */

header('Content-Type: application/json');
require_once 'mobile/connection.php';

try {
    // Create tables
    $sql_file = file_get_contents('create_arpl_appendix_f_tables.sql');
    $statements = explode(';', $sql_file);
    
    foreach ($statements as $stmt) {
        $stmt = trim($stmt);
        if (!empty($stmt)) {
            if ($conn->query($stmt) === FALSE) {
                throw new Exception("Error executing statement: " . $conn->error);
            }
        }
    }
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Appendix F tables created successfully',
        'tables' => [
            'arpl_appendix_f',
            'arpl_appendix_f_practical_tasks',
            'arpl_appendix_f_workplace_observations'
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
