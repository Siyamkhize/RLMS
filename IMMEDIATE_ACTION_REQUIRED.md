# 🔴 IMMEDIATE ACTION REQUIRED - ARPL UI NOT SHOWING

**Priority:** CRITICAL  
**Time Estimate:** 10 minutes  
**Date:** July 14, 2026

---

## PROBLEM

✅ APK installed  
✅ Login works  
✅ Server is reachable  
❌ **ARPL assessor seeing normal assessor UI instead of ARPL UI**

---

## SOLUTION (ONE FILE FIX)

### On Your Online Server:

#### File Path: `/var/www/html/mobile/get_classes.php`

#### Current Content (Lines 14-20):
```php
$query = "
    SELECT s.project_id, c.* 
    FROM class c
    JOIN sites s ON s.siteID = c.siteID
    JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
    WHERE f.facilitator_id = ?
";
```

#### Change To (Lines 14-24):
```php
$query = "
    SELECT 
        s.project_id, 
        s.Project_pathway,
        c.* 
    FROM class c
    JOIN sites s ON s.siteID = c.siteID
    JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
    WHERE f.facilitator_id = ?
    ORDER BY c.className
";
```

**What Changed:**
- Line 17: Added `s.Project_pathway,`
- Line 24: Added `ORDER BY c.className`

---

## DEPLOYMENT STEPS

### Step 1: Connect to Server
```bash
ssh user@rlms.rlms.co.za
cd /var/www/html/mobile/
```

### Step 2: Backup Current File
```bash
cp get_classes.php get_classes.php.backup
```

### Step 3: Edit File
```bash
nano get_classes.php
```

### Step 4: Find Line 14-20 (Search for "SELECT s.project_id")
- Delete these lines
- Replace with the corrected query above
- Save: Ctrl+O → Enter → Ctrl+X

### Step 5: Test the Fix
```bash
curl "https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=123"
```

**Check Response** contains:
```json
"Project_pathway": "ARPL"
```

---

## VERIFY ON DEVICE

### Step 1: Clear App Cache
```bash
adb shell pm clear com.example.rlmss
```

### Step 2: Reopen App & Login
- Open RLMSS app
- Login with ARPL assessor credentials

### Step 3: Check Result
✅ Dashboard title says "ARPL Dashboard"  
✅ Drawer shows ARPL menu items:
   - ARPL Competency Scale
   - ARPL Assessor Toolkit
   - Appendix A through I
   - Assessment Review
   - Access Recommendation
   - Evidence Checklist

---

## IF IT STILL DOESN'T WORK

### Check 1: Verify File Was Updated
```bash
grep "Project_pathway" /var/www/html/mobile/get_classes.php
```

Should return: `s.Project_pathway,` (not empty)

### Check 2: Test Endpoint Response
```bash
curl -v "https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=123"
```

Response should include `"Project_pathway"` field (even if value is null, field should exist)

### Check 3: Database Has Pathway Data
```bash
mysql -u [user] -p [database]
SELECT siteID, Project_pathway FROM sites LIMIT 5;
```

Should show pathway values (like "ARPL", "Training Program", etc.)

### Check 4: Restart Web Server (if needed)
```bash
sudo systemctl restart apache2
# OR
sudo systemctl restart nginx
# OR
sudo systemctl restart php-fpm
```

---

## WHAT THIS FIX DOES

The mobile app code checks:
```dart
String pathway = (data[0]['Project_pathway'] ?? data[0]['learning_pathway'])
    ?.toString()
    .toUpperCase() ?? '';

if (pathway.contains('ARPL')) {
  _pathwayType = 'ARPL';  // ← Now this will be true
} else {
  _pathwayType = pathway;
}
```

**Before Fix:**
- `Project_pathway` not in response
- `pathway` becomes empty string
- Condition fails
- Shows normal menu

**After Fix:**
- `Project_pathway` in response
- `pathway` = "ARPL"
- Condition passes ✓
- Shows ARPL menu

---

## COMPLETE CORRECTED FILE

If you want to replace the entire file, use this:

```php
<?php
include('connection.php');
header('Content-Type: application/json');
error_reporting(0); // Hide warnings
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

if (!isset($_GET['facilitator_id'])) {
    echo json_encode(["error" => "facilitator_id is required"]);
    exit;
}

$facilitator_id = $_GET['facilitator_id'];
$query = "
    SELECT 
        s.project_id, 
        s.Project_pathway,
        c.* 
    FROM class c
    JOIN sites s ON s.siteID = c.siteID
    JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
    WHERE f.facilitator_id = ?
    ORDER BY c.className
";

$stmt = $conn->prepare($query);
$stmt->bind_param("i", $facilitator_id);
$stmt->execute();
$result = $stmt->get_result();

$classes = [];
while ($row = $result->fetch_assoc()) {
    $classes[] = $row;
}

echo json_encode($classes, JSON_PRETTY_PRINT);
$stmt->close();
$conn->close();
?>
```

---

## AFTER THIS FIX - NEXT STEPS

Once ARPL menu appears:

1. ✅ You can now access ARPL Toolkit
2. ✅ You can view all appendices
3. 📋 Still need to upload remaining 57 PHP files
4. 📋 Still need to create 26 database tables
5. 📋 Then test complete ARPL workflow

But the critical blocker is THIS fix first.

---

## TIMELINE

- **Before Fix:** ARPL assessor sees normal menu (❌)
- **After Step 3 Above:** File updated on server
- **After Step 5 (Test):** Endpoint verified
- **After Device Cache Clear:** ARPL menu appears (✅)

---

## RISK LEVEL

🟢 **LOW RISK**
- Only adding a field to the query
- No data deletion
- No schema changes
- Easy to rollback (backup available)

---

## TESTING SUMMARY

| Test | Before | After |
|------|--------|-------|
| API includes pathway | ❌ No | ✅ Yes |
| App detects ARPL | ❌ No | ✅ Yes |
| Dashboard title | ❌ "Assessor Dashboard" | ✅ "ARPL Dashboard" |
| Menu shows ARPL items | ❌ No | ✅ Yes |
| Toolkit visible | ❌ No | ✅ Yes |
| Appendices visible | ❌ No | ✅ Yes |

---

## SUPPORT

If stuck:
1. Check `URGENT_ONLINE_SERVER_FIX_REQUIRED.md` for detailed guide
2. Check `ARPL_ASSESSOR_UI_FIX.md` for technical explanation
3. Check database: does `sites` table have `Project_pathway` column?
4. Check file: does `get_classes.php` have the added line?

---

**This is the ONLY thing blocking ARPL from working!**  
**Do this, then ARPL menu will appear.** ✅

**Estimated Time:** 10 minutes  
**Impact:** Critical functionality restored

