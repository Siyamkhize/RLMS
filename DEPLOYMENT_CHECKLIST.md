# ARPL ASSESSOR MENU FIX - DEPLOYMENT CHECKLIST

**Use this checklist to deploy and test the fix systematically.**

---

## PRE-DEPLOYMENT CHECKLIST

- [x] ArplAssessorPage.dart pathway detection fixed
- [x] mobile/compare_local_vs_online.php schema issue fixed
- [x] Comprehensive logging added to all files
- [x] Documentation created
- [ ] PHP files ready to upload to server
- [ ] Ready to rebuild APK

---

## DEPLOYMENT STEPS

### ☐ Step 1: Deploy PHP Files to Server

```bash
scp mobile/login.php user@rlms.rlmsco.com:/home/rlmsrlmsco/public_html/mobile/
scp mobile/get_classes.php user@rlms.rlmsco.com:/home/rlmsrlmsco/public_html/mobile/
scp mobile/compare_local_vs_online.php user@rlms.rlmsco.com:/home/rlmsrlmsco/public_html/mobile/
```

**Verify upload:**
```bash
ssh user@rlms.rlmsco.com
ls -la /home/rlmsrlmsco/public_html/mobile/*.php
```

---

### ☐ Step 2: Rebuild APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

**Verify build:**
- [ ] Build completed without errors
- [ ] APK exists at: `build/app/outputs/flutter-apk/app-release.apk`
- [ ] APK file size is reasonable (check it's not corrupted)

---

### ☐ Step 3: Install Fresh APK

**On test device:**
- [ ] Uninstall old APK (Settings → Apps → RLMSS → Uninstall)
- [ ] Clear app data (if needed)
- [ ] Install new APK:
  ```bash
  adb install build/app/outputs/flutter-apk/app-release.apk
  ```
  OR copy to device and install manually

---

### ☐ Step 4: Prepare Log Collection

**Backend (Server):**
```bash
# In separate terminal, SSH to server and watch logs
ssh user@rlms.rlmsco.com
tail -f /var/log/apache2/error.log | grep -E "LOGIN|GET_CLASSES"
```

**Frontend (Device):**
```bash
# In separate terminal, watch Flutter logs
flutter logs | grep -E "LOGIN|NAVIGATION|ArplAssessor"
```

OR

```bash
# Use ADB logcat
adb logcat | grep -E "flutter.*LOGIN|flutter.*NAVIGATION|flutter.*ArplAssessor"
```

---

## TESTING CHECKLIST

### ☐ Test 1: Login as ARPL Assessor

**Steps:**
1. [ ] Open app
2. [ ] Log in as facilitator 6 (arpl_Assessor role)
3. [ ] Watch logs in both terminals

**Expected Result:**
- [ ] App navigates to ArplAssessorPage
- [ ] ARPL dashboard appears (NOT default assessor dashboard)
- [ ] Menu shows ARPL-specific items

**Backend Logs Should Show:**
```
[LOGIN] Facilitator 6: DB role = 'arpl_Assessor', normalized = 'arpl_assessor'
[LOGIN] Detected ARPL Assessor role
[LOGIN] Final response role for facilitator 6: 'arpl_assessor'
```

**Frontend Logs Should Show:**
```
[LOGIN] Raw role from server: "arpl_assessor"
[NAVIGATION] Normalized role: "arpl_assessor"
[NAVIGATION] ===== ARPL ASSESSOR NAVIGATION =====
[ArplAssessorPage] Detected Pathway: ARPL (from data: ELECTRICIAN, isARPL: true)
[ArplAssessorPage] Will show ARPL dashboard
```

---

### ☐ Test 2: Verify ARPL Menu Items

**Check that menu includes:**
- [ ] ARPL Dashboard
- [ ] Assigned Classes
- [ ] Candidate Preparation
- [ ] Other ARPL-specific menu items

**Should NOT show:**
- [ ] Default assessor menu items (if shows default, fix failed)

---

### ☐ Test 3: Pathway Detection with Different Trades

**If possible, test with classes having different pathway values:**
- [ ] "ARPL" → Should show ARPL menu
- [ ] "Electrician" → Should show ARPL menu
- [ ] "Plumbing" → Should show ARPL menu
- [ ] "Bricklaying" → Should show ARPL menu
- [ ] "Office Admin" (non-ARPL) → Should show default menu

---

## LOG COLLECTION CHECKLIST

### ☐ Collect Backend Logs

```bash
# Save last 200 lines containing LOGIN or GET_CLASSES
ssh user@rlms.rlmsco.com
tail -n 200 /var/log/apache2/error.log | grep -E "LOGIN|GET_CLASSES" > ~/backend_logs.txt

# Download to local machine
scp user@rlms.rlmsco.com:~/backend_logs.txt ./backend_logs.txt
```

---

### ☐ Collect Frontend Logs

```bash
# If using flutter logs:
flutter logs > frontend_logs.txt
# Press Ctrl+C after collecting sufficient logs

# If using ADB:
adb logcat > frontend_logs.txt
# Press Ctrl+C after collecting sufficient logs

# Filter the logs
grep -E "LOGIN|NAVIGATION|ArplAssessor" frontend_logs.txt > frontend_logs_filtered.txt
```

---

## TROUBLESHOOTING CHECKLIST

### ☐ If ARPL Menu Does NOT Appear

**Check Backend Logs:**
- [ ] What role was detected? Look for: `[LOGIN] Detected ??? role`
- [ ] What role was sent in response? Look for: `[LOGIN] Final response role`
- [ ] Is the role in database correct? Check: `SELECT role FROM facilitator WHERE facilitator_id = 6`

**Check Frontend Logs:**
- [ ] What role was received? Look for: `[LOGIN] Raw role from server: "???"`
- [ ] What page was navigated to? Look for: `[NAVIGATION] About to navigate to ???Page`
- [ ] What pathway was detected? Look for: `[ArplAssessorPage] Detected Pathway: ??? (isARPL: ???)`

**Common Issues:**
- [ ] Backend sending wrong role → Check database `facilitator.role` value
- [ ] Frontend not parsing correctly → Check if role contains unexpected characters
- [ ] Pathway detection failing → Check if `isARPL: false` in logs
- [ ] Wrong dashboard showing → Check `[ArplAssessorPage] Will show ??? dashboard`

---

### ☐ If Logs Are Not Appearing

**Backend:**
- [ ] Check PHP error_log is enabled
- [ ] Check correct log file path: `php -i | grep error_log`
- [ ] Try manual test: `curl "https://rlms.rlmsco.com/mobile/login.php"`

**Frontend:**
- [ ] Check device is connected: `adb devices`
- [ ] Check Flutter is running in debug/profile mode (logs limited in release)
- [ ] Use Android Studio's Logcat viewer as alternative

---

## POST-TEST CHECKLIST

### ☐ If Test Passed (Success!)

- [ ] Verify menu works correctly
- [ ] Test a few ARPL-specific features
- [ ] Document success in test report
- [ ] Deploy to production users
- [ ] Notify users of update
- [ ] Archive logs for reference

---

### ☐ If Test Failed (Needs Investigation)

- [ ] Save all logs (backend + frontend)
- [ ] Document what went wrong
- [ ] Note which step failed (login, navigation, pathway detection, UI rendering)
- [ ] Share logs and failure details
- [ ] Do NOT deploy to production yet

**Share with developer:**
- Backend logs (backend_logs.txt)
- Frontend logs (frontend_logs_filtered.txt)
- Description of what happened vs what was expected
- Screenshots of wrong menu (if visible)

---

## ROLLBACK CHECKLIST (If Needed)

### ☐ If Critical Issue Found

**Rollback PHP:**
```bash
# SSH to server
ssh user@rlms.rlmsco.com

# Restore from backup (if you created backups)
cp /path/to/backup/login.php /home/rlmsrlmsco/public_html/mobile/
cp /path/to/backup/get_classes.php /home/rlmsrlmsco/public_html/mobile/
```

**Rollback APK:**
- Install previous working APK version

---

## COMPLETION CHECKLIST

- [ ] Deployment completed
- [ ] Testing completed
- [ ] Logs collected and reviewed
- [ ] Success/failure documented
- [ ] If successful: Production deployment planned
- [ ] If failed: Investigation plan created

---

## NOTES SECTION

**Date Deployed:** _______________

**Test Results:**
- Login: ☐ Pass ☐ Fail
- Menu Display: ☐ Pass ☐ Fail
- Pathway Detection: ☐ Pass ☐ Fail

**Issues Found:**
_________________________________________________
_________________________________________________
_________________________________________________

**Next Actions:**
_________________________________________________
_________________________________________________
_________________________________________________

---

**Remember:** The comprehensive logging will help you identify exactly where any issue occurs. Follow the logs step by step through the flow!
