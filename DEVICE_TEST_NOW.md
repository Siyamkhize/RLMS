# Device Test - Trade-Specific ARPL Forms
**Build Date:** July 9, 2026  
**APK Version:** 45.9 MB  
**Status:** Ready for Testing

---

## 🚀 APP IS READY TO TEST

✅ APK Built successfully  
✅ APK Installed on device  
✅ New API endpoint created  
✅ Dart code updated  
✅ All checks passed  

**NOW TEST IT!**

---

## TEST NOW - 5 MINUTES

### Step 1: Open App
- Launch RLMSS app on device
- Go to: ARPL Assessment → View Complete Toolkit

### Step 2: Select Bricklaying Learner
- Click Candidate dropdown
- Select a learner from **Bricklaying class** (e.g., "Dikeledi Khoza")

### Step 3: Check Android Studio Logs
```
Search for: TOOLKIT_DEBUG

Look for this:
[TOOLKIT_DEBUG] Learner classID: 783
[TOOLKIT_DEBUG] Fetching OFO for classID: 783
[TOOLKIT_DEBUG] API returned OFO: 671103 for trade: Bricklaying
[TOOLKIT_DEBUG] Set _selectedOfoNumber=671103
```

### Step 4: Click "Open Toolkit"
**Expected:** Bricklayer form opens  
**Not Expected:** Electrician form (wrong)

---

## WHAT SUCCESS LOOKS LIKE

✅ Logs show: `API returned OFO: 671103`  
✅ Logs show: `Set _selectedOfoNumber=671103`  
✅ Bricklayer form opens (not Electrician)  
✅ No crashes  
✅ No errors  

---

## WHAT FAILURE LOOKS LIKE

❌ Logs show: `Set _selectedOfoNumber=671101` (without API call)  
❌ Logs show: `API error: 404`  
❌ Electrician form opens (wrong)  
❌ App crashes  
❌ Network error  

---

## TEST SCENARIOS

### Scenario 1: Bricklaying Class (MUST PASS ✅)
**Steps:**
1. Select Bricklaying learner (classID 783)
2. Check logs for: `OFO: 671103`
3. Click "Open Toolkit"
4. Verify Bricklayer form opens

**Expected Logs:**
```
[TOOLKIT_DEBUG] Learner classID: 783
[TOOLKIT_DEBUG] API returned OFO: 671103 for trade: Bricklaying
```

---

### Scenario 2: Electrician Class (SHOULD PASS ✅)
**Steps:**
1. Go back to learner selection
2. Select Electrician learner (classID 782, e.g., "lowest" class)
3. Check logs for: `OFO: 671101`
4. Click "Open Toolkit"
5. Verify Electrician form opens

**Expected Logs:**
```
[TOOLKIT_DEBUG] Learner classID: 782
[TOOLKIT_DEBUG] API returned OFO: 671101 for trade: Electrician
```

---

### Scenario 3: Plumbing Class (IF AVAILABLE ✅)
**Steps:**
1. Go back to learner selection
2. Find and select Plumbing learner (if class exists)
3. Check logs for: `OFO: 671102`
4. Click "Open Toolkit"
5. Verify Plumber form opens

**Expected Logs:**
```
[TOOLKIT_DEBUG] Learner classID: XXX
[TOOLKIT_DEBUG] API returned OFO: 671102 for trade: Plumbing
```

---

## HOW TO VIEW LOGS

### Android Studio (Easy)
1. Window → Logcat (or Alt+6)
2. Type in filter: `TOOLKIT_DEBUG`
3. Select device from dropdown
4. Perform test actions
5. Watch logs scroll

### Command Line (Alternative)
```bash
adb logcat | grep TOOLKIT_DEBUG
```

### Save to File
```bash
adb logcat | grep TOOLKIT_DEBUG > test_logs.txt
```

---

## PASS/FAIL CHECKLIST

### Bricklaying Test
- [ ] Logs show classID: 783
- [ ] Logs show API response code: 200
- [ ] Logs show OFO: 671103
- [ ] Bricklayer form opens
- [ ] No crashes

### Electrician Test
- [ ] Logs show classID: 782
- [ ] Logs show API response code: 200
- [ ] Logs show OFO: 671101
- [ ] Electrician form opens
- [ ] No crashes

### Plumbing Test (if available)
- [ ] Logs show classID: TBD
- [ ] Logs show API response code: 200
- [ ] Logs show OFO: 671102
- [ ] Plumber form opens
- [ ] No crashes

### Overall
- [ ] All 3 trades route correctly (or 2/3 if Plumbing unavailable)
- [ ] No API errors (404, 500, etc.)
- [ ] No JSON parsing errors
- [ ] No crashes or exceptions
- [ ] App responds smoothly

---

## ERROR CHECKLIST

If you see any of these, the fix didn't work:

### ❌ Hardcoded OFO Error
```
[TOOLKIT_DEBUG] Learner classID: 783
[TOOLKIT_DEBUG] Set _selectedOfoNumber=671101  ← WRONG!
(no "API returned" line)
```
**Fix:** Rebuild and reinstall APK

### ❌ API 404 Error
```
[TOOLKIT_DEBUG] API error: 404
```
**Fix:** Check that `get_class_trade_info.php` exists on server

### ❌ API JSON Error
```
[TOOLKIT_DEBUG] JSON decode error
```
**Fix:** Check API response format, verify database query works

### ❌ Wrong Form Opens
```
Select Bricklaying → Opens Electrician form ❌
```
**Fix:** Check ArplToolkitRouter.dart routing logic

---

## IF TEST FAILS

### Immediate Actions
1. **Check logs** - Look for API error or hardcoded OFO
2. **Note the error** - Write down the exact error message
3. **Screenshot logs** - Capture for debugging
4. **Try again** - Restart app and test again

### If Still Failing
1. **Rebuild:**
   ```bash
   cd c:\projects\rlmss
   flutter clean
   flutter build apk --release
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

2. **Test API manually:**
   ```bash
   curl -X POST https://rlms.rlms.co.za/mobile/get_class_trade_info.php \
     -H "Content-Type: application/json" \
     -d '{"classID": 783}'
   ```

3. **Check database:**
   ```bash
   php find_classes_with_trade.php
   ```

---

## SUCCESS SIGNALS

### 🟢 GREEN LIGHTS (Tests Passing)
✅ Logs show correct OFO for each class  
✅ Correct forms open for each trade  
✅ API returns 200 status code  
✅ No errors in logs  
✅ App doesn't crash  

### 🔴 RED LIGHTS (Tests Failing)
❌ Still seeing hardcoded 671101  
❌ API returns 404 or error  
❌ Wrong form opens  
❌ App crashes  
❌ Network errors  

---

## REFERENCE VALUES

Keep these handy:

| Class | ID | Expected OFO | Expected Form |
|-------|-----|-------------|-------|
| Bricklaying | 783 | 671103 | ArplToolkitBricklayerPage |
| lowest | 782 | 671101 | ArplToolkitViewerPage |
| (Plumbing) | TBD | 671102 | ArplToolkitPlumberPage |

---

## TEST SUMMARY

**Total Tests:** 3 (or 2 if Plumbing unavailable)  
**Estimated Time:** 5-10 minutes  
**Required:** Device with app installed + Android Studio for logs  

**Goal:** Verify each trade routes to correct form

---

## DOCUMENTATION LINKS

**For Developers:**
- API_DOCUMENTATION.md - Full API specs
- API_TRADE_FIX_COMPLETE.md - Technical details

**For Testing:**
- QUICK_TEST_GUIDE.md - Even faster version
- EXPECTED_LOG_OUTPUT.md - What to expect

---

## READY? GO TEST!

1. Open app
2. Select Bricklaying learner
3. Check logs for OFO 671103
4. Click Open Toolkit
5. Verify Bricklayer form opens

**That's it!** 

If all 3 trades route correctly = ✅ FEATURE COMPLETE

Report results in format:
```
✅ Bricklaying (783) → OFO 671103 → Bricklayer form
✅ Electrician (782) → OFO 671101 → Electrician form
✅ Plumbing (XXX) → OFO 671102 → Plumber form
```

