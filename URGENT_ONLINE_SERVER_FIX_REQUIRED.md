# 🚨 URGENT: ONLINE SERVER FIX REQUIRED FOR ARPL

**Date:** July 14, 2026  
**Priority:** HIGH - BLOCKING ISSUE  
**Status:** Awaiting online server deployment

---

## THE PROBLEM

ARPL assessors login successfully but see **normal assessor UI** instead of **ARPL-specific UI**.

### Missing Features:
- ❌ ARPL Toolkit not visible
- ❌ Appendices (A-H) not showing
- ❌ Wrong menu items displaying

---

## ROOT CAUSE

The online server's `mobile/get_classes.php` endpoint is missing the `Project_pathway` field in its response.

**Impact:** The mobile app cannot detect that the assessor belongs to an ARPL project, so it defaults to normal assessor UI.

---

## THE FIX (Copy-Paste Ready)

### File to Update: `/mobile/get_classes.php`

Replace the entire file with this corrected version:

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

### Key Changes:
- Added `s.Project_pathway` to SELECT (line 19)
- Added `ORDER BY c.className` (line 24)

---

## HOW TO DEPLOY THIS FIX

### Step 1: SSH Access
```bash
ssh [username]@rlms.rlms.co.za
cd /var/www/html/mobile/
```

### Step 2: Edit File
```bash
nano get_classes.php
```

### Step 3: Replace Content
- Delete all existing content
- Paste the corrected code from above
- Press Ctrl+O, then Enter to save
- Press Ctrl+X to exit

### Step 4: Verify
```bash
curl "https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=[ARPL_ASSESSOR_ID]"
```

Expected: Response should include `"Project_pathway": "ARPL"`

---

## VERIFICATION CHECKLIST

**Before Fix:**
- ❌ Response missing `Project_pathway` field
- ❌ App shows normal assessor menu

**After Fix:**
- ✅ Response includes `"Project_pathway": "ARPL"`
- ✅ App shows ARPL menu after login
- ✅ ARPL Toolkit visible in menu
- ✅ All appendices accessible

---

## TEST AFTER DEPLOYMENT

1. **Clear app cache on device:**
   ```bash
   adb shell pm clear com.example.rlmss
   ```

2. **Login again as ARPL assessor**

3. **Verify menu shows:**
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

## WHAT WAS HAPPENING (Technical)

**App Code (lib/AssessorPage.dart):**
```dart
String pathway = (data[0]['Project_pathway'] ?? data[0]['learning_pathway'])
    ?.toString()
    .toUpperCase() ?? '';

if (pathway.contains('ARPL')) {
  _pathwayType = 'ARPL';  // ← Should set this
} else {
  _pathwayType = pathway;
}
```

**Problem:**
- API returns empty `Project_pathway` 
- Code falls through to default pathway type
- App doesn't detect ARPL
- Shows normal assessor UI

**Solution:**
- API now returns `Project_pathway: "ARPL"`
- Code detects ARPL correctly
- Shows ARPL-specific UI

---

## DATABASE CONTEXT

The fix queries the `sites` table for `Project_pathway`:

```sql
SELECT s.Project_pathway, ...
FROM class c
JOIN sites s ON s.siteID = c.siteID
```

The `sites` table contains the pathway information for each site/class. By including it in the response, the app can determine which UI to show.

---

## TIMELINE

- **12:00 PM:** Tested login - ARPL UI not showing
- **12:10 PM:** Identified root cause in API response
- **12:15 PM:** Created this fix document
- **12:20 PM:** Ready for online deployment

---

## QUESTIONS?

If the endpoint still doesn't work after applying this fix:

1. Verify `sites` table has `Project_pathway` column:
   ```sql
   SELECT column_name FROM information_schema.columns 
   WHERE table_name='sites' AND column_name='Project_pathway';
   ```

2. Check that ARPL assessor's site has pathway set:
   ```sql
   SELECT siteID, siteName, Project_pathway FROM sites 
   WHERE siteID IN (SELECT siteID FROM class WHERE classID IN (782, 783));
   ```

3. Test query directly:
   ```sql
   SELECT s.project_id, s.Project_pathway, c.* 
   FROM class c
   JOIN sites s ON s.siteID = c.siteID
   JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
   WHERE f.facilitator_id = [ARPL_ASSESSOR_ID];
   ```

---

## SUMMARY

| Step | Status | Action |
|------|--------|--------|
| Root Cause | ✅ FOUND | API missing pathway field |
| Local Fix | ✅ DONE | Code updated locally |
| Online Deploy | ⏳ PENDING | Update `/mobile/get_classes.php` |
| Testing | ⏳ PENDING | Verify after deployment |

**BLOCKING:** Cannot proceed with ARPL testing until this is fixed on online server.

