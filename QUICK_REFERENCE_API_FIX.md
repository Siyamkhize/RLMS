# Quick Reference: ARPL Trade API Fix

**Status:** ✅ COMPLETE  
**APK:** Fresh build ready on device  
**API:** Verified working  

---

## What Was Fixed

### Problem
Learners from Bricklaying class (783) were opening Electrician forms instead of Bricklayer forms.

### Root Causes
1. ❌ Hardcoded HTTPS URL in Dart code
2. ❌ Wrong API endpoint called 
3. ❌ Fallback to default OFO 671101

### Solutions Applied
1. ✅ Changed to `AppConfig.baseUrl` (respects local/production config)
2. ✅ Created dedicated `get_class_trade_info.php` endpoint
3. ✅ API now returns correct OFO for each class's trade

---

## How It Works Now

```
User selects learner from Bricklaying class (classID 783)
         ↓
App calls: GET_CLASS_TRADE_INFO(classID=783)
         ↓
API Query:
  SELECT trade_id FROM class WHERE classID=783
  → trade_id = 4
  SELECT ofo_number, trade_name FROM arpl_trades WHERE trade_id=4
  → ofo_number = 671103, trade_name = "Bricklayer"
         ↓
API returns: {"ofo_number": "671103", "trade_name": "Bricklayer"}
         ↓
App opens: BRICKLAYER FORM ✓
```

---

## API Endpoint

**URL:** `http://[server]/assessorReport2/mobile/get_class_trade_info.php`

**Request:**
```json
POST
{
  "classID": 783
}
```

**Response:**
```json
{
  "status": "success",
  "classID": 783,
  "className": "Bricklaying",
  "trade_id": 4,
  "trade_name": "Bricklayer",
  "ofo_number": "671103",
  "siteName": "NDENGEZI"
}
```

---

## Test Command

```bash
curl -X POST http://192.168.0.57:8080/assessorReport2/mobile/get_class_trade_info.php \
  -H "Content-Type: application/json" \
  -d '{"classID": 783}'
```

**Expected:** OFO 671103, trade "Bricklayer"

---

## Files Changed

| File | Change | Status |
|------|--------|--------|
| `mobile/get_class_trade_info.php` | Created new endpoint | ✅ New |
| `lib/ArplAssessorPage.dart` line 12485 | Changed to AppConfig.baseUrl | ✅ Fixed |
| `lib/ArplAssessorPage.dart` | Added _fetchOfoForClass() method | ✅ New |
| APK | Rebuilt with changes | ✅ Built |

---

## Expected Device Log Output

**Good (Fixed Version):**
```
[TOOLKIT_DEBUG] Fetching OFO for classID: 783
[TOOLKIT_DEBUG] API Response Code: 200
[TOOLKIT_DEBUG] API returned OFO: 671103 for trade: Bricklayer
```

**Bad (Old Version - Should NOT see this):**
```
[TOOLKIT_DEBUG] API error: 404, using default 671101
```

---

## Trade Mapping

| OFO | Trade | Class Example | Expected Form |
|-----|-------|---------------|---------------|
| 671101 | Electrician | 782 | ArplToolkitViewerPage |
| 671102 | Plumber | 784 | ArplToolkitPlumberPage |
| 671103 | Bricklayer | 783 | ArplToolkitBricklayerPage |

---

## Quick Checklist

- ✅ API endpoint works: returns OFO 671103 for class 783
- ✅ Dart code uses AppConfig.baseUrl
- ✅ APK rebuilt and installed
- ⏳ Device test: Select Bricklaying learner → Verify Bricklayer form opens
- ⏳ Test other trades: Electrician, Plumber
- ⏳ Production deployment when ready

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Still showing OFO 671101 | Uninstall and reinstall APK |
| API returns 404 | Check class has trade_id assigned |
| Wrong form opens | Check router implementation |
| Cannot reach API | Verify device on same network as server |

---

## Documentation Files

- `API_ENDPOINT_TEST_RESULTS.md` - Full API test results
- `DEVICE_TEST_ARPL_TRADE_FIX.md` - How to test on device
- `ARPL_TRADE_FIX_COMPLETE_SUMMARY.md` - Complete technical summary
- `test_get_class_trade_info.php` - PHP test suite
- `QUICK_REFERENCE_API_FIX.md` - This file

---

**Ready for:** Device Testing  
**APK Location:** `build/app/outputs/flutter-apk/app-release.apk`  
**Last Updated:** July 9, 2026
