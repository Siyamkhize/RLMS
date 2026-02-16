# PHP Auto-Clocking Issue - Diagnosis & Fix Guide

## Problem
PHP endpoints are automatically inserting clock-in records when the app runs.

## Critical Files to Check

### 1. Upload Diagnostic Script to Server

Upload `php/diagnose_auto_clocking.php` to your server at:
```
https://rlms.rlms.co.za/mobile/diagnose_auto_clocking.php
```

Then visit that URL to see the diagnosis report. It will show:
- Recent clock-ins created today
- Database triggers that might auto-insert
- Scheduled events
- Stored procedures
- Table structure

### 2. Replace Sync Endpoint

Upload the corrected `php/sync_learner_clocking.php` to:
```
https://rlms.rlms.co.za/mobile/sync_learner_clocking.php
```

This version:
- ✅ **READ ONLY** - Only allows GET requests
- ✅ **NEVER INSERTS** - Only selects existing records
- ✅ **Detailed logging** - Logs all sync requests
- ✅ **Security check** - Rejects POST/PUT/DELETE requests

## Common Causes of Auto-Insertion

### Cause 1: Database Triggers
**Check for triggers:**
```sql
SHOW TRIGGERS WHERE `Table` = 'learner_clocking';
```

**Fix:** If any triggers exist that auto-insert records, disable them:
```sql
DROP TRIGGER IF EXISTS trigger_name_here;
```

### Cause 2: Default Values in Database
**Check for auto-generated values:**
```sql
SHOW COLUMNS FROM learner_clocking;
```

**Fix:** Ensure no columns have `DEFAULT CURRENT_TIMESTAMP` or auto-insert values except `clocking_id` (auto-increment).

### Cause 3: Stored Procedures
**Check for procedures:**
```sql
SELECT 
    ROUTINE_NAME, 
    ROUTINE_DEFINITION 
FROM information_schema.ROUTINES 
WHERE ROUTINE_SCHEMA = DATABASE()
AND ROUTINE_DEFINITION LIKE '%learner_clocking%';
```

**Fix:** Review and modify any procedures that auto-insert clock-in records.

### Cause 4: PHP Code Auto-Inserting
**Check these files on your server:**

1. `mobile/sync_learner_clocking.php` - Should ONLY SELECT, never INSERT
2. `mobile/clockin.php` - Should ONLY insert when POST request received
3. `mobile/sync_clocking.php` - Check if it inserts instead of selecting
4. Any cron jobs or scheduled scripts

**Signs of bad code:**
```php
// ❌ BAD - Auto-inserting in sync endpoint
$stmt = $conn->prepare("INSERT INTO learner_clocking ...");

// ✅ GOOD - Only selecting
$stmt = $conn->prepare("SELECT * FROM learner_clocking ...");
```

## Step-by-Step Diagnosis

### Step 1: Check Current Database State
```sql
-- How many clock-ins today?
SELECT 
    COUNT(*) as total_today,
    COUNT(DISTINCT LearnerID) as unique_learners
FROM learner_clocking 
WHERE clock_date = CURDATE();

-- Who clocked in today?
SELECT 
    lc.LearnerID,
    ld.Name,
    ld.Surname,
    lc.clock_in_time,
    lc.synced
FROM learner_clocking lc
LEFT JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID
WHERE lc.clock_date = CURDATE()
ORDER BY lc.clock_in_time DESC;
```

### Step 2: Monitor Real-Time Insertions

Enable MySQL general query log temporarily:
```sql
SET GLOBAL general_log = 'ON';
SET GLOBAL log_output = 'TABLE';

-- After testing, check what queries ran:
SELECT 
    event_time,
    user_host,
    command_type,
    argument 
FROM mysql.general_log 
WHERE argument LIKE '%learner_clocking%'
AND command_type = 'Query'
ORDER BY event_time DESC 
LIMIT 50;

-- Disable when done:
SET GLOBAL general_log = 'OFF';
```

### Step 3: Check PHP Error Logs

On your server, check:
```bash
tail -f /var/log/apache2/error.log | grep -i "clock"
# or
tail -f /var/log/php/error.log | grep -i "clock"
```

Look for:
- INSERT statements
- Clock-in attempts
- Sync operations

### Step 4: Test Sync Endpoint Directly

Test your sync endpoint in a browser:
```
https://rlms.rlms.co.za/mobile/sync_learner_clocking.php?clock_date=2025-10-18
```

**Before visiting:** Note the number of records in database
**After visiting:** Check if NEW records were created

If NEW records appear, the sync endpoint is WRITING when it should only READ!

## Fix Implementation

### Fix 1: Ensure Sync is Read-Only

Your `sync_learner_clocking.php` should:

```php
<?php
// ONLY allow GET requests
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'READ ONLY']);
    exit;
}

// ONLY SELECT, never INSERT
$stmt = $conn->prepare("
    SELECT * FROM learner_clocking 
    WHERE clock_date = ? 
    AND LearnerID IN (
        SELECT LearnerID FROM learnerdetails WHERE classID = ?
    )
");
$stmt->bind_param("ss", $clock_date, $classID);
$stmt->execute();
$result = $stmt->get_result();

// Return data
echo json_encode($result->fetch_all(MYSQLI_ASSOC));
?>
```

### Fix 2: Add Logging to Clock-In Endpoint

Modify `mobile/clockin.php` to log every attempt:

```php
<?php
// At the start of clockin.php
$logEntry = date('Y-m-d H:i:s') . " - Clock-in attempt\n";
$logEntry .= "LearnerID: " . ($_POST['LearnerID'] ?? 'none') . "\n";
$logEntry .= "Source IP: " . $_SERVER['REMOTE_ADDR'] . "\n";
$logEntry .= "User Agent: " . $_SERVER['HTTP_USER_AGENT'] . "\n";
$logEntry .= "POST data: " . json_encode($_POST) . "\n\n";
file_put_contents('clockin_log.txt', $logEntry, FILE_APPEND);

// ... rest of clock-in code ...
?>
```

### Fix 3: Clear Test/Duplicate Records

If you have test records or duplicates, clean them:

```sql
-- CAREFUL: This deletes records!
-- First, backup the table:
CREATE TABLE learner_clocking_backup AS SELECT * FROM learner_clocking;

-- Option 1: Delete all today's records (if they're all fake)
DELETE FROM learner_clocking WHERE clock_date = CURDATE();

-- Option 2: Keep only the earliest clock-in per learner today
DELETE lc1 FROM learner_clocking lc1
INNER JOIN learner_clocking lc2 
WHERE lc1.clock_date = CURDATE()
AND lc2.clock_date = CURDATE()
AND lc1.LearnerID = lc2.LearnerID 
AND lc1.clocking_id > lc2.clocking_id;
```

## Verification Checklist

After applying fixes:

- [ ] Run `diagnose_auto_clocking.php` - Should show 0 triggers, 0 events
- [ ] Visit sync endpoint - Should NOT create new records
- [ ] Login to app - Should NOT create records
- [ ] Test manual clock-in with fingerprint - SHOULD create record
- [ ] Check PHP error logs - Should show only legitimate clock-in attempts
- [ ] Check database - Only records from actual fingerprint scans

## Expected Behavior After Fixes

✅ **Sync endpoints** - Only read existing records, never insert
✅ **Clock-in endpoint** - Only insert when POST request with valid data
✅ **App login** - Only displays synced records, doesn't create new ones
✅ **Fingerprint scan** - Creates ONE record per learner per day
✅ **No duplicates** - Each learner can only clock in once per day

## Monitoring

To ensure the issue doesn't return, set up monitoring:

```php
// In clockin.php, add alert for suspicious activity
$todayCount = $conn->query("
    SELECT COUNT(*) as count 
    FROM learner_clocking 
    WHERE clock_date = CURDATE()
")->fetch_assoc()['count'];

if ($todayCount > 100) {
    mail(
        'admin@rlms.co.za',
        'ALERT: High clock-in volume',
        "Unusual number of clock-ins today: $todayCount"
    );
}
```

## Support Files Created

1. `php/diagnose_auto_clocking.php` - Diagnostic tool
2. `php/sync_learner_clocking.php` - Corrected sync endpoint (READ ONLY)
3. `php/clockin.php` - Already has logging (from your existing file)

## Need More Help?

If issue persists after these fixes, collect this information:

1. Output from `diagnose_auto_clocking.php`
2. Last 50 lines from PHP error log
3. Query log showing INSERT statements
4. Screenshot of records in database

This will help identify the exact source of auto-insertions.

