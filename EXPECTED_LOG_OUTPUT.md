# Expected Debug Log Output After Fix
**July 9, 2026** - Trade-Specific ARPL Forms OFO Fix

---

## LOG PATTERNS TO VERIFY

### When User Selects Bricklaying Class Learner (Should show OFO 671103)

**CORRECT OUTPUT (After Fix):**
```
[TOOLKIT_DEBUG] Dropdown onChanged: value=77112005230872
[TOOLKIT_DEBUG] Found learner in dropdown: true
[TOOLKIT_DEBUG] Learner Name: Masoko Rosinah Segola
[TOOLKIT_DEBUG] Learner classID: 783
[TOOLKIT_DEBUG] Learner LearnerID: 72
[TOOLKIT_DEBUG] Fetching OFO for classID: 783          ← API call starts
[TOOLKIT_DEBUG] API returned OFO: 671103              ← CORRECT OFO!
[TOOLKIT_DEBUG] Set _selectedLearnerId=77112005230872
[TOOLKIT_DEBUG] Set _selectedClassId=783
[TOOLKIT_DEBUG] Set _selectedOfoNumber=671103         ← NOW CORRECT!
```

**WRONG OUTPUT (Before Fix):**
```
[TOOLKIT_DEBUG] Dropdown onChanged: value=77112005230872
[TOOLKIT_DEBUG] Found learner in dropdown: true
[TOOLKIT_DEBUG] Learner Name: Masoko Rosinah Segola
[TOOLKIT_DEBUG] Learner classID: 783
[TOOLKIT_DEBUG] Learner LearnerID: 72
[TOOLKIT_DEBUG] Set _selectedOfoNumber=671101        ← HARDCODED WRONG!
```

---

## When User Clicks "Open Toolkit" Button

### With Bricklaying Learner (OFO 671103 - Should open Bricklayer Form)

**CORRECT OUTPUT:**
```
[TOOLKIT_DEBUG] === _openToolkit called ===
[TOOLKIT_DEBUG] _selectedLearnerId: 77112005230872
[TOOLKIT_DEBUG] _selectedClassId: 783
[TOOLKIT_DEBUG] _selectedOfoNumber: 671103           ← CORRECT!
[TOOLKIT_DEBUG] _learners.length: XX
[TOOLKIT_DEBUG] Searching for learner with IDNumber: 77112005230872
[TOOLKIT_DEBUG] Learner search result: FOUND
[TOOLKIT_DEBUG] Found learner: Masoko Rosinah Segola
[TOOLKIT_DEBUG] Learner LearnerID: 72
[TOOLKIT_DEBUG] Learner IDNumber: 77112005230872
[TOOLKIT_DEBUG] Learner classID: 783
[TOOLKIT_DEBUG] Parsed learnerId: 72, classId: 783
[TOOLKIT_DEBUG] All checks passed, navigating to toolkit
[TOOLKIT_DEBUG] Final parameters: learnerId=72, classId=783, ofoNumber=671103
```

Then app should navigate to: **ArplToolkitBricklayerPage** ✅

### With Electrician Learner (OFO 671101 - Should open Electrician Form)

**CORRECT OUTPUT:**
```
[TOOLKIT_DEBUG] === _openToolkit called ===
[TOOLKIT_DEBUG] _selectedLearnerId: XXXXXXXXXXXXX
[TOOLKIT_DEBUG] _selectedClassId: 782
[TOOLKIT_DEBUG] _selectedOfoNumber: 671101           ← CORRECT!
[TOOLKIT_DEBUG] Fetching OFO for classID: 782
[TOOLKIT_DEBUG] API returned OFO: 671101
[TOOLKIT_DEBUG] Set _selectedOfoNumber=671101
[TOOLKIT_DEBUG] Final parameters: learnerId=XX, classId=782, ofoNumber=671101
```

Then app should navigate to: **ArplToolkitViewerPage** ✅

### With Plumbing Learner (OFO 671102 - Should open Plumber Form)

**CORRECT OUTPUT:**
```
[TOOLKIT_DEBUG] === _openToolkit called ===
[TOOLKIT_DEBUG] _selectedLearnerId: XXXXXXXXXXXXX
[TOOLKIT_DEBUG] _selectedClassId: XXX
[TOOLKIT_DEBUG] _selectedOfoNumber: 671102           ← CORRECT!
[TOOLKIT_DEBUG] Fetching OFO for classID: XXX
[TOOLKIT_DEBUG] API returned OFO: 671102
[TOOLKIT_DEBUG] Set _selectedOfoNumber=671102
[TOOLKIT_DEBUG] Final parameters: learnerId=XX, classId=XXX, ofoNumber=671102
```

Then app should navigate to: **ArplToolkitPlumberPage** ✅

---

## API CALL DETAILS

### What the API Call Does

```
GET /mobile/get_arpl_toolkit_data.php?classID=783

Backend Processing:
1. Receives classID: 783
2. Queries: SELECT t.ofo_number FROM class c 
            LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id 
            WHERE c.classID = 783
3. Database returns: ofo_number = 671103 (Bricklayer)
4. Responds: { "status": "success", "ofo_number": "671103" }

Expected Response Times: 200-500ms
```

### Full API Response Structure

**Success Response:**
```json
{
  "status": "success",
  "ofo_number": "671103",
  "trade_id": 4,
  "trade_name": "Bricklaying",
  "activities": [...],
  "...other data...": "..."
}
```

**What Dart extracts:**
- Checks if `status == "success"`
- Extracts `ofo_number` field
- Returns it as a string
- Falls back to '671101' if any error

---

## HOW TO VIEW LOGS

### Option 1: Android Studio Logcat (Recommended)
```
1. Open Android Studio
2. Window → Logcat (or Alt+6)
3. Filter: "TOOLKIT_DEBUG"
4. Select device from dropdown
5. Watch logs as you interact with app
```

### Option 2: Command Line (ADB)
```bash
adb logcat | grep TOOLKIT_DEBUG

# Or save to file:
adb logcat | grep TOOLKIT_DEBUG > toolkit_logs.txt
```

### Option 3: Real-time Filtered View
```bash
adb logcat *:S TOOLKIT_DEBUG:I
```

---

## ERROR CASES (What NOT to See)

### If You See These, The Fix Didn't Work:

```
❌ [TOOLKIT_DEBUG] Fetching OFO for classID: 783
❌ [TOOLKIT_DEBUG] API error: 404, using default 671101
   → API endpoint might be wrong or server issue

❌ [TOOLKIT_DEBUG] API returned no OFO, using default 671101
   → API returned unexpected response format

❌ [TOOLKIT_DEBUG] Exception fetching OFO: Connection refused
   → Network connectivity issue

❌ [TOOLKIT_DEBUG] Set _selectedOfoNumber=671101
   (without prior API call logs)
   → Code is still using hardcoded value - NOT FIXED!
```

### If API Call is Missing Entirely:
```
❌ [TOOLKIT_DEBUG] Found learner in dropdown: true
❌ [TOOLKIT_DEBUG] Learner classID: 783
❌ [TOOLKIT_DEBUG] Set _selectedOfoNumber=671101
❌ (No "Fetching OFO" line)

→ This means the new code wasn't deployed or old APK is still running
→ Solution: Rebuild and reinstall APK
```

---

## VERIFICATION CHECKLIST

Use this checklist while testing:

### Dropdown Selection
- [ ] Select Bricklaying learner
- [ ] See log: "Fetching OFO for classID: 783"
- [ ] See log: "API returned OFO: 671103" (NOT 671101)
- [ ] See log: "Set _selectedOfoNumber=671103"

### Toolkit Navigation
- [ ] Click "Open Toolkit"
- [ ] See log: "Final parameters: ... ofoNumber=671103"
- [ ] Form opens without crashing
- [ ] Page shows Bricklayer content (confirm visually)

### Multiple Tests
- [ ] Test with Bricklaying class → should get 671103
- [ ] Test with Electrician class → should get 671101
- [ ] Test with Plumbing class (if available) → should get 671102

### No Hardcoding
- [ ] NEVER see: "Set _selectedOfoNumber=671101" without API call
- [ ] ALWAYS see: "Fetching OFO for classID:" before OFO is set

---

## TROUBLESHOOTING

### Problem: Still Getting Wrong Form (Electrician when selecting Bricklaying)

**Check 1: Is new APK installed?**
```bash
adb shell pm list packages | grep rlmss
adb shell dumpsys package com.example.rlmss | grep versionCode
```

**Check 2: Is new code running?**
- Look for "Fetching OFO for classID:" in logs
- If NOT present → rebuild and reinstall

**Check 3: Is API responding?**
```bash
# Test API directly:
curl "https://rlms.rlms.co.za/mobile/get_arpl_toolkit_data.php?classID=783"
# Should see: "ofo_number":"671103"
```

**Check 4: Database correct?**
```sql
SELECT c.classID, c.trade_id, t.ofo_number 
FROM class c 
JOIN arpl_trades t ON c.trade_id = t.trade_id 
WHERE c.classID IN (782, 783);
```

### Problem: App Crashes When Selecting Learner

**Likely causes:**
1. Network error → Check internet connection
2. API returns unexpected format → Check PHP endpoint
3. Type casting error → Check Dart's jsonDecode

**How to fix:**
1. Check logs for full error message
2. Run manual API test
3. Verify database values
4. Rebuild APK if needed

### Problem: Correct OFO in Logs But Wrong Form Opens

**Likely causes:**
1. ArplToolkitRouter routing logic is wrong
2. OFO values don't match router's switch cases

**How to fix:**
1. Check `lib/ArplToolkitRouter.dart` routing logic
2. Verify OFO strings match exactly (no leading/trailing spaces)
3. Check that Bricklayer/Plumber pages actually exist

---

## SUMMARY TABLE

| Scenario | Expected OFO | Expected Form | Expected Log |
|----------|-------------|----------------|-------------|
| Bricklaying (783) | 671103 | ArplToolkitBricklayerPage | "API returned OFO: 671103" |
| Electrician (782) | 671101 | ArplToolkitViewerPage | "API returned OFO: 671101" |
| Plumbing (TBD) | 671102 | ArplToolkitPlumberPage | "API returned OFO: 671102" |

---

## FINAL CHECK

After testing, you should be able to say:

✅ "The app now correctly routes Bricklaying learners to the Bricklayer form"  
✅ "The app correctly routes Electrician learners to the Electrician form"  
✅ "The app correctly routes Plumbing learners to the Plumber form"  
✅ "The OFO is fetched from the API, not hardcoded"  
✅ "All debug logs show the correct OFO values"  

If all of these are true, the fix is working correctly! ✨

