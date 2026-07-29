# Immediate Action Items - ARPL System

**Date:** July 13, 2026  
**Status:** 3 Critical Tasks Remaining

---

## TASK 1: Build and Install APK ⚠️ PRIORITY 1

**Status:** Ready to execute  
**Why:** Test that all Dart compilation fixes are working and load the latest code on device

### Steps:

```cmd
cd c:\projects\rlmss
flutter clean
flutter pub get
flutter build apk --release
```

**Expected Output:**
- Build completes without errors
- APK generated at: `build/app/outputs/flutter-apk/app-release.apk`

### Install on Device:
```cmd
adb uninstall com.rlmss.app
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Success Indicator:** App installs and launches without crashing

**Troubleshooting:**
- If build fails: Check `flutter doctor` for missing dependencies
- If install fails: Ensure device is connected (`adb devices`)
- If app crashes: Check logcat: `adb logcat`

---

## TASK 2: Debug 404 Endpoint Issues ⚠️ PRIORITY 2

**Status:** Requires investigation  
**Why:** Mobile app cannot save ARPL form data - endpoints returning 404 errors

### Current Status:
- ✓ All endpoints exist in project: `c:\projects\rlmss\mobile\`
- ✗ Need to verify they're in XAMPP directory: `c:\xampp\htdocs\assessorReport2\mobile\`

### Investigation Steps:

1. **Check XAMPP is Running:**
   ```
   http://192.168.0.57:8080
   ```
   Should show XAMPP dashboard

2. **List Endpoints in XAMPP:**
   ```
   dir c:\xampp\htdocs\assessorReport2\mobile\save_arpl*.php
   ```
   Should show all save_arpl_*.php files

3. **Test Endpoint Directly:**
   ```bash
   curl http://192.168.0.57:8080/assessorReport2/mobile/save_arpl_appendix_b.php
   ```
   Should return JSON response (not 404)

4. **Check PHP Error Log:**
   ```
   c:\xampp\apache\logs\error.log
   c:\xampp\mysql\data\rlmss*.err
   ```

5. **If Files Missing from XAMPP:**
   Copy from project to XAMPP:
   ```cmd
   xcopy c:\projects\rlmss\mobile\save_arpl*.php c:\xampp\htdocs\assessorReport2\mobile\ /Y
   xcopy c:\projects\rlmss\mobile\get_arpl*.php c:\xampp\htdocs\assessorReport2\mobile\ /Y
   ```

### Key Endpoints to Verify:
- save_arpl_appendix_b.php
- save_arpl_appendix_d.php
- save_arpl_appendix_e.php
- save_arpl_appendix_e_ratings.php
- save_arpl_appendix_f_assessment.php
- save_arpl_appendix_f.php
- save_arpl_appendix_g.php
- save_arpl_appendix_i.php
- save_arpl_appendix_j.php

---

## TASK 3: Test End-to-End Workflow ⚠️ PRIORITY 3

**Status:** Dependent on Tasks 1 & 2  
**Why:** Verify the complete ARPL flow works without errors

### Workflow:

1. **Login as Bricklayer Learner**
   - Username: (Bricklayer facilitator account)
   - Class: 783 (Bricklaying)
   - OFO Code: 641201

2. **Navigate to ARPL Section**
   - Open: Assessor Dashboard → Assigned Classes
   - Select class 783 (Bricklaying)
   - Start ARPL Assessment

3. **Fill Form Sections**
   - [ ] Appendix A: Application Form
   - [ ] Appendix B: Competency Activities (with ratings)
   - [ ] Appendix C: Self-Evaluation
   - [ ] Appendix D: Practical Skills Assessment
   - [ ] Appendix E: Practical Assessment Ratings
   - [ ] Appendix F: Assessment Agreement
   - [ ] Appendix G: Assessment Plan

4. **Save Each Section**
   - After each section, save using mobile app
   - **CHECK:** No 404 errors in network logs
   - **CHECK:** Data persists after sync

5. **Generate PDF Report**
   - Click: Generate PDF / View Portfolio
   - **CHECK:** Questions section shows PDF preview (400px)
   - **CHECK:** Script section shows full PDF (600px)
   - **CHECK:** Blue theme for theory, orange for practical

6. **Verify Data Persistence**
   - Close app and reopen
   - Navigate back to same learner/class
   - **CHECK:** All saved data still present
   - **CHECK:** No data loss or duplication

---

## KNOWN ISSUES RESOLVED ✓

### ✓ ARPL Trade Display Bug (COMPLETE)
- Bricklayer users now see correct questions (641201, not 671101)
- Electrician users see 671101 questions
- Plumber users see 642601 questions

### ✓ ArplAssessorPage.dart Compilation Errors (COMPLETE)
- Fixed `_selectedClassId` undefined reference
- Fixed nullable String type casting
- Added proper validation and error handling

### ✓ ARPL PDF Questions Display (COMPLETE)
- Theory papers now show 400px question preview + 600px full PDF
- Practical scripts now show 400px question preview + 600px full PDF
- Color-coded sections for easy visual distinction

---

## NEXT PHASE - After End-to-End Testing

If all tests pass:

1. **Load Test:** Verify performance with multiple learners/classes
2. **Error Handling:** Test edge cases (network loss, invalid data, etc.)
3. **Offline Capability:** Test offline form filling and sync
4. **Data Export:** Verify PDF generation is stable and complete
5. **Training:** Prepare user manual for assessors

---

## QUICK COMMANDS

```bash
# Build APK
flutter clean && flutter pub get && flutter build apk --release

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# View logs
adb logcat | findstr com.rlmss

# Test endpoint
curl http://192.168.0.57:8080/assessorReport2/mobile/save_arpl_appendix_b.php

# Copy endpoints to XAMPP
xcopy c:\projects\rlmss\mobile\save_arpl*.php c:\xampp\htdocs\assessorReport2\mobile\ /Y
```

---

## CONFIGURATION

**Device IP:** 192.168.0.57  
**XAMPP Port:** 8080  
**Database:** rlmss  
**API Base:** /assessorReport2/mobile/  

**Bricklayer Test:**
- Class ID: 783
- OFO Code: 641201
- Facilitator: (check facilitator assigned to class 783)

**Electrician Test:**
- Class ID: 782
- OFO Code: 671101
- Facilitator: (check facilitator assigned to class 782)

---

## SUPPORT

If issues occur:

1. Check error logs first
2. Verify network connectivity
3. Clear app cache: `adb shell pm clear com.rlmss.app`
4. Rebuild and reinstall APK
5. Check database integrity: Run `create_arpl_poe_unified_table.sql`

**Contact:** Development Team - See project documentation

---

**Last Updated:** July 13, 2026  
**Next Check:** After APK build completes
