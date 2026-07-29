# Appendix H Troubleshooting Guide

**Issue**: Assessment items not showing, only save button visible

## Fix Applied

Added loading states and error handling to `_buildAppendixH()` method:
- Shows loading spinner while fetching data
- Shows error message with "Retry" button if data fails to load
- Improved debug logging in `_loadAppendixHItems()`

## How to Check What's Happening

### 1. Check Device Logs
Run this command to see the debug output:
```bash
adb logcat | findstr "APPX H"
```

Look for these messages:
- `[APPX H] Starting to load items for learner: 20286`
- `[APPX H] Loading items from: http://192.168.0.57:8080/assessorReport2/mobile/get_appxh_acr_items.php?learner_id=20286`
- `[APPX H] Response status: 200`
- `[APPX H] Response body: {...}`
- `[APPX H] Loaded 4 items successfully`

### 2. Test API Directly
Test the API endpoint from your PC:
```bash
curl "http://192.168.0.57:8080/assessorReport2/mobile/get_appxh_acr_items.php?learner_id=20286"
```

Expected response:
```json
{
  "success": true,
  "learner_id": 20286,
  "assessment_items": [
    {"ACRID": "1", "AssessmentType": "Knowledge assessment", "Status": null, "Remarks": null},
    {"ACRID": "2", "AssessmentType": "Practical assessment", "Status": null, "Remarks": null},
    {"ACRID": "3", "AssessmentType": "Workplace Observation", "Status": null, "Remarks": null},
    {"ACRID": "4", "AssessmentType": "Overall Result", "Status": null, "Remarks": null}
  ]
}
```

### 3. Check Network Connectivity
Make sure the device can reach the server:
```bash
# From device shell
adb shell ping -c 3 192.168.0.57
```

### 4. What You Should See on Device

**Scenario A: Loading (Initial State)**
- Spinning progress indicator
- Text: "Loading assessment items..."

**Scenario B: Success (After API loads)**
- 4 assessment item cards:
  1. Knowledge assessment
  2. Practical assessment
  3. Workplace Observation
  4. Overall Result
- Each with dropdown and remarks field
- Save button at bottom

**Scenario C: Error (If API fails)**
- Orange warning icon
- Text: "No assessment items found"
- Text: "Learner ID: 20286"
- Blue "Retry" button

## Common Issues & Solutions

### Issue 1: API File Not on Server
**Symptom**: HTTP 404 error in logs
**Solution**: Make sure `mobile/get_appxh_acr_items.php` exists on the server at:
`C:\xampp\htdocs\assessorReport2\mobile\get_appxh_acr_items.php`

### Issue 2: Database Table Missing
**Symptom**: API returns `success: false`
**Solution**: Run the table creation script:
```bash
php mobile/create_appxh_tables.php
```

### Issue 3: Wrong Base URL
**Symptom**: Connection timeout or refused
**Solution**: Check `lib/config.dart`:
```dart
static const String serverHost = '192.168.0.57';
static const int serverPort = 8080;
static const String basePath = '/assessorReport2/mobile';
```

### Issue 4: Learner Not Selected
**Symptom**: Nothing happens when tab is clicked
**Solution**: 
1. Make sure you've selected a learner from the dropdown
2. Check logs for: `[APPX H] No learner selected, cannot load items`

## Testing Steps

1. **Open App** on device
2. **Login** as assessor/facilitator
3. **Go to** ARPL → Assessor Review
4. **Select Learner**: Choose learner ID 20286
5. **Click** "Appx H (Access Rec)" tab
6. **Observe**:
   - Should show loading spinner briefly
   - Then show 4 assessment cards
   - If error, check logs and click "Retry"

## Quick Fix Commands

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release

# Install on device
adb install -r build\app\outputs\flutter-apk\app-release.apk

# Watch logs
adb logcat | findstr "APPX H"
```

## API Test Command
```bash
php -r "\$_GET['learner_id']='20286'; include 'mobile/get_appxh_acr_items.php';"
```

Should output:
```json
{
    "success": true,
    "learner_id": 20286,
    "assessment_items": [...]
}
```

---

**Status**: Fix deployed in latest APK (45.6MB)
**Date**: July 8, 2026
**Next**: Check device logs to see actual error
