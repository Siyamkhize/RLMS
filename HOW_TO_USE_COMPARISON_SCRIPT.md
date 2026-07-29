# How to Use the Local vs Online Comparison Script

## Overview

This script compares the ARPL assessor configuration between your LOCAL dev server and ONLINE server to identify exactly what's different.

**It will tell you:**
- ✅ What works locally that also works online
- ❌ What works locally but NOT on online
- 🔧 Exact fixes needed to match

---

## Setup

### Step 1: Deploy the Comparison Script

Upload the comparison script to your ONLINE server:

```
Source: c:\projects\rlmss\mobile\compare_local_vs_online.php
Destination: https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php
```

### Step 2: Verify Script Exists

Test that it works on both servers:

```bash
# Test LOCAL
curl http://192.168.0.57:8080/assessorReport2/mobile/compare_local_vs_online.php

# Test ONLINE
curl https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php
```

Both should return JSON output with no errors.

---

## Run the Comparison

### Option 1: PowerShell Script (Recommended)

```bash
cd c:\projects\rlmss

# Run the comparison
.\compare_servers.ps1
```

This will:
1. Fetch data from LOCAL server
2. Fetch data from ONLINE server  
3. Show side-by-side comparison
4. Highlight differences
5. Tell you what to fix

### Option 2: Manual Curl Commands

```bash
# Get LOCAL data
curl http://192.168.0.57:8080/assessorReport2/mobile/compare_local_vs_online.php > local_data.json

# Get ONLINE data
curl https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php > online_data.json

# Compare visually
diff local_data.json online_data.json
```

---

## What the Script Checks

### 1. **Connection Info**
```
Local Server: 192.168.0.57:8080
Online Server: rlms.rlmss.co.za

Checking:
- Host name
- PHP version
- MySQL version
- Server software
```

### 2. **Facilitator Check**
```
Queries: SELECT * FROM facilitator WHERE facilitator_id = 6

Checking:
- Facilitator exists
- Role value in database
- Role after trim/lowercase
- Email
- Assigned classes
```

### 3. **Role Detection**
```
Tests different ways to detect ARPL assessor:

✓ Test 1: exact match "assessor" (lowercase)
✓ Test 2: exact match "arpl_assessor" (lowercase)
✓ Test 3: contains "arpl" AND "assessor"
✓ Final: What role will app detect as
```

### 4. **Get Classes Query**
```
Checks if get_classes.php returns:
- classID ✓
- className ✓
- siteID ✓
- numberOfLearners ✓
- project_id ✓
- Project_pathway ✓  ← CRITICAL
```

### 5. **Pathway Detection**
```
Checks if Project_pathway contains:
- "ARPL" (case insensitive)
- "Bricklayer" (case insensitive)
- Proper JSON structure
```

---

## Reading the Output

### Example 1: Everything Works (Local)

```
[connection_info]
LOCAL:  {
  "status": "Connected",
  "host": "192.168.0.57",
  "database": "rlmss_local",
  ...
}
✓ MATCH
```

### Example 2: Something Different (Online)

```
[role_detection]
LOCAL:  {
  "detected_role": "arpl_assessor",
  "tests": { "contains_arpl": true, ... }
}
ONLINE: {
  "detected_role": "assessor",
  "tests": { "contains_arpl": false, ... }
}
✗ DIFFERENT
```

This means: **Online server is NOT detecting the role as ARPL!**

### Example 3: Missing Column (Online)

```
[get_classes_check]
LOCAL:  {
  "all_columns_present": {
    "Project_pathway": true,
    ...
  }
}
ONLINE: {
  "all_columns_present": {
    "Project_pathway": false,  ← PROBLEM!
    ...
  }
}
✗ DIFFERENT
```

This means: **Online get_classes.php is NOT returning Project_pathway column!**

---

## If You Find Differences

### Difference #1: Role Not Detected as ARPL

**Symptom:** 
```
Local:  "detected_role": "arpl_assessor"
Online: "detected_role": "assessor"
```

**Solution:**
Check what the role value is on online server:
```
Look for: "role_in_database" in online output
If it's: "arpl_Assessor", "ARPL_ASSESSOR", etc.
Then: Role detection logic needs to handle mixed case
Fix: Update mobile/login.php lines 213-230
```

### Difference #2: Project_pathway Column Missing

**Symptom:**
```
Local:  "Project_pathway": true
Online: "Project_pathway": false
```

**Solution:**
The online get_classes.php isn't returning Project_pathway column.

1. Check online file:
   ```bash
   ssh user@rlms.rlmss.co.za
   cat /public_html/mobile/get_classes.php | grep -A 10 "SELECT"
   ```

2. If missing Project_pathway in SELECT, update it:
   ```php
   SELECT 
       c.classID,
       c.className,
       c.siteID,
       c.numberOfLearners,
       c.instructorID,
       c.startDate,
       c.endDate,
       c.contact_hours,
       s.project_id, 
       s.Project_pathway  ← Add this
   ```

### Difference #3: Pathway Not Detected

**Symptom:**
```
Local:  "will_detect_as_arpl": true
Online: "will_detect_as_arpl": false
```

**Solution:**
The Project_pathway data on online server is different.

1. Check what's in Project_pathway column:
   ```
   Look for: "raw_pathway" in online output
   If empty: ()
   If contains SQL error: Database issue
   If contains "assessor": Wrong data
   ```

2. Verify data in database:
   ```bash
   ssh user@rlms.rlmss.co.za
   mysql -u root -p$DB_PASS $DB_NAME
   SELECT Project_pathway FROM sites WHERE siteID IN (
     SELECT siteID FROM class WHERE classID IN (
       SELECT classID FROM facilitator WHERE facilitator_id = 6
     )
   );
   ```

   Should return: `[{"type":"ARPL",...}]` or similar with ARPL/trade data

---

## What to Do After Finding Differences

### If Role Issue (Most Common)

```bash
# 1. Update mobile/login.php on online server
ssh user@rlms.rlmss.co.za

# 2. Backup
cp /public_html/mobile/login.php /public_html/mobile/login.php.backup

# 3. Upload new version from: c:\projects\rlmss\mobile\login.php

# 4. Verify
php -l /public_html/mobile/login.php
```

### If Project_pathway Missing

```bash
# 1. Update mobile/get_classes.php on online server
ssh user@rlms.rlmss.co.za

# 2. Backup
cp /public_html/mobile/get_classes.php /public_html/mobile/get_classes.php.backup

# 3. Upload new version from: c:\projects\rlmss\mobile/get_classes.php

# 4. Verify
php -l /public_html/mobile/get_classes.php
```

### If Data Issue (Project_pathway Empty)

```bash
# This requires database update
# The Project_pathway column in sites table doesn't have ARPL data

# Check with:
mysql> SELECT s.siteID, s.Project_pathway FROM sites s
       WHERE s.siteID IN (
         SELECT c.siteID FROM class c
         WHERE c.classID IN (
           SELECT classID FROM facilitator WHERE facilitator_id = 6
         )
       );

# If empty, you need to populate it
# Contact support or run update script
```

---

## Run Comparison Again to Verify

After making any fixes:

```bash
.\compare_servers.ps1
```

All checks should now show: **✓ MATCH**

And summary should show: **✓ All checks match between LOCAL and ONLINE servers!**

---

## Troubleshooting the Comparison Script

### "ERROR fetching LOCAL server"

**Problem:** Can't connect to local dev server

**Solution:**
```bash
# 1. Verify local dev server is running
# 2. Verify PHP is serving on 192.168.0.57:8080
# 3. Check firewall allows port 8080
# 4. Test with curl:
curl http://192.168.0.57:8080/assessorReport2/mobile/compare_local_vs_online.php
```

### "ERROR fetching ONLINE server"

**Problem:** Can't connect to online server

**Solution:**
```bash
# 1. Verify domain: rlms.rlmss.co.za
# 2. Verify script uploaded to: /public_html/mobile/compare_local_vs_online.php
# 3. Check with curl:
curl https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php

# 4. Check if SSL certificate is valid
curl -I https://rlms.rlmss.co.za
```

### Script returns empty JSON

**Problem:** Script runs but returns no data

**Solution:**
```bash
# 1. Check database connection in connection.php
# 2. Verify facilitator_id = 6 exists in database
# 3. Run directly on server:
ssh user@rlms.rlmss.co.za
php /public_html/mobile/compare_local_vs_online.php
# Should see JSON output
```

---

## Quick Reference

| Check | LOCAL ✓ | ONLINE ✓ | If Different |
|-------|---------|---------|--------------|
| Facilitator Found | Yes | Yes | Check facilitator table exists |
| Role Detected as ARPL | Yes | Yes | Update role detection logic |
| Project_pathway Column | Yes | Yes | Update get_classes.php query |
| Pathway Detects as ARPL | Yes | Yes | Check database Project_pathway data |
| No Critical Issues | Yes | Yes | All working! |

---

## Summary

This comparison script will:
1. ✅ Show you EXACTLY what's different
2. ✅ Point out which file needs fixing
3. ✅ Tell you what the error is
4. ✅ Let you verify the fix worked

**Next steps:**
1. Run: `.\compare_servers.ps1`
2. Read the output
3. Fix any differences found
4. Run again to verify

That's it!
