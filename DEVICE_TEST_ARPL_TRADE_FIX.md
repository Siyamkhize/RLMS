# Device Test: ARPL Trade-Specific Toolkit Forms

**Updated:** July 9, 2026  
**APK Status:** ✅ Fresh Build (45.9 MB)  
**API Status:** ✅ Endpoint Verified  
**Test Duration:** ~5 minutes

---

## Quick Test (5 Minutes)

### Prerequisites
- APK installed on device
- Connected to network (192.168.0.57:8080 API server accessible)
- Device has Bricklaying learner available

### Test Steps

#### Step 1: Launch ARPL Assessor
1. Open RLMSS app on device
2. Login as facilitator
3. Navigate to **ARPL Assessor Dashboard**
4. Verify dashboard loads ✓

#### Step 2: Select Bricklaying Class
1. Click **Assigned Classes**
2. Find and select class **783 (Bricklaying)**
3. Class should load with learners ✓

#### Step 3: Select Bricklaying Learner
1. From class, view learners
2. Select a learner from Bricklaying class (e.g., "Dikeledi Khoza" if available)
3. Learner details should display ✓

#### Step 4: Test Trade Lookup API
1. Open learner's ARPL Toolkit
2. In the dropdown, select this learner
3. **CRITICAL:** Watch device logs for:
   ```
   [TOOLKIT_DEBUG] Fetching OFO for classID: 783
   [TOOLKIT_DEBUG] API Response Code: 200
   [TOOLKIT_DEBUG] API returned OFO: 671103 for trade: Bricklayer
   ```

#### Step 5: Verify Correct Form Opens
1. After OFO retrieval, the ARPL Toolkit should route to **Bricklayer Form**
2. Verify form title indicates: "Bricklaying" or "Bricklayer"
3. Form should NOT show "Electrician" title

#### Step 6: Test Form Navigation
1. Navigate through Appendices (A, B, C, D, E, F, G, H)
2. Verify all sections load correctly
3. Try filling out one section to verify save functionality

---

## Expected vs Actual Results

### Expected (Fixed Version)

**Test Log Output:**
```
[TOOLKIT_DEBUG] Dropdown onChanged: value=...
[TOOLKIT_DEBUG] Learner classID: 783
[TOOLKIT_DEBUG] Fetching OFO for classID: 783
[TOOLKIT_DEBUG] API Response Code: 200
[TOOLKIT_DEBUG] API Response Body: {"status":"success",...,"ofo_number":"671103",...}
[TOOLKIT_DEBUG] API returned OFO: 671103 for trade: Bricklayer
```

**Form Behavior:**
- ✓ Bricklayer toolkit opens (correct form)
- ✓ All sections load without errors
- ✓ Data persistence works
- ✓ No 404 errors

### Previous (Broken Version - What We Fixed)

**Old Log Output:**
```
[TOOLKIT_DEBUG] Learner classID: 783
[TOOLKIT_DEBUG] Fetching OFO for classID: 783
[TOOLKIT_DEBUG] API error: 404, using default 671101  ← WRONG
```

**Old Form Behavior:**
- ✗ Electrician form opened instead of Bricklayer
- ✗ API returned 404
- ✗ Fallback to hardcoded OFO 671101

---

## Test Additional Trades (Optional)

### Test with Electrician Class (782)
1. Select class **782 (Electrician)**
2. Select learner from Electrician class
3. Expected logs:
   ```
   [TOOLKIT_DEBUG] Learner classID: 782
   [TOOLKIT_DEBUG] API returned OFO: 671101 for trade: Electrician
   ```
4. Electrician form should open

### Test with Plumber Class (784)
1. Select class **784 (Plumber)**
2. Select learner from Plumber class
3. Expected logs:
   ```
   [TOOLKIT_DEBUG] Learner classID: 784
   [TOOLKIT_DEBUG] API returned OFO: 671102 for trade: Plumber
   ```
4. Plumber form should open

---

## Troubleshooting

### Issue: Still Getting OFO 671101 (Default)
**Possible Causes:**
1. APK not updated (old version still installed)
   - **Fix:** Uninstall old APK: `adb uninstall com.example.rlmss`
   - Then reinstall fresh: `adb install build/app/outputs/flutter-apk/app-release.apk`

2. API endpoint not responding
   - **Fix:** Check API server is running on 192.168.0.57:8080
   - Test manually: `curl http://192.168.0.57:8080/assessorReport2/mobile/get_class_trade_info.php?classID=783`

3. Device not on same network
   - **Fix:** Verify device is on same Wi-Fi as PC running API server
   - Ping test: `ping 192.168.0.57` from device (if possible)

### Issue: API Error 404
**Possible Causes:**
1. Class doesn't have trade_id assigned
   - **Fix:** Verify class has trade_id in database: `SELECT trade_id FROM class WHERE classID = 783`

2. class-to-trade relationship missing
   - **Fix:** Run `find_classes_with_trade.php` to verify data

### Issue: Form Won't Load After OFO Retrieval
**Possible Causes:**
1. Dart routing issue
   - **Check:** Verify `ArplToolkitRouter.dart` has routes for all trades
   - Verify trade names match in router

2. Trade-specific form not implemented
   - **Fix:** Verify `ArplToolkitBricklayerPage.dart` and `ArplToolkitPlumberPage.dart` exist

---

## Quick Diagnostics

### To View Device Logs:
```bash
adb logcat | grep -i toolkit
```

### To Test API Directly from PC:
```bash
# Test Bricklaying class
curl -X POST http://192.168.0.57:8080/assessorReport2/mobile/get_class_trade_info.php \
  -H "Content-Type: application/json" \
  -d '{"classID": 783}'

# Expected response:
# {"status":"success","classID":783,"className":"Bricklaying","trade_id":4,"trade_name":"Bricklayer","ofo_number":"671103","siteName":"NDENGEZI"}
```

### To Verify Database State:
```bash
# Run on server:
php find_classes_with_trade.php
```

---

## Success Criteria

✅ **Test PASSED if:**
1. Device logs show `API Response Code: 200`
2. Device logs show `API returned OFO: 671103` (not 671101)
3. Bricklayer form opens after OFO retrieval
4. All form sections load and function correctly
5. No 404 or API errors in logs

❌ **Test FAILED if:**
1. Logs show `API error: 404` or API error
2. OFO is still showing as 671101 (default fallback)
3. Electrician form opens instead of Bricklayer
4. Form sections fail to load
5. Form buttons don't work

---

## Report Results

After testing, please report:
1. Device logs (copy full [TOOLKIT_DEBUG] section)
2. Whether correct form opened (Bricklayer vs Electrician)
3. Any errors encountered
4. Whether form sections load and save correctly

---

## Next Steps After Successful Test

1. ✅ Test with other trades (Electrician, Plumber)
2. ✅ Test form data persistence (fill out sections, save, reload)
3. ✅ Test AppendixH dropdown (verify learner selection works)
4. ✅ Test PDF export functionality
5. ✅ Deploy to production when all trades verified

---

**APK Ready:** `build/app/outputs/flutter-apk/app-release.apk` (45.9 MB)  
**Build Date:** July 9, 2026  
**Last Updated:** After Dart code fix (AppConfig.baseUrl)
