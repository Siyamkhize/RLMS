# Online Server Deployment - Files to Upload

## Overview
Three PHP files need to be uploaded to the online server to fix the ARPL role detection issue.

---

## File 1: mobile/login.php

### Location on Online Server
```
/public_html/mobile/login.php
```

### Key Changes
**Lines 213-230:** ARPL role detection improvement

**Critical Section:**
```php
// OLD CODE (Lines 213-215):
if ($dbRole === 'assessor') {
    $role = 'assessor';
} elseif (strpos($dbRole, 'arpl_assessor') !== false) {
    $role = 'arpl_assessor';
} elseif ($dbRole === 'moderator') {
    $role = 'Moderator';
} else {
    $role = 'facilitator';
}

// NEW CODE (Lines 213-230):
// Debug: Log the role detection
error_log("[LOGIN] Facilitator {$row['facilitator_id']}: DB role = '{$row['role']}', normalized = '$dbRole'");

if (strpos($dbRole, 'arpl') !== false && strpos($dbRole, 'assessor') !== false) {
    // Matches: arpl_assessor, arpl_Assessor, ARPL_Assessor, etc.
    $role = 'arpl_assessor';
    error_log("[LOGIN] Detected ARPL Assessor role");
} elseif ($dbRole === 'assessor') {
    $role = 'assessor';
    error_log("[LOGIN] Detected Assessor role");
} elseif ($dbRole === 'moderator') {
    $role = 'Moderator';
    error_log("[LOGIN] Detected Moderator role");
} else {
    $role = 'facilitator';
    error_log("[LOGIN] Defaulting to Facilitator role");
}
```

### Verification
After uploading, test by accessing the login endpoint and checking error logs for:
```
[LOGIN] Detected ARPL Assessor role
```

### Backup Before Uploading
```bash
cp /public_html/mobile/login.php /public_html/mobile/login.php.backup
```

---

## File 2: get_classes.php

### Location on Online Server
```
/public_html/get_classes.php
```

### Key Changes
**Line 43:** Fixed missing SQL variable declaration

**Critical Section:**
```php
// OLD CODE (Line 43):
// Missing: $sql = "..."
        SELECT DISTINCT
            c.classID,
            ...

// NEW CODE (Line 43-61):
$sql = "
    SELECT DISTINCT
        c.classID,
        c.className,
        c.siteID,
        s.siteName,
        s.project_id,
        s.Project_pathway,
        p.Project_name,
        COUNT(DISTINCT ld.LearnerID) as numberOfLearners
    FROM facilitator f
    INNER JOIN class c ON f.classID = c.classID
    INNER JOIN sites s ON c.siteID = s.siteID
    LEFT JOIN project p ON s.project_id = p.project_id
    LEFT JOIN learnerdetails ld ON c.classID = ld.classID
    WHERE f.facilitator_id = ?
    GROUP BY c.classID, c.className, c.siteID, s.siteName, s.project_id, s.Project_pathway, p.Project_name
    ORDER BY c.className
";
```

### Verification
After uploading, test endpoint:
```bash
curl "https://rlms.rlms.co.za/get_classes.php?facilitator_id=6" | jq '.[0] | keys'
```

Should include: `classID, className, siteID, siteName, project_id, Project_pathway, Project_name, numberOfLearners`

### Backup Before Uploading
```bash
cp /public_html/get_classes.php /public_html/get_classes.php.backup
```

---

## File 3: mobile/get_classes.php

### Location on Online Server
```
/public_html/mobile/get_classes.php
```

### Key Changes
**Lines 12-30:** Explicit column selection

**Critical Section:**
```php
// OLD CODE (Lines 12-14):
$query = "
    SELECT 
        s.project_id, 
        s.Project_pathway,
        c.* 
    FROM class c
    ...

// NEW CODE (Lines 12-30):
$query = "
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
        s.Project_pathway
    FROM class c
    JOIN sites s ON s.siteID = c.siteID
    JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
    WHERE f.facilitator_id = ?
    ORDER BY c.className
";

// Also add after loop (after line 25):
// Explicitly ensure Project_pathway is present in the response
if (empty($row['Project_pathway'])) {
    $row['Project_pathway'] = '';
}
```

### Verification
After uploading, test endpoint:
```bash
curl "https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=6" | jq '.[0]'
```

Should include `Project_pathway` field with JSON data like:
```json
{
  "classID": 797,
  "className": "class A",
  "Project_pathway": "[{\"type\":\"ARPL\",...}]"
}
```

### Backup Before Uploading
```bash
cp /public_html/mobile/get_classes.php /public_html/mobile/get_classes.php.backup
```

---

## Deployment Steps

### Step 1: Backup Current Files
```bash
ssh user@rlms.rlms.co.za

cd /public_html
cp mobile/login.php mobile/login.php.backup.$(date +%Y%m%d_%H%M%S)
cp get_classes.php get_classes.php.backup.$(date +%Y%m%d_%H%M%S)
cp mobile/get_classes.php mobile/get_classes.php.backup.$(date +%Y%m%d_%H%M%S)
```

### Step 2: Upload New Files
```bash
# Using SFTP or SCP from local machine:
sftp user@rlms.rlms.co.za
cd public_html

# Upload File 1
put mobile/login.php

# Upload File 2
put get_classes.php

# Upload File 3
put mobile/get_classes.php

quit
```

### Step 3: Verify Uploads
```bash
ssh user@rlms.rlms.co.za

# Check file sizes are correct
ls -lh /public_html/mobile/login.php
ls -lh /public_html/get_classes.php
ls -lh /public_html/mobile/get_classes.php

# Check for syntax errors
php -l /public_html/mobile/login.php
php -l /public_html/get_classes.php
php -l /public_html/mobile/get_classes.php
```

All should return: `No syntax errors detected in ...`

### Step 4: Test Endpoints
```bash
# Test login endpoint
curl -X POST https://rlms.rlms.co.za/mobile/login.php \
  -d "email=6&password=test" \
  | jq '.role'

# Should output: "arpl_assessor"

# Test get_classes endpoint
curl "https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=6" \
  | jq '.[0].Project_pathway' | head -c 50

# Should output: [{"type":"ARPL"...
```

### Step 5: Check Error Logs
```bash
# View PHP error log
tail -20 /path/to/php_error.log

# Should NOT show any parse errors for the three files
```

---

## Rollback Procedure

If something goes wrong:

```bash
ssh user@rlms.rlms.co.za

cd /public_html

# Restore from backups
cp mobile/login.php.backup.* mobile/login.php
cp get_classes.php.backup.* get_classes.php
cp mobile/get_classes.php.backup.* mobile/get_classes.php

# Verify restored
php -l mobile/login.php
php -l get_classes.php
php -l mobile/get_classes.php
```

---

## Local Versions for Reference

These are the files with the fixes already applied:

1. `c:\projects\rlmss\mobile\login.php` - Has ARPL role detection fix
2. `c:\projects\rlmss\get_classes.php` - Has SQL variable fix
3. `c:\projects\rlmss\mobile\get_classes.php` - Has column selection fix

---

## Post-Deployment Testing

### Test on Android Device

```bash
# 1. Build new APK
cd c:\projects\rlmss
flutter build apk --release

# 2. Install on device
adb install build/app/outputs/flutter-apk/app-release.apk

# 3. Point app to ONLINE server (edit config in app)

# 4. Login with facilitator 6

# 5. Check logs
adb logcat | grep "LOGIN.*Detected"

# Expected output:
# [LOGIN] Facilitator 6: DB role = 'arpl_Assessor', normalized = 'arpl_assessor'
# [LOGIN] Detected ARPL Assessor role
```

### Expected Result
- ARPL Dashboard appears (not regular Assessor dashboard)
- Drawer shows ARPL menu items (Toolkit, Appendices, etc.)
- No errors in logs

---

## Monitoring After Deployment

### Watch for Errors
```bash
# SSH to server
ssh user@rlms.rlms.co.za

# Monitor error log in real-time
tail -f /path/to/php_error.log | grep -E "LOGIN|get_classes"
```

### Check Success Rate
Monitor these logs after deployment:
- `[LOGIN] Detected ARPL Assessor role` = Success
- `[LOGIN] Detected Assessor role` = Regular assessor (expected)
- `[LOGIN] Defaulting to Facilitator role` = Unexpected, check logs

---

## Deployment Checklist

- [ ] Backup current PHP files
- [ ] Upload mobile/login.php
- [ ] Upload get_classes.php
- [ ] Upload mobile/get_classes.php
- [ ] Verify uploads: `php -l` on all three files
- [ ] Test endpoints with curl
- [ ] Build new APK
- [ ] Install APK on test device
- [ ] Login with facilitator 6
- [ ] Verify ARPL menu appears
- [ ] Check logs for success message
- [ ] Monitor server logs for any errors
- [ ] Approve for production use

---

## Success Criteria

✅ All PHP files upload without errors  
✅ `php -l` shows no syntax errors  
✅ Login endpoint returns `role: "arpl_assessor"` for facilitator 6  
✅ Get classes endpoint includes `Project_pathway`  
✅ New APK installed successfully  
✅ ARPL menu appears after login  
✅ No errors in server logs  

---

**Deployment Date:** July 14, 2026  
**Expected Duration:** 15-20 minutes  
**Risk Level:** Low (non-breaking change)
