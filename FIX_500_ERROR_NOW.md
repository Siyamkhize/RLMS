# 🚨 FIX 500 ERROR - CRITICAL ISSUE FOUND

## THE REAL PROBLEM

The ArplAssessorPage **IS loading** (shows "Assessor Dashboard" and "Facilitator ID: 6"), but it's getting a **500 Internal Server Error** when trying to fetch classes!

**Error shown on screen:**
```
Error: Exception: Failed to load classes. Error: Exception: 
Failed to load classes. Server error: 500
```

**This means:** `mobile/get_classes.php` is crashing on the ONLINE server with a PHP error.

---

## POSSIBLE CAUSES

### 1. Missing `security_functions.php`
The `mobile/connection.php` requires:
```php
require_once __DIR__ . '/security_functions.php';
```

If this file is missing or has errors on ONLINE server → 500 error

### 2. Database Connection Error
The connection credentials might be wrong on ONLINE server

### 3. Missing Column `Project_pathway`
If the ONLINE `sites` table doesn't have `Project_pathway` column → SQL error → 500

### 4. PHP Version Issues
The query uses features that might not work on ONLINE server's PHP version

---

## DIAGNOSTIC FILES CREATED

I've created test scripts to diagnose the issue:

### Test 1: Simple Database Test
```
mobile/test_simple_get_classes.php
```

This tests:
- ✓ PHP works
- ✓ Database connection works
- ✓ Facilitator exists
- ✓ get_classes query works

**Upload this and access:**
```
https://rlms.rlms.co.za/mobile/test_simple_get_classes.php?facilitator_id=6
```

### Test 2: Full Diagnostic Test
```
mobile/test_get_classes.php
```

This tests the exact same code as `get_classes.php` with detailed logging.

**Upload this and access:**
```
https://rlms.rlms.co.za/mobile/test_get_classes.php?facilitator_id=6
```

---

## IMMEDIATE ACTIONS

### Action 1: Upload Test Scripts

Upload these files to ONLINE server:
1. `mobile/test_simple_get_classes.php`
2. `mobile/test_get_classes.php`

### Action 2: Run Tests

Access in browser:
1. https://rlms.rlms.co.za/mobile/test_simple_get_classes.php?facilitator_id=6
2. https://rlms.rlms.co.za/mobile/test_get_classes.php?facilitator_id=6

### Action 3: Check Server Error Logs

On the ONLINE server, check PHP error logs:
- `/var/log/php-errors.log`
- Or cPanel → Error Logs
- Look for errors around the time you tried to log in

### Action 4: Verify Files Exist on ONLINE Server

Check these files exist:
- ✓ `mobile/connection.php`
- ✓ `mobile/security_functions.php`
- ✓ `mobile/get_classes.php`

---

## EXPECTED TEST RESULTS

### IF test_simple_get_classes.php WORKS:

You'll see:
```
✓ PHP is working
✓ Database connected
✓ Facilitator found:
  ID: 6
  Role: arpl_assessor
  ClassID: 797
✓ Query prepared
✓ Query executed
✓ Found 1 classes

First class:
Array (
    [classID] => 797
    [className] => class A
    [Project_pathway] => [{"type":"ARPL","name":"Bricklayer"}]
    ...
)

===== ALL TESTS PASSED =====
```

**If this works but get_classes.php fails** → The issue is in `connection.php` or `security_functions.php`

### IF test_simple_get_classes.php FAILS:

You'll see an error message showing exactly what's wrong:
- ✗ Connection failed: ...
- ✗ Query prepare failed: ...
- ✗ Unknown column 'Project_pathway' ...

---

## MOST LIKELY CAUSE

Based on the 500 error, I suspect **ONE of these**:

1. **Missing `security_functions.php` on ONLINE server**
   - Local has it, ONLINE doesn't
   - Fix: Upload `mobile/security_functions.php` to ONLINE

2. **Wrong database credentials in `mobile/connection.php` on ONLINE**
   - Local uses `root` / no password
   - ONLINE uses different credentials
   - Fix: Update `connection.php` on ONLINE server

3. **Column `Project_pathway` doesn't exist on ONLINE**
   - But we know it does from your earlier test
   - Less likely

---

## FILES TO UPLOAD TO ONLINE SERVER

Priority order:

### 1. Test Scripts (UPLOAD FIRST):
- `mobile/test_simple_get_classes.php` ← START HERE
- `mobile/test_get_classes.php`

### 2. If tests pass, upload fixes:
- `mobile/login.php` (with Project_pathway fix)
- `mobile/security_functions.php` (if missing)
- `mobile/get_classes.php` (refresh to ensure latest)

---

## TROUBLESHOOTING STEPS

### Step 1: Upload test_simple_get_classes.php
Upload and access in browser

### Step 2: Check result
- **If works** → Database and query are fine, issue is in connection.php includes
- **If fails** → Shows exact error message

### Step 3: Based on result:
- **Connection error** → Fix database credentials
- **Column error** → Verify Project_pathway column exists
- **Include error** → Upload missing security_functions.php

### Step 4: Fix and retry
- Upload fixed files
- Test login again
- Should see ARPL menu

---

## WHAT TO SEND ME

After uploading test scripts, send me:

1. **Output from:**
   ```
   https://rlms.rlms.co.za/mobile/test_simple_get_classes.php?facilitator_id=6
   ```

2. **Server error logs** (if available)

3. **Confirmation of which files exist on ONLINE server:**
   - mobile/connection.php ✓ or ✗
   - mobile/security_functions.php ✓ or ✗
   - mobile/get_classes.php ✓ or ✗

---

## QUICK SUMMARY

**Problem:** 500 error when fetching classes  
**Cause:** PHP crash in `mobile/get_classes.php`  
**Fix:** Upload test scripts to diagnose exact error  
**Next:** Based on test results, upload correct fixes  

**DO THIS NOW:** Upload `mobile/test_simple_get_classes.php` and access it in browser!
