<?php
/**
 * Simple file-based caching system for search results
 * Improves performance by caching frequent searches
 */

class SearchCache {
    private $cacheDir;
    private $defaultTTL;
    
    public function __construct($cacheDir = 'cache', $defaultTTL = 300) { // 5 minutes default
        $this->cacheDir = $cacheDir;
        $this->defaultTTL = $defaultTTL;
        
        // Create cache directory if it doesn't exist
        if (!is_dir($this->cacheDir)) {
            mkdir($this->cacheDir, 0755, true);
        }
    }
    
    /**
     * Generate cache key from parameters
     */
    private function getCacheKey($params) {
        return md5(serialize($params));
    }
    
    /**
     * Get cache file path
     */
    private function getCacheFile($key) {
        return $this->cacheDir . '/' . $key . '.cache';
    }
    
    /**
     * Get cached data if valid
     */
    public function get($params) {
        $key = $this->getCacheKey($params);
        $file = $this->getCacheFile($key);
        
        if (!file_exists($file)) {
            return null;
        }
        
        $data = json_decode(file_get_contents($file), true);
        
        if (!$data || !isset($data['expires']) || $data['expires'] < time()) {
            // Cache expired, delete file
            unlink($file);
            return null;
        }
        
        return $data['content'];
    }
    
    /**
     * Store data in cache
     */
    public function set($params, $content, $ttl = null) {
        $key = $this->getCacheKey($params);
        $file = $this->getCacheFile($key);
        $ttl = $ttl ?? $this->defaultTTL;
        
        $data = [
            'expires' => time() + $ttl,
            'content' => $content,
            'created' => time()
        ];
        
        file_put_contents($file, json_encode($data));
    }
    
    /**
     * Clear expired cache files
     */
    public function cleanup() {
        $files = glob($this->cacheDir . '/*.cache');
        $cleaned = 0;
        
        foreach ($files as $file) {
            $data = json_decode(file_get_contents($file), true);
            if (!$data || $data['expires'] < time()) {
                unlink($file);
                $cleaned++;
            }
        }
        
        return $cleaned;
    }
    
    /**
     * Clear all cache
     */
    public function clear() {
        $files = glob($this->cacheDir . '/*.cache');
        foreach ($files as $file) {
            unlink($file);
        }
        return count($files);
    }
}

// Usage in search endpoints
function getCachedSearchResults($params, $callback) {
    $cache = new SearchCache();
    
    // Try to get from cache first
    $cached = $cache->get($params);
    if ($cached !== null) {
        return $cached;
    }
    
    // Execute search and cache result
    $result = $callback();
    
    // Only cache successful results
    if (isset($result['success']) && $result['success']) {
        $cache->set($params, $result, 180); // Cache for 3 minutes
    }
    
    return $result;
}
?>