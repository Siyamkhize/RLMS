# Build New APK - Appendix E Database Fix

**Date:** July 8, 2026  
**Changes:** Appendix E now reads from database instead of hardcoded data

---

## What Changed

✅ Fixed Appendix E to read activities from `arplappxe_electrician_activities` table  
✅ Fixed ratings save/load to `arplappxe_electrician_activity_ratings` table  
✅ Proper 1-5 rating scale with database persistence  

---

## Step 1: Clean Build

```cmd
flutter clean
flutter pub get
```

---

## Step 2: Build Release APK

```cmd
flutter build apk --release
```

**Expected Output:**
```
✓ Built build\app\outputs\flutter-apk\app-release.apk (XX.X MB)
```

---

## Step 3: Locate the APK

The APK will be at:
```
c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk
```

---

## Step 4: Transfer to Device

### Option A: USB Cable
1. Connect your Android device via USB
2. Enable File Transfer mode
3. Copy `app-release.apk` to device's Downloads folder

### Option B: Cloud Storage
1. Upload to Google Drive/Dropbox
2. Download on device
3. Open from Downloads

### Option C: Direct ADB Install
```cmd
adb install build\app\outputs\flutter-apk\app-release.apk
```

---

## Step 5: Install on Device

1. **Find the APK** in Downloads folder
2. **Tap to install** (may need to allow "Install from Unknown Sources")
3. **Uninstall old version** if prompted, or install over it
4. **Open the app**

---

## Step 6: Test Appendix E

1. Login to the app
2. Navigate to **ARPL Assessor** page
3. Select a learner
4. Go to **Appendix E** tab
5. **Verify activities load from database** (not hardcoded)
6. Rate some activities (1-5)
7. Add comments
8. Click **Save Appendix E**
9. Verify success message
10. Close and reopen - ratings should persist

---

## Quick Commands

```cmd
cd c:\projects\rlmss
flutter clean
flutter pub get
flutter build apk --release
```

Then install:
```cmd
adb install build\app\outputs\flutter-apk\app-release.apk
```

---

## Troubleshooting

### Build Fails
```cmd
flutter doctor
flutter clean
flutter pub get
flutter build apk --release
```

### Can't Install APK
- Enable "Install from Unknown Sources" in device settings
- Uninstall old version first if needed
- Try ADB install method

### Activities Don't Show
- Check debug script: `http://localhost/assessorReport2/debug_arpl_appendix_e.php`
- Verify activities exist in `arplappxe_electrician_activities` table
- Check app console logs for errors

---

## Verification

After installing, check:
- ✅ Activities load from database (no hardcoded list)
- ✅ Can rate activities 1-5
- ✅ Can add comments
- ✅ Save works
- ✅ Ratings persist after reload
- ✅ Existing ratings load correctly

---

**Build Time:** ~5-10 minutes  
**File Size:** ~50-60 MB  
**Target:** Android 5.0+ (API 21+)
