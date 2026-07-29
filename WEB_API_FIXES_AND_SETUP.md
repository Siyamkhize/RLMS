# Web API Fixes and Setup Guide

**Date:** July 10, 2026  
**Issue:** JSON parsing error when accessing `classes.php` - API returning HTML instead of JSON

---

## Problem Description

**Error Message:**
```
classes.php:214 Error: SyntaxError: Unexpected token '<', "<br /> <b>"... is not valid JSON
```

**Root Cause:**
- API endpoints were not properly handling errors
- PHP errors were being printed before JSON output
- Connection errors were outputting HTML error messages
- Headers weren't being set before any output

---

## Fixes Applied

### 1. All API Endpoints Updated

All 4 API files have been updated with proper error handling:
- `web/api/get_arpl_trades.php`
- `web/api/get_arpl_classes.php` ✅ FIXED
- `web/api/get_arpl_class_learners.php` ✅ FIXED
- `web/api/get_arpl_complete_data.php` ✅ FIXED

### 2. Key Changes Made

**A. Headers Set First**
```php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
```

**B. Error Suppression**
```php
ini_set('display_errors', 0);  // Prevent PHP errors showing in output
error_reporting(E_ALL);         // Still log errors internally
```

**C. Connection Path Handling**
```php
// Handle both web/api/ and root level access
$connection_file = file_exists('../../connection.php') ? '../../connection.php' : '../connection.php';

if (!file_exists($connection_file)) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Connection file not found']);
    exit;
}
```

**D. Better Error Checking**
```php
// Verify connection exists before using
if (!isset($conn) || !$conn) {
    throw new Exception('Database connection failed');
}

// Check statement execution
if (!$stmt->execute()) {
    throw new Exception('Query execution failed: ' . $stmt->error);
}
```

**E. JSON Encoding Options**
```php
// Ensure clean JSON output
echo json_encode($data, JSON_UNESCAPED_SLASHES);
```

---

## New Files Created

### 1. `web/connection.php`
```php
// Proxy file that loads the root connection.php
// Ensures web/api/ endpoints can find the database connection
```

This file:
- Locates the root `connection.php`
- Verifies connection is established
- Returns JSON error if connection fails

### 2. `web/test_api.php`
```
Interactive API tester for all endpoints
```

**Features:**
- Test each endpoint individually
- Change parameters (OFO code, Class ID, Learner ID)
- View formatted JSON responses
- Color-coded success/error output

**Access:** `http://localhost/web/test_api.php`

---

## How to Test

### Option 1: Use the Test Page
```
1. Navigate to http://localhost/web/test_api.php
2. Click "Test Get Trades" button
3. View formatted response
4. Adjust parameters and test other endpoints
```

### Option 2: Manual Testing
```bash
# Test get_arpl_classes.php
curl -X POST http://localhost/web/api/get_arpl_classes.php \
  -H "Content-Type: application/json" \
  -d '{"ofo_code":"671101"}'

# Expected response:
{
  "status": "success",
  "trade": "Electrician",
  "ofo_code": "671101",
  "classes": [...],
  "count": 5
}
```

### Option 3: Browser Console (from index.php)
```javascript
fetch('api/get_arpl_classes.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ofo_code: '671101'})
})
.then(r => r.json())
.then(data => console.log(data));
```

---

## Troubleshooting Checklist

### Issue: Still Getting JSON Parse Error

**Step 1: Enable Error Display Temporarily**
```php
// Add to top of test_api.php
ini_set('display_errors', 1);
error_reporting(E_ALL);
```

**Step 2: Check Browser Console**
- Open Developer Tools (F12)
- Go to Network tab
- Click on failed API request
- Check Response tab for actual error message

**Step 3: Check PHP Error Log**
```bash
# On Windows with XAMPP
tail -f C:\xampp\apache\logs\error.log
```

### Issue: 404 Not Found on API Endpoints

**Possible Causes:**
1. Web server not configured to serve `/web/` directory
2. .htaccess blocking API access
3. PHP not enabled for this directory

**Solution:**
```apache
# Add to web/.htaccess if needed
<FilesMatch "\.php$">
    Require all granted
</FilesMatch>

# Allow access to api subdirectory
<Directory "/path/to/rlmss/web/api">
    Require all granted
</Directory>
```

### Issue: Database Connection Error

**Check connection.php:**
```php
// Verify these are correct:
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "rlmsrlmsco_ezxcmacd_rlms";
```

**Test Connection:**
```php
<?php
require_once 'connection.php';

if ($conn->ping()) {
    echo "Connected successfully!";
} else {
    echo "Connection failed: " . $conn->error;
}
?>
```

---

## Verification Steps

### ✅ Step 1: Test Connection File
```bash
cd web
php -r "include 'connection.php'; echo 'OK';"
```

Expected output: `OK`

### ✅ Step 2: Test API Endpoint
```bash
curl -X POST http://localhost/web/api/get_arpl_trades.php \
  -H "Content-Type: application/json"
```

Expected output: Valid JSON with trades list

### ✅ Step 3: Test Full Flow
1. Open `index.php`
2. Select trade (Electrician)
3. Should load `classes.php` without JSON error
4. Classes should load correctly
5. Select a class
6. Should load `learners.php` without JSON error

### ✅ Step 4: Check Response Headers
```javascript
// In browser console
fetch('api/get_arpl_classes.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ofo_code: '671101'})
})
.then(r => {
    console.log('Content-Type:', r.headers.get('Content-Type'));
    return r.text();
})
.then(text => console.log('Response:', text))
```

Should see: `Content-Type: application/json; charset=utf-8`

---

## Performance Notes

- All endpoints use prepared statements (SQL injection prevention)
- Connections are closed in finally blocks
- Error handling prevents information leakage
- Response headers set before any output

---

## Common Issues Summary

| Issue | Cause | Solution |
|-------|-------|----------|
| "Unexpected token <" | PHP error before JSON | Check php.ini `display_errors` setting |
| Connection refused | Database not running | Start MySQL/MariaDB service |
| 500 error | Missing connection.php | Verify file at `../connection.php` |
| Empty classes list | No classes with OFO code | Check class.ofoNumber values in DB |
| No learners showing | Wrong enrollment status | Check enrollment status values in DB |

---

## Next Steps

1. **Test all endpoints** using `web/test_api.php`
2. **Verify database tables** have required data
3. **Check .htaccess** if APIs still not accessible
4. **Enable debug mode** if issues persist
5. **Proceed to Phase 3:** PDF generation implementation

---

## Support

If issues persist:
1. Check PHP error log at XAMPP installation
2. Verify MySQL database is running
3. Test connection using `php -i` to check mysqli extension
4. Review database table structure matches queries
5. Check user permissions for web directory

