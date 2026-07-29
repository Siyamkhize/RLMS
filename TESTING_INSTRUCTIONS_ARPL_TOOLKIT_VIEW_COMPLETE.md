# Testing Instructions - ARPL Toolkit View Complete Feature

**Build Date:** July 9, 2026  
**APK Version:** Debug Build (20.3s compile time)  
**Feature Status:** READY FOR TESTING

---

## Installation

1. **Connect Android Device:**
   ```cmd
   adb devices
   ```

2. **Install Updated APK:**
   ```cmd
   adb install -r build\app\outputs\flutter-apk\app-debug.apk
   ```

3. **Verify Installation:**
   - App should open without crashes
   - Check ARPL Assessor drawer menu

---

## Step-by-Step Testing Workflow

### Test Case 1: Basic Dropdown Selection

**Steps:**
1. Open app as ARPL Assessor
2. Navigate to drawer menu
3. Click **"View Complete Toolkit"** (below Remedials)
4. Wait for page to load (should show "Select Candidate to View Toolkit")

**Expected Results:**
- ✅ Page loads without errors
- ✅ Dropdown shows list of candidates with format: "Name Surname (IDNumber)"
- ✅ Example: "Nkosivile Sophangisa (9603125720088)"
- ✅ IDNumber shown is actual government ID (e.g., 9603125720088), NOT internal LearnerID (e.g., 20310)

**Debug Output (Check Logcat):**
```
[TOOLKIT_DEBUG] === Page initialized ===
[TOOLKIT_DEBUG] Learners loaded: X learners found
```

---

### Test Case 2: Candidate Selection

**Steps:**
1. From dropdown, click and select ANY candidate
2. Observe the page updates

**Expected Results:**
- ✅ Dropdown value updates to show selected candidate
- ✅ Info card appears below dropdown with:
  - **Candidate:** Name Surname
  - **ID Number:** [Government ID number]
  - **Class:** [Class ID number]
- ✅ OFO Number displays as read-only "671101"
- ✅ "Open Complete Toolkit" button becomes clickable (not grayed out)

**Debug Output (Check Logcat):**
```
[TOOLKIT_DEBUG] Dropdown onChanged: value=9603125720088
[TOOLKIT_DEBUG] Found learner in dropdown: true
[TOOLKIT_DEBUG] Learner Name: Nkosivile Sophangisa
[TOOLKIT_DEBUG] Learner classID: 782
[TOOLKIT_DEBUG] Learner LearnerID: 12345
[TOOLKIT_DEBUG] Set _selectedLearnerId=9603125720088
[TOOLKIT_DEBUG] Set _selectedClassId=782
[TOOLKIT_DEBUG] Set _selectedOfoNumber=671101
```

---

### Test Case 3: OFO Field Behavior

**Steps:**
1. Select any candidate
2. Look at OFO Number section
3. Try to click or tap on OFO Number field

**Expected Results:**
- ✅ OFO Number displays as plain text in a container (NOT editable)
- ✅ Field shows "671101" by default
- ✅ Cannot edit the field
- ✅ No keyboard appears when tapping the field

**NOT Expected:**
- ❌ TextField that allows user input
- ❌ Cursor appears
- ❌ Keyboard opens

---

### Test Case 4: Toolkit Navigation

**Steps:**
1. Select a candidate
2. Verify info card shows correct data
3. Click **"Open Complete Toolkit"** button
4. Observe navigation

**Expected Results:**
- ✅ App navigates to ArplToolkitViewerPage
- ✅ Toolkit loads with selected learner's data
- ✅ All tabs visible (Cover, Appendix A-J)
- ✅ Appendix F appears AFTER Appendix H
- ✅ No errors displayed

**Debug Output (Check Logcat):**
```
[TOOLKIT_DEBUG] === _openToolkit called ===
[TOOLKIT_DEBUG] _selectedLearnerId: 9603125720088
[TOOLKIT_DEBUG] _selectedClassId: 782
[TOOLKIT_DEBUG] _selectedOfoNumber: 671101
[TOOLKIT_DEBUG] Learner search result: FOUND
[TOOLKIT_DEBUG] Found learner: Nkosivile Sophangisa
[TOOLKIT_DEBUG] Parsed learnerId: 12345, classId: 782
[TOOLKIT_DEBUG] All checks passed, navigating to toolkit
[TOOLKIT_DEBUG] Final parameters: learnerId=12345, classId=782, ofoNumber=671101
```

---

### Test Case 5: Error Handling - No Candidate Selected

**Steps:**
1. Open View Complete Toolkit page
2. Click "Open Complete Toolkit" WITHOUT selecting a candidate
3. Observe error message

**Expected Results:**
- ✅ Snackbar error message appears: "Please select a candidate to continue"
- ✅ Error message remains visible for 2 seconds
- ✅ Page does NOT navigate
- ✅ Dropdown still open for selection

**Debug Output (Check Logcat):**
```
[TOOLKIT_DEBUG] === _openToolkit called ===
[TOOLKIT_DEBUG] _selectedLearnerId: null
[TOOLKIT_DEBUG] ERROR: _selectedLearnerId is null or empty
```

---

### Test Case 6: Multiple Candidate Selection

**Steps:**
1. Select Candidate A
2. Verify info card shows Candidate A's data
3. Select dropdown again
4. Choose Candidate B
5. Verify info card updates
6. Click "Open Complete Toolkit"

**Expected Results:**
- ✅ Info card updates immediately when new candidate selected
- ✅ Navigation uses NEW candidate's data
- ✅ No errors during candidate switching
- ✅ Toolkit opens with Candidate B's data

---

### Test Case 7: Toolkit Data Persistence

**After successfully opening toolkit:**

**Steps:**
1. Edit some Appendix data (e.g., ratings, text fields)
2. Click Save
3. See "✓ Changes saved successfully" message
4. Observe that form fields still show the saved data

**Expected Results:**
- ✅ Data appears to be persisted (existing feature)
- ✅ Fields show saved values after save button click
- ✅ No data loss

---

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "Please select a candidate to continue" appears after clicking button | _selectedLearnerId is null/empty or not set correctly | Select a candidate from dropdown first |
| Dropdown shows LearnerID instead of IDNumber (e.g., "20310" instead of "9603125720088") | Wrong column used for display | This should now show IDNumber - if not, check logs |
| OFO field is editable/has cursor | Field implemented as TextField | Field should be read-only Container - if editable, check code |
| Navigation fails with error "Invalid learner ID" or "Invalid class ID" | Data parsing failed | Check Logcat for "Parsed learnerId:" to see if values are 0 |
| Crash when selecting candidate | Exception during learner lookup | Check Logcat for "ERROR:" messages |

---

## Debug Log Extraction

**To capture debug logs:**

```cmd
adb logcat -s "flutter" | find "[TOOLKIT_DEBUG]"
```

**Key debug markers to look for:**
- `[TOOLKIT_DEBUG] === Page initialized ===` - Page loaded
- `[TOOLKIT_DEBUG] Dropdown onChanged:` - Candidate selected
- `[TOOLKIT_DEBUG] === _openToolkit called ===` - Button clicked
- `[TOOLKIT_DEBUG] All checks passed, navigating to toolkit` - Navigation starting
- `[TOOLKIT_DEBUG] ERROR:` - Something failed

---

## Success Criteria

All of the following must pass:

- ✅ No crashes during selection workflow
- ✅ Dropdown displays IDNumber (not LearnerID)
- ✅ Info card shows correct candidate data
- ✅ OFO Number is read-only and shows "671101"
- ✅ Button click navigates to toolkit with correct parameters
- ✅ Toolkit opens and loads correctly
- ✅ Debug logs show proper state progression
- ✅ Error messages display when candidate not selected
- ✅ Multiple candidate selections work correctly

---

## Quick Reference - Expected UI Layout

```
╔════════════════════════════════════════════════════════════╗
║        ARPL Assessor - View Complete Toolkit              ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║  Select Candidate to View Toolkit                        ║
║                                                            ║
║  Candidate:                                              ║
║  [Dropdown: Choose a candidate ▼]                        ║
║                                                            ║
║  ┌──────────────────────────────────────────────┐        ║
║  │ Candidate: Nkosivile Sophangisa             │        ║
║  │ ID Number: 9603125720088                    │        ║
║  │ Class: 782                                  │        ║
║  └──────────────────────────────────────────────┘        ║
║                                                            ║
║  OFO Number:                                             ║
║  ┌──────────────────────────────────────────────┐        ║
║  │ 671101                                      │        ║
║  └──────────────────────────────────────────────┘        ║
║                                                            ║
║  ┌──────────────────────────────────────────────┐        ║
║  │  Open Complete Toolkit                     │        ║
║  └──────────────────────────────────────────────┘        ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
```

---

**Built:** July 9, 2026  
**Ready for Testing:** YES ✅
