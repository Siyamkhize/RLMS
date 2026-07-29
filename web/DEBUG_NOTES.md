# Web Module Debug Notes

## Issue Encountered

**User:** Tried to access web/index.php, then clicked "Continue to Classes"  
**Error Message:** 
```
classes.php:214 Error: SyntaxError: Unexpected token '<', "<br /> <b>"... is not valid JSON
```

**Location:** Line 214 of classes.php - in the `loadClasses()` function fetch response

---

## Root Cause Analysis

### What Was Happening

1. User clicks "Continue to Classes" in index.php
2. JavaScript calls: `fetch('api/get_arpl_classes.php', ...)`
3. PHP script runs but has an error
4. Instead of sending JSON, it sends HTML error page
5. JavaScript tries to parse HTML as JSON: `response.json()`
6. Parse fails because `<br />` is not valid JSON

### Why PHP Sent HTML

The old code had NO error handling. When something went wrong:
```php
// OLD CODE - PROBLEMATIC
header('Content-Type: application/json');
require_once '../connection.php';

try {
    $stmt = $conn->prepare($sql);
    // ... if error occurs here, PHP displays it as HTML
```

If `connection.php` failed OR `$conn` was invalid, PHP would show:
```html
<br />
<b>Fatal error</b>:  Uncaught Exception: Database connection failed in ...
```

---

## The Fix

### Step 1: Set Headers First
```php
// ALWAYS set JSON header at the very top
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

// THEN suppress error display
ini_set('display_errors', 0);
error_reporting(E_ALL);
```

### Step 2: Validate Before Using
```php
// Check connection exists
if (!isset($conn) || !$conn) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Database connection failed'
    ]);
    exit;
}
```

### Step 3: Check Query Execution
```php
// Old way - no error check
$stmt->execute();  // Silently fails!

// New way - explicit check
if (!$stmt->execute()) {
    throw new Exception('Query failed: ' . $stmt->error);
}
```

### Step 4: Always Use Try/Catch
```php
try {
    // ... all code here ...
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
```

---

## Files That Had This Issue

All 4 API endpoints were affected:

1. ❌ `get_arpl_trades.php` - Minimal error handling
2. ❌ `get_arpl_classes.php` - **TRIGGERED THE ERROR**
3. ❌ `get_arpl_class_learners.php` - Same issue
4. ❌ `get_arpl_complete_data.php` - Same issue

All 4 have been fixed.

---

## How to Reproduce the Old Error

1. Create a database connection that fails:
   ```php
   $conn = new mysqli('localhost', 'wrong_user', 'wrong_pass', 'wrong_db');
   ```

2. Run old API code - gets HTML error
3. Run fixed API code - gets JSON error

```json
{"status": "error", "message": "Database connection failed"}
```

---

## Testing to Verify Fix

### Test 1: Use test_api.php
```
http://localhost/web/test_api.php
```
- Click "Test Get Trades"
- Should see JSON response, not HTML error

### Test 2: Check Response Headers
```javascript
fetch('api/get_arpl_classes.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ofo_code: '671101'})
})
.then(r => {
    // Check Content-Type header
    console.log(r.headers.get('Content-Type'));
    // Should be: application/json; charset=utf-8
    return r.json();
})
.then(data => console.log('Data:', data))
.catch(e => console.error('Error:', e));
```

### Test 3: Intentional Error
```javascript
// Send invalid OFO code
fetch('api/get_arpl_classes.php', {
    method: 'POST',
    body: JSON.stringify({ofo_code: 'INVALID'})
})
.then(r => r.json())
.then(data => console.log(data));
// Should return: {"status": "error", "message": "Invalid OFO code..."}
```

---

## Common Mistakes That Cause Similar Errors

### ❌ Mistake 1: Output Before Headers
```php
// WRONG - will fail
echo "Something";
header('Content-Type: application/json');  // Too late!
```

### ❌ Mistake 2: Including File With Output
```php
// WRONG - connection.php might have output
require_once 'connection.php';
header('Content-Type: application/json');  // Too late if connection.php printed anything
```

### ❌ Mistake 3: No Error Catching
```php
// WRONG - errors print as HTML
$stmt->execute();
$result = $stmt->get_result();  // If execute() failed, this returns false
```

### ❌ Mistake 4: Displaying Errors
```php
// WRONG - errors show in response
ini_set('display_errors', 1);  // Shows errors as HTML
```

---

## Correct Pattern (Always Use This)

```php
<?php
// 1. Set headers FIRST
header('Content-Type: application/json; charset=utf-8');
ini_set('display_errors', 0);
error_reporting(E_ALL);

// 2. Load connection
$conn_file = __DIR__ . '/../connection.php';
if (!file_exists($conn_file)) {
    http_response_code(500);
    die(json_encode(['status' => 'error', 'message' => 'Connection file not found']));
}
require_once $conn_file;

// 3. Use try/catch for all operations
try {
    // Validate connection
    if (!isset($conn) || !$conn) {
        throw new Exception('No database connection');
    }
    
    // Do work
    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new Exception('Prepare failed: ' . $conn->error);
    
    $stmt->bind_param(...);
    if (!$stmt->execute()) throw new Exception('Execute failed: ' . $stmt->error);
    
    $result = $stmt->get_result();
    
    // Return success
    http_response_code(200);
    echo json_encode(['status' => 'success', 'data' => $data]);
    
} catch (Exception $e) {
    // Always return JSON error
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    
} finally {
    if (isset($conn)) $conn->close();
}
?>
```

---

## Verification Checklist

After fixes, verify:

- [ ] `web/test_api.php` loads without errors
- [ ] "Test Get Trades" returns valid JSON
- [ ] "Test Get Classes" returns valid JSON or proper error
- [ ] `index.php` → "Continue" → `classes.php` works
- [ ] `classes.php` loads classes without JSON error
- [ ] Select class → "View Learners" works
- [ ] `learners.php` loads learners without JSON error

---

## If Issues Persist

1. **Enable debug output temporarily:**
   ```php
   // Add to test_api.php only
   ini_set('display_errors', 1);
   ```

2. **Check browser console (F12):**
   - Network tab
   - Click failed request
   - Response tab shows actual error

3. **Check PHP error log:**
   - Windows XAMPP: `C:\xampp\apache\logs\error.log`
   - Linux: `/var/log/apache2/error.log`

4. **Verify database connection:**
   ```php
   <?php
   require_once 'connection.php';
   echo $conn->ping() ? 'Connected' : 'Failed: ' . $conn->error;
   ?>
   ```

---

## Summary

| Item | Status |
|------|--------|
| Root Cause | Identified ✅ |
| Files Fixed | 4 API endpoints ✅ |
| New Files | connection.php, test_api.php ✅ |
| Error Handling | Improved ✅ |
| JSON Output | Guaranteed ✅ |
| Testing Tool | Created ✅ |

The web module should now work correctly without JSON parsing errors.

