# TEST APPENDIX F - QUICK START GUIDE

## What Was Fixed

### Issue 1: Appendix F Was Empty
- **Problem:** Practical tasks and workplace observations weren't showing in the UI
- **Root Cause:** Dead code - methods existed but were never called in the widget tree
- **Fix:** Wired `_buildPracticalTasksList()` and `_buildWorkplaceObservationsList()` into `_buildAppendixF()`

### Issue 2: Data Wasn't Parsing
- **Problem:** Even when data came from API, it silently became empty lists
- **Root Cause:** JSON key mismatch - PHP sends `practicalTasks` (camelCase) but code read `practical_tasks` (snake_case)
- **Fix:** Updated AppendixFData.fromJson() to use correct camelCase keys

### Issue 3: Wrong Trade OFO
- **Problem:** Bricklayer showed electrician OFO (671101) instead of bricklayer (641201)
- **Fixes Applied:**
  - Bricklayer: Changed default OFO from `'671103'` to `'641201'`
  - Assessor Review: Removed hardcoded electrician fallback, now queries correct trade OFO

---

## Quick Test on Device

### After APK Install, Do This:

1. **Open RLMSS App**
2. **Navigate to ARPL Toolkit → Bricklayer**
3. **Scroll Down to Appendix F**

### What You Should See:

#### Trade Banner (Top)
```
╔══════════════════════════╗
║  Bricklayer              ║
║  OFO: 641201             ║
╚══════════════════════════╝
```

#### Section 1: PRACTICAL TASKS (13 Cards)
```
┌─ Task 1: [Task Name] ────────────┐
│  Score:      ___________         │
│  Percentage: ___________         │
└──────────────────────────────────┘

┌─ Task 2: [Task Name] ────────────┐
│  Score:      ___________         │
│  Percentage: ___________         │
└──────────────────────────────────┘

... (13 total)
```

#### Section 2: WORKPLACE OBSERVATIONS (detailed) (13 Cards)
```
┌─ Observation 1: [Task Name] ─────┐
│  Technical Knowledge: __________  │
│  Interpretation:     __________  │
│  Team Work:          __________  │
└──────────────────────────────────┘

┌─ Observation 2: [Task Name] ─────┐
│  Technical Knowledge: __________  │
│  Interpretation:     __________  │
│  Team Work:          __________  │
└──────────────────────────────────┘

... (13 total)
```

---

## Test Edit Mode

1. **Tap Edit Button** (Top Right)
2. **Fill in first practical task:**
   - Score: `85`
   - Percentage: `85`
3. **Fill in first observation:**
   - Technical Knowledge: `Good understanding`
   - Interpretation: `Correct method`
   - Team Work: `Good`
4. **Tap Save Button**
5. **Expected:** Data saved, fields now read-only
6. **Navigate away and back** → Data should still be there

---

## Test Other Trades

1. **Go back to Bricklayer selection**
2. **Try Electrician Toolkit**
3. **Go to Appendix F**
4. **Verify:** Banner shows `Electrician (671101)` not Bricklayer

---

## Success Criteria

All of these should be true:

- [x] Appendix F shows 3 distinct sections (not empty)
- [x] Trade banner shows "Bricklayer" and OFO "641201"
- [x] PRACTICAL TASKS section has 13 cards
- [x] WORKPLACE OBSERVATIONS section has 13 cards
- [x] Each card has correct fields (no missing inputs)
- [x] Edit mode works (fields become editable)
- [x] Save mode works (data persists)
- [x] Other trades show different OFO numbers

---

## What If Something Is Wrong

| Problem | Solution |
|---------|----------|
| All fields empty but trade name shows | Data isn't in database or API query failed. Check PHP. |
| Shows wrong OFO (671101 instead of 641201) | OFO wasn't updated in code. Check line 14 of ArplToolkitBricklayerPage.dart |
| Appendix F completely blank/missing | Methods not wired into widget tree. Check _buildAppendixF() calls. |
| Fields read-only even after clicking Edit | _isEditing flag not toggling. Check Edit button handler. |
| App crashes on Appendix F | JSON parsing error. Check camelCase keys in AppendixFData.fromJson(). |

---

## Files That Were Changed

1. **lib/models/arpl_toolkit_data.dart**
   - AppendixFData.fromJson() - camelCase keys fix

2. **lib/ArplToolkitBricklayerPage.dart**
   - _buildAppendixF() - wired missing methods
   - Line 14 - changed OFO to '641201'
   - Lines 564-573 - fixed isEmpty check

3. **lib/ArplAssessorPage.dart**
   - _loadActivitiesFromAPI() - OFO lookup fix

---

## Device Status

- ✅ APK: 45.8MB (Release build)
- ✅ Device: Samsung SM_A155F
- ✅ Installation: Success (adb install -r)
- ✅ Build: No errors

**Ready to test!**

---

*After testing, check APPENDIX_F_VERIFICATION_COMPLETE.md for detailed verification checklist*
