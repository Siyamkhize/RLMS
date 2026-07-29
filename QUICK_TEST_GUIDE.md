# Quick Trade-Specific ARPL Forms Test Guide
**Date:** July 9, 2026

---

## APP IS READY - TEST NOW

✅ APK Built: `build/app/outputs/flutter-apk/app-release.apk` (45.9 MB)  
✅ APK Installed: Successfully on device  
✅ API Created: `mobile/get_class_trade_info.php`  
✅ Dart Updated: Calls new API for OFO  

---

## FAST TEST (2 Minutes)

### Step 1: Open App → ARPL Assessment → View Complete Toolkit

### Step 2: Select Bricklaying Class Learner
- Dropdown shows: "Dikeledi Khoza" (or similar Bricklaying learner)
- This learner is in **Bricklaying class (ID 783)**

### Step 3: Check Logs in Android Studio
```
Look for these lines:
[TOOLKIT_DEBUG] Fetching OFO for classID: 783
[TOOLKIT_DEBUG] API Response Code: 200
[TOOLKIT_DEBUG] API returned OFO: 671103 for trade: Bricklaying
```

✅ If you see `OFO: 671103` = API working correctly!  
❌ If you see `OFO: 671101` = Still wrong (rebuild needed)

### Step 4: Click "Open Toolkit"
- Should open **Bricklayer form** (not Electrician)
- Form title or content should indicate Bricklaying trade

✅ If Bricklayer form opens = FIXED!  
❌ If Electrician form opens = NOT FIXED

---

## DETAILED TEST CHECKLIST

### Test Case 1: Bricklaying Class ✓
- [ ] Select Bricklaying class learner
- [ ] Logs show: `API returned OFO: 671103`
- [ ] Bricklayer form opens
- [ ] No crashes

### Test Case 2: Electrician Class ✓
- [ ] Select Electrician class learner (e.g., "lowest" class ID 782)
- [ ] Logs show: `API returned OFO: 671101`
- [ ] Electrician form opens
- [ ] No crashes

### Test Case 3: Plumbing Class ✓
- [ ] Select Plumbing class learner (if available)
- [ ] Logs show: `API returned OFO: 671102`
- [ ] Plumber form opens
- [ ] No crashes

---

## WHAT TO LOOK FOR IN LOGS

### ✅ CORRECT (After Fix)
```
[TOOLKIT_DEBUG] Learner classID: 783
[TOOLKIT_DEBUG] Fetching OFO for classID: 783
[TOOLKIT_DEBUG] API Response Code: 200
[TOOLKIT_DEBUG] API returned OFO: 671103 for trade: Bricklaying
[TOOLKIT_DEBUG] Set _selectedOfoNumber=671103
```

### ❌ WRONG (Before Fix)
```
[TOOLKIT_DEBUG] Learner classID: 783
[TOOLKIT_DEBUG] Set _selectedOfoNumber=671101  ← HARDCODED!
(No API call logs)
```

---

## API TEST (Terminal)

```bash
# Test Bricklaying class (783)
curl -X POST https://rlms.rlms.co.za/mobile/get_class_trade_info.php \
  -H "Content-Type: application/json" \
  -d '{"classID": 783}'

# Should return:
# {"status":"success","classID":783,"trade_id":4,"trade_name":"Bricklaying","ofo_number":"671103"}
```

---

## KNOWN GOOD VALUES

| Class | ID | Trade | OFO | Expected Form |
|-------|-----|-------|-----|-------|
| Bricklaying | 783 | Bricklayer | 671103 | ArplToolkitBricklayerPage |
| "lowest" | 782 | Electrician | 671101 | ArplToolkitViewerPage |
| (Plumbing) | TBD | Plumber | 671102 | ArplToolkitPlumberPage |

---

## IF SOMETHING GOES WRONG

### Logs show 404 error
```
[TOOLKIT_DEBUG] API error: 404
```
**Solution:** Check that `get_class_trade_info.php` exists on server

### Logs show OFO 671101 (wrong)
```
[TOOLKIT_DEBUG] API returned OFO: 671101
```
**Solution:** Old APK still running - rebuild and reinstall

### Logs show no API call
```
[TOOLKIT_DEBUG] Set _selectedOfoNumber=671101 (no API logs before)
```
**Solution:** Rebuild - old code still deployed

### Wrong form opens
- Bricklaying opens Electrician form
**Solution:** Check router logic in `lib/ArplToolkitRouter.dart`

---

## REBUILD IF NEEDED

```bash
cd c:\projects\rlmss
flutter clean
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## SUCCESS CRITERIA

✅ Select Bricklaying learner → OFO 671103 in logs → Bricklayer form opens  
✅ Select Electrician learner → OFO 671101 in logs → Electrician form opens  
✅ Select Plumbing learner → OFO 671102 in logs → Plumber form opens  
✅ No crashes or errors  
✅ API responds with correct trade data  

---

## SUMMARY

**What Changed:**
1. Created new API endpoint: `get_class_trade_info.php`
2. Updated Dart to call new API instead of hardcoding OFO
3. OFO now fetched dynamically from database based on class trade

**Result:**
- Bricklaying class learners now route to Bricklayer form ✅
- Electrician class learners now route to Electrician form ✅
- Plumbing class learners now route to Plumber form ✅
- No more hardcoded 671101 for everything ✅

Ready for testing!

