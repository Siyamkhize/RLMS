<?php
/**
 * Simple verification endpoint to confirm the endpoint is reachable
 * Access: https://rlms.rlms.co.za/mobile/verify_appendix_f_endpoint.php
 */
header('Content-Type: application/json');

echo json_encode([
    'status' => 'success',
    'message' => 'Endpoint is reachable!',
    'timestamp' => date('Y-m-d H:i:s'),
    'directory' => __DIR__,
    'this_file' => basename(__FILE__),
    'save_file_exists' => file_exists(__DIR__ . '/save_appendix_f_data.php'),
    'save_file_path' => __DIR__ . '/save_appendix_f_data.php',
    'files_in_directory' => array_values(array_filter(
        scandir(__DIR__),
        fn($f) => str_starts_with($f, 'save_') && str_ends_with($f, '.php')
    ))
]);
?>
