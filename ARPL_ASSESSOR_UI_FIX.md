# ARPL ASSESSOR UI ISSUE - ROOT CAUSE AND FIX

**Date:** July 14, 2026  
**Issue:** ARPL assessors seeing normal assessor UI instead of ARPL-specific UI  
**Status:** ROOT CAUSE IDENTIFIED & FIXED

---

## PROBLEM IDENTIFIED

When an ARPL assessor logs in, the app shows:
- ❌ Regular assessor menu (normal workflow)
- ❌ NO "ARPL Toolkit" option
- ❌ NO appendices (A-H)
- ❌ Wrong UI/menu items

**Root Cause:** The `mobile/get_classes.php` endpoint is NOT returning the `Project_pathway` field.

---

## HOW IT SHOULD WORK

1. **App Login:** Assessor logs in
2. **API Call:** App calls `mobile/get_classes.php?facilitator_id=[ID]`
3. **Response Should Include:** 
   ```json
   {
     "classID": "782",
     "className": "Electrician",
     "Project_pathway": "ARPL",
     "project_id": "5"
   }
   ```
4. **App Detection:** App checks if `Project_pathway` contains "ARPL"
5. **Result:** If ARPL detected → show ARPL menu; otherwise → show normal assessor menu

**Current Problem:** Step 3 doesn't include `Project_pathway`, so app defaults to normal assessor menu.

---

## THE FIX

### File: `mobile/get_classes.php`

**BEFORE (WRONG):**
```php
$query = "
    SELECT s.project_id, c.* 
    FROM class c
    JOIN sites s ON s.siteID = c.siteID
    JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
    WHERE f.facilitator_id = ?
";
```

**AFTER (CORRECT):**
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

**Changes:**
- ✅ Added `s.Project_pathway` to SELECT statement
- ✅ Added `ORDER BY c.className` for consistency

---

## DEPLOYMENT CHECKLIST

**LOCAL (Already Done):**
- ✅ Fixed `c:\projects\rlmss\mobile\get_classes.php`

**ONLINE SERVER (MUST DO):**
- ❌ Update `/mobile/get_classes.php` on online server with the fix above
- ❌ Restart web server or clear PHP cache (if applicable)
- ❌ Test the endpoint

---

## HOW TO APPLY THE FIX ON ONLINE SERVER

### Option 1: Via FTP/SFTP
1. Connect to online server via FTP
2. Navigate to `/mobile/` directory
3. Download `get_classes.php`
4. Edit locally - replace the SELECT query with the corrected version
5. Upload back to `/mobile/get_classes.php`

### Option 2: Via SSH
```bash
ssh user@rlms.rlms.co.za
cd /var/www/html/mobile/
nano get_classes.php
# Edit the SELECT statement
# Save and exit
```

### Option 3: Via Web Control Panel (cPanel, etc.)
1. File Manager → navigate to `/public_html/mobile/`
2. Edit `get_classes.php`
3. Replace the SELECT query with corrected version
4. Save

---

## VERIFICATION

After applying the fix, test:

```bash
curl "https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=[ARPL_ASSESSOR_ID]"
```

**Expected Response:**
```json
[
  {
    "project_id": "5",
    "Project_pathway": "ARPL",
    "classID": "782",
    "className": "Electrician",
    ...other fields...
  }
]
```

**Key Check:** The response MUST include `"Project_pathway": "ARPL"`

---

## AFTER FIX - TEST ON DEVICE

1. Clear app cache:
   ```bash
   adb shell pm clear com.example.rlmss
   ```

2. Login again as ARPL assessor

3. Verify:
   - ✅ Dashboard title changes to "ARPL Dashboard"
   - ✅ Drawer menu shows ARPL-specific items:
     - ARPL Competency Scale
     - ARPL Assessor Toolkit
     - Appendix A - Learner Details
     - Appendix B - Self Evaluation
     - Appendix C - Self Evaluation Form
     - Appendix D - Practical Skills Assessment
     - Appendix E - Activity Rating Form
     - Appendix F - Assessment Criteria
     - Appendix G - Assessment Agreement
     - Appendix I - Generic Access Recommendation
     - Assessor Review (D,E,F)
     - Access Recommendation (H)
     - Evidence Checklist

---

## RELATED CODE

### In `lib/AssessorPage.dart` (Lines 65-80):

```dart
if (data.isNotEmpty && widget.forcePathwayType == null) {
  setState(() {
    String pathway = 
        (data[0]['Project_pathway'] ?? data[0]['learning_pathway'])
            ?.toString()
            .toUpperCase() ?? '';
    
    if (pathway.contains('ARPL')) {
      _pathwayType = 'ARPL';
    } else {
      _pathwayType = pathway;
    }
  });
}
```

This code:
1. Gets first class data from API response
2. Looks for `Project_pathway` or `learning_pathway`
3. Converts to uppercase
4. Checks if contains "ARPL"
5. Sets UI accordingly

---

## WHY THIS BUG HAPPENED

The mobile endpoint was created as a simplified version without pathway information. The web endpoint (`get_classes.php`) has it, but the mobile endpoint missed it. This was discovered when testing ARPL features with the new online server deployment.

---

## COMPLETE FIXED CODE

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

## TIMELINE

- **2026-07-14 ~11:55 AM:** APK built and installed with online server config
- **2026-07-14 ~12:00 PM:** Tested login - ARPL UI not showing
- **2026-07-14 ~12:10 PM:** Root cause identified: `Project_pathway` missing from API
- **2026-07-14 ~12:15 PM:** Local fix applied to `mobile/get_classes.php`
- **2026-07-14 ~12:20 PM:** This documentation created

---

## NEXT STEPS

1. **Apply this fix to online server** - Update `mobile/get_classes.php`
2. **Test endpoint** - Verify it returns `Project_pathway`
3. **Clear app cache** - Run `adb shell pm clear com.example.rlmss`
4. **Test login** - ARPL assessor should now see ARPL UI
5. **Verify menu items** - All ARPL-specific menu options should appear

---

## SUMMARY

| Item | Status |
|------|--------|
| Root Cause | ✅ IDENTIFIED |
| Local Fix | ✅ APPLIED |
| Online Deployment | ⏳ PENDING |
| Testing | ⏳ PENDING |

**Critical:** This must be deployed to online server for ARPL to work properly.

