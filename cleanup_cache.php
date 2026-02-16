<?php
/**
 * Cache cleanup script
 * Run this periodically to remove expired cache files
 */

require_once 'search_cache.php';

try {
    $cache = new SearchCache();
    
    echo "Starting cache cleanup...\n";
    
    // Clean expired cache files
    $cleaned = $cache->cleanup();
    
    echo "Cleaned $cleaned expired cache files.\n";
    
    // Optional: Clear all cache if requested
    if (isset($argv[1]) && $argv[1] === '--clear-all') {
        $total = $cache->clear();
        echo "Cleared all $total cache files.\n";
    }
    
    echo "Cache cleanup completed.\n";
    
} catch (Exception $e) {
    echo "Cache cleanup error: " . $e->getMessage() . "\n";
    exit(1);
}
?>