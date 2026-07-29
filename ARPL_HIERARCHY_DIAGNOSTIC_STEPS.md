# ARPL Hierarchy Diagnostic Steps - HTTP 500 Error Fix
**Date: July 23, 2026**
**Status: Diagnostic Phase**

---

## 🎯 Current Issue

**Problem:** HTTP 500 error when accessing `test_arpl_hierarchy_endpoint.php`

**Likely Causes:**
1. Missing or incorrect `connection.php` include path
2. Missing `security_functions.php` dependency
3. PHP syntax error not caught locally
4. Database connection failure
5. Missing database tables

---

## 📋 Step 1: Upload Diagnostic Script

### Upload This File:
```
Source: c:\projects\rlmss\diagnose_arpl_500_error.php
Destination: /public_html/diagnose_arpl_500_error.php
```

### Access Via Browser:
```
https://rlms.rlms.co.za/diagnose_arpl_500_error.php
```

### What It Checks:
- ✅ PHP version
- ✅ File existence (connection.php, security_functions.php, get_arpl_hierarchy.php)
- ✅ Database connection
- ✅ Required tables (learnerdetails, class, arpl_trades, arpl_papers, arpl_questions)
- ✅ Test query for learner 11701
- ✅ Actual execution of get_arpl_hierarchy.php
- ✅ Detailed error messages with line numbers

---

## 📊 Step 2: Analyze Diagnostic Output

### Look For These Patterns:

#### ✅ Success Pattern:
```
✓ mobile/connection.php (readable)
✓ Connection object created
✓ Database connected: localhost via TCP/IP
✓ Table 'arpl_trades' exists
✓ Found learner 11701, classID: 797
✓ Trade name: Bricklaying
✓ Execution completed
✓ Valid JSON response
✓ Trades found: Bricklaying
```

#### ❌ Error Pattern 1: Missing File
```
✗ mobile/connection.php
✗ mobile/security_functions.php
```
**Fix:** Upload missing files

#### ❌ Error Pattern 2: Include Path Error
```
✗ Fatal error: Failed opening required 'connection.php'
```
**Fix:** Change include path in get_arpl_hierarchy.php

#### ❌ Error Pattern 3: Database Connection Error
```
✗ Connection error: Access denied for user
```
**Fix:** Check database credentials in connection.php

#### ❌ Error Pattern 4: Missing Tables
```
✗ Table 'arpl_trades' NOT FOUND
```
**Fix:** Run SQL scripts to create tables

---

## 🔧 Step 3: Common Fixes

### Fix 1: Connection.php Include Path Issue

**If diagnostic shows:** `Failed to open 'connection.php'`

**Update get_arpl_hierarchy.php:**
```php
// Try different include paths
// Option 1: Same directory
include_once 'connection.php';

// Option 2: Relative path
include_once __DIR__ . '/connection.php';

// Option 3: Absolute path
include_once $_SERVER['DOCUMENT_ROOT'] . '/mobile/connection.php';
```

---

### Fix 2: Security Functions Missing

**If diagnostic shows:** `security_functions.php not found`

**Check these locations:**
1. `/public_html/mobile/security_functions.php`
2. `/public_html/security_functions.php`

**Upload from:**
```
Source: c:\projects\rlmss\mobile\security_functions.php
Destination: /public_html/mobile/security_functions.php
```

---

### Fix 3: Database Tables Missing

**If diagnostic shows:** `Table 'arpl_trades' NOT FOUND`

**Run these SQL scripts in phpMyAdmin:**
1. Check if `arpl_trades` table exists
2. Check if `arpl_papers` table exists
3. Check if `arpl_questions` table exists

**Quick Check Query:**
```sql
SHOW TABLES LIKE 'arpl%';
```

---

### Fix 4: Wrong Database Connection

**If diagnostic shows:** `Database connection failed`

**Check connection.php settings:**
```php
$servername = "localhost";
$username = "root";  // Check this
$password = "";      // Check this
$dbname = "rlmsrlmsco_ezxcmacd_rlms";  // Check this
```

---

## 🚀 Step 4: After Diagnostic Complete

### Once Diagnostic Shows Success:

1. **Remove test files:**
   ```
   DELETE: /public_html/test_arpl_hierarchy_endpoint.php
   DELETE: /public_html/diagnose_arpl_500_error.php
   ```

2. **Upload fixed get_arpl_hierarchy.php:**
   ```
   Source: c:\projects\rlmss\mobile\get_arpl_hierarchy.php
   Destination: /public_html/mobile/get_arpl_hierarchy.php
   ```

3. **Test endpoint with cURL:**
   ```bash
   curl "https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701"
   ```

4. **Expected response:**
   ```json
   {
     "pathways": {
       "ARPL": {
         "qualifications": {
           "Bricklaying": {
             "theory_papers": {...},
             "practical_papers": {...}
           }
         }
       }
     }
   }
   ```

5. **Test on device:**
   ```bash
   # Monitor logs
   adb logcat | findstr ARPL
   ```

---

## 📱 Step 5: Device Testing

### Login Flow:
1. Open app
2. Login as ARPL Assessor (User ID: 6)
3. View Bricklayer class
4. Select learner (e.g., 11701)
5. View ARPL Portfolio breakdown

### Expected UI:
```
ARPL Portfolio - Bricklaying  ← Should show "Bricklaying" not "Electrician"
├─ Theory Papers
│  ├─ Theory Paper 1
│  ├─ Theory Paper 2
│  └─ Theory Paper 3
└─ Practical Papers
   ├─ Practical Paper 1
   └─ Practical Paper 2
```

### Monitor Logs:
```bash
adb logcat | findstr "ARPL\|TRADE"
```

### Expected Log Output:
```
[ARPL_TRADE] ✅ Trade name: Bricklaying
ARPL API Response: {"pathways":{"ARPL":{"qualifications":{"Bricklaying":{...}}}}}
ARPL DEBUG DATA: ["From arpl_trades table - Trade: Bricklaying, OFO: 641201"]
```

---

## 📝 Troubleshooting Checklist

### Server-Side Issues:
- [ ] Diagnostic script uploaded to `/public_html/`
- [ ] Diagnostic accessed via browser (not 500 error)
- [ ] Diagnostic shows all files exist
- [ ] Diagnostic shows database connection success
- [ ] Diagnostic shows all tables exist
- [ ] Diagnostic shows learner 11701 found
- [ ] Diagnostic shows trade query returns "Bricklaying"
- [ ] Diagnostic shows valid JSON response

### File Upload Issues:
- [ ] File permissions set to 644 for PHP files
- [ ] Directory permissions set to 755 for mobile/
- [ ] Files uploaded in ASCII/text mode (not binary)
- [ ] No UTF-8 BOM at start of PHP files

### PHP Configuration Issues:
- [ ] PHP version 7.4 or higher
- [ ] mysqli extension enabled
- [ ] json extension enabled
- [ ] max_execution_time at least 60 seconds
- [ ] memory_limit at least 128M

---

## 🔍 Quick Commands Reference

### Check PHP Error Log:
```bash
tail -f /var/log/php_errors.log
```

### Check Apache Error Log:
```bash
tail -f /var/log/apache2/error.log
```

### Test PHP Syntax Locally:
```bash
php -l mobile/get_arpl_hierarchy.php
```

### Clear PHP OpCache:
```php
<?php opcache_reset(); echo "Cache cleared"; ?>
```

---

## 📊 Expected Diagnostic Output (Success Case)

```
ARPL Hierarchy 500 Error Diagnostic
====================================

1. PHP Version: 7.4.33

2. File System Check:
   ✓ mobile/connection.php (readable)
   ✓ mobile/security_functions.php (readable)
   ✓ mobile/get_arpl_hierarchy.php (readable)
   ✓ connection.php (readable)
   ✓ security_functions.php (readable)

3. Testing Connection Include:
   Using path: mobile/connection.php
   ✓ Connection object created
   ✓ Database connected: localhost via TCP/IP

4. Testing Database Tables:
   ✓ Table 'learnerdetails' exists
   ✓ Table 'class' exists
   ✓ Table 'arpl_trades' exists
   ✓ Table 'arpl_papers' exists
   ✓ Table 'arpl_questions' exists

5. Testing ARPL Trade Query (learner 11701):
   ✓ Found learner 11701, classID: 797
   ✓ Class trade_id: 1
   ✓ Trade name: Bricklaying
   ✓ OFO number: 641201

6. Testing get_arpl_hierarchy.php Execution:
   Attempting to execute with learner_id=11701...
   ✓ Execution completed
   Output length: 5432 bytes
   ✓ Valid JSON response
   ✓ Trades found: Bricklaying
   Debug messages: 8 items
     - Found learner: {...}
     - Found class with trade_id: 1
     - From arpl_trades table - Trade: Bricklaying, OFO: 641201
     - Final trade selected: Bricklaying (OFO: 641201)
     - Total papers loaded: 5
     - Created paper structure with 5 papers
     - Total questions processed: 50

====================================
Diagnostic Complete
Save this output and share with developer
```

---

## ✅ Success Criteria

**Before proceeding to device test, ensure:**
1. ✅ Diagnostic script runs without 500 error
2. ✅ All required files found and readable
3. ✅ Database connection successful
4. ✅ All required tables exist
5. ✅ Test query returns "Bricklaying" not "Electrician"
6. ✅ get_arpl_hierarchy.php execution completes
7. ✅ Valid JSON response generated
8. ✅ Response contains "Bricklaying" qualification

---

## 🎯 Next Action

**RIGHT NOW:**
1. Upload `diagnose_arpl_500_error.php` to server
2. Access via browser: `https://rlms.rlms.co.za/diagnose_arpl_500_error.php`
3. Review output
4. Apply fixes based on diagnostic results
5. Re-run diagnostic until all checks pass
6. Upload corrected `mobile/get_arpl_hierarchy.php`
7. Test endpoint
8. Test on device

---

**File Ready:** ✅ `diagnose_arpl_500_error.php`
**Upload Location:** `/public_html/diagnose_arpl_500_error.php`
**Access URL:** `https://rlms.rlms.co.za/diagnose_arpl_500_error.php`

**Status:** ⏳ Awaiting diagnostic results
