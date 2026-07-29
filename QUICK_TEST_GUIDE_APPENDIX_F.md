# Quick Test Guide - Appendix F Redesign

**Build Status:** ✅ Complete & Installed  
**APK Location:** `build/app/outputs/flutter-apk/app-debug.apk`  
**Device:** `adb-RZ8X306F7TZ-mKvVzH (4)._adb-tls-connect._tcp`

---

## What Changed

### Before
- Appendix F was a complex assessment agreement form
- Had acknowledgment checkboxes
- Minimal table structure

### After
- Appendix F is now a **Practical Assessment Evaluation Form**
- Has professional two-table layout:
  1. **Practical Section - Tasks Assessment** (Tasks 1-13)
  2. **Workplace Observation** (Tasks 1-5)
- Includes signature fields
- Scoring guide visible
- Mobile-responsive with horizontal scrolling

---

## Quick Test Steps

### 1. Open App & Navigate to ARPL Toolkit

```
1. Open RLMSS mobile app
2. Login
3. Navigate to ARPL Toolkit section
4. Select test learner: Nkosivile Sophangisa (ID: 20286)
```

### 2. Test Trade Title Banner (All Appendices)

Go through each tab and verify:
- ✅ Green banner appears at top with "Trade: Electrician"
- ✅ Banner shows consistently on all 11 tabs:
  - Appendix A
  - Appendix B
  - Appendix C
  - Appendix D
  - Appendix E
  - **Appendix F (NEW!)**
  - Appendix G
  - Appendix H
  - Appendix I
  - Appendix J

### 3. Test Appendix F Layout

**Click on "Appx F" tab**

Verify the following sections appear (top to bottom):

#### Section 1: Title & Trade
```
Appendix F: PRACTICAL ASSESSMENT EVALUATION
Trade: Electrician
```

#### Section 2: Practical Section - Tasks Assessment
Table with columns:
- No | Tasks | Score | %
- Rows 1-13

Try to scroll left/right on the table - should be smooth.

#### Section 3: Observation Evaluation - Scoring Guide
```
Fair: 1     Good: 2     Excellent: 3
```

#### Section 4: Authorization & Signatures
Fields for:
- Assessor Signature & Date
- Candidate Signature & Date
- Witness Name

#### Section 5: Workplace Observation
Table with columns:
- No | Tasks Observed | Technical Knowledge | Interpretation | Team Work
- Rows 1-5

Try to scroll left/right - should be smooth.

### 4. Test Edit Mode

**Click the Edit Icon** (pencil icon in app bar)

Verify:
- ✅ "✏️ EDIT MODE" banner appears
- ✅ All text fields become editable
- ✅ You can type in:
  - Assessor signature field
  - Candidate signature field
  - Witness name field
  - Date fields (auto-populated)

### 5. Test Data Entry (Optional)

Try entering sample data:
```
Assessor Signature: John Smith
Candidate Signature: Nkosivile Sophangisa
Witness Name: Mary Johnson
Date: (auto-filled)
```

### 6. Test Save (If Integrated)

**Click the Save Icon** (disk icon in app bar)

Verify:
- ✅ Spinner appears while saving
- ✅ Success message appears
- ✅ Data persists when reopening Appendix F
- ✅ Other appendices still work correctly

---

## What to Look For

### ✅ Success Signs
- Trade title appears consistently green across all tabs
- Appendix F shows table structure (not old card-based layout)
- Tables have visible borders and headers
- Signature fields are present and editable
- No crashes when switching between appendices
- Edit mode toggles correctly

### ❌ Issues to Report
- Trade title not showing or showing wrong trade
- Appendix F layout broken or misaligned
- Tables not scrollable on mobile
- Fields not editable in edit mode
- Crashes when saving
- Dates not auto-populating

---

## Expected OFO Mapping

For learner ID 20286 (Nkosivile Sophangisa):
- **OFO Number:** 671101
- **Should Show:** "Trade: Electrician"

If different OFO, trade name should map accordingly:
- 671102 → Plumber
- 671103 → Bricklayer
- 671104 → Carpenter
- 671105 → Welder

---

## Device Info

If app doesn't run:
1. Uninstall old version: `adb uninstall com.example.rlmss`
2. Reinstall: `adb install build/app/outputs/flutter-apk/app-debug.apk`
3. Clear app data: `adb shell pm clear com.example.rlmss`

---

## Screenshots Checklist

For documentation, take screenshots of:
- [ ] Trade title banner on Appendix A
- [ ] Trade title banner on Appendix F (new form)
- [ ] Practical Section table (full view)
- [ ] Workplace Observation table (full view)
- [ ] Edit mode activated
- [ ] Signature fields filled in
- [ ] Save confirmation

---

## Build Command Reference

If you need to rebuild:
```bash
cd c:\projects\rlmss
flutter clean
flutter pub get
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

---

## Files to Check

If debugging:
- Main UI: `lib/ArplToolkitViewerPage.dart` (line 1860-2050 for Appendix F)
- Data models: `lib/models/arpl_toolkit_data.dart`
- Backend: `mobile/get_arpl_toolkit_data.php`
- Save API: `mobile/save_arpl_appendix_f_assessment.php`

---

## Success Criteria

✅ **Phase 1: Deployment** - COMPLETE
- APK built without errors
- Installed on device successfully

✅ **Phase 2: Visual** - TESTING NOW
- All appendices show trade title
- Appendix F has new table layout
- No crashes

⏳ **Phase 3: Functional** - NEXT
- Edit mode works
- Data saves correctly
- Load/save cycle works end-to-end

---

**Expected Test Duration:** 10-15 minutes

Good luck! 🚀

