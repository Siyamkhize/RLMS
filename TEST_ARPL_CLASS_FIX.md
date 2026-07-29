# Testing Guide: ARPL Assessor Class Display Fix

## Date: July 20, 2026

## APK Installation Status
✅ **APK Built Successfully**: `app-release.apk` (45.9MB)
✅ **Installed on Device**: Successful

## What Was Fixed
Fixed the "Unknown Class" and "0 learners" issue in ARPL Assessor Clocking page caused by key name mismatch between PHP API and Flutter code.

## Test Steps

### 1. Login as ARPL Assessor
- **Username**: (facilitator_id 6)
- **Role**: `arpl_Assessor`
- **Expected**: Should login successfully and see ARPL Assessor dashboard

### 2. Navigate to Clocking Page
- From dashboard, tap on "Clocking" or "Clock In/Out" button
- **Expected**: Opens ARPL Assessor Clocking Page with 2 tabs

### 3. Test "My Clock In/Out" Tab (Tab 1)
- Should see your assessor details
- Should see fingerprint button for clocking in/out
- **Expected**: Assessor fingerprint clocking works as before (no changes here)

### 4. Test "Learner Clocking" Tab (Tab 2) - THE FIX
**Previous Behavior (BROKEN):**
- ❌ Showed "Unknown Class"
- ❌ Showed "0 learners"
- ❌ Class ID was blank

**New Expected Behavior (FIXED):**
- ✅ Should show **actual class names** (e.g., "Bricklayer Class", "Plumber Class")
- ✅ Should show **correct class IDs** (e.g., 797)
- ✅ Should show **actual learner count** (e.g., 15 learners)
- ✅ Classes should be displayed in a list with green badge showing learner count

### 5. Test Learner Clocking Workflow
- Tap on a class from the list
- **Expected**: 
  - Loading indicator shows "Loading learners..."
  - If learners exist locally: Navigate to Clock In Page immediately
  - If no learners locally: Auto-sync from server, then navigate
  - Clock In Page should show list of learners for that class

### 6. Test Learner Fingerprint Scanning
- Select a learner from the list
- Tap "Clock In" or "Clock Out"
- **Expected**: 
  - Fingerprint scanner dialog appears
  - Same workflow as facilitator learner clocking
  - Success message after scanning

## Expected Class Data Format

### From API (`get_classes.php`)
```json
[
  {
    "classID": "797",
    "className": "Bricklayer ARPL Class",
    "siteID": "123",
    "numberOfLearners": "15",
    "project_id": "5",
    "Project_pathway": "ARPL"
  }
]
```

### Display in App
```
┌──────────────────────────────────────┐
│  (15)  Bricklayer ARPL Class         │
│        Class ID: 797 • 15 learners   │
│                                    → │
└──────────────────────────────────────┘
```

## Debug Information

### If Classes Still Don't Show:
1. Check if facilitator_id 6 has classID field populated in database
2. Run diagnostic script: `php test_get_classes_debug.php`
3. Check API response: `https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=6`
4. Verify class table has records for the assigned classIDs

### If "No Learners Found" Still Appears:
1. Check learnerdetails table has records for the classID
2. Verify `get_learners.php` endpoint returns data
3. Check API: `https://rlms.rlms.co.za/mobile/get_learners.php?classID=797`
4. Enable logging to see sync attempts

## Technical Details

### File Changed
`lib/arpl_assessor_clocking_page.dart` (line 293-297)

### Key Names Fixed
| Old (WRONG) | New (CORRECT) | Source |
|-------------|---------------|--------|
| `ClassName` | `className` | SQL column name |
| `ClassID` | `classID` | SQL column name |
| `learner_count` | `numberOfLearners` | SQL column name |

### Why This Matters
Dart is case-sensitive. When the code looked for `classData['ClassName']` but the API returned `classData['className']`, it got `null` instead of the actual class name, triggering the fallback "Unknown Class".

## Success Criteria
- ✅ Class names display correctly (not "Unknown Class")
- ✅ Class IDs display correctly (not blank)
- ✅ Learner counts display correctly (not 0)
- ✅ Tapping a class navigates to Clock In Page
- ✅ Learners load (either from local DB or auto-sync)
- ✅ Fingerprint scanning works for learners

## Notes
- First time accessing a class may take longer due to learner sync
- Subsequent access should be instant (data cached locally)
- Requires internet for first-time learner sync
- Offline mode works after initial sync
