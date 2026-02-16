# URL Change Troubleshooting Guide

## ✅ What Has Been Updated

All code files have been successfully updated to use `rlms.rlms.co.za`:

### 1. Configuration Files Updated:
- ✅ `lib/config.dart` - Main server configuration
- ✅ `get_facilitator_profile.php` - PHP base URL
- ✅ All test PHP files updated

### 2. Dart Files Updated:
- ✅ `lib/AddLearnerPage.dart` - Hardcoded URL fixed
- ✅ `lib/AssessorPage.dart` - All 30+ hardcoded URLs updated
- ✅ All other Dart files verified clean

### 3. Verification Completed:
```
Server Host: rlms.rlms.co.za
Base URL: https://rlms.rlms.co.za/mobile
Login URL: https://rlms.rlms.co.za/mobile/login.php
Clock In URL: https://rlms.rlms.co.za/mobile/clockin.php
```

## 🔧 If App Still Connects to Old Server

### Step 1: Clear Flutter Cache
```bash
flutter clean
flutter pub get
```

### Step 2: Rebuild the App
```bash
# For debug build
flutter build apk --debug

# For release build  
flutter build apk --release
```

### Step 3: Clear App Data (Android)
1. Go to Settings > Apps > RLMSS
2. Tap "Storage"
3. Tap "Clear Data" and "Clear Cache"
4. Reinstall the app

### Step 4: Check Local Database
The app might have cached server data. To force a fresh sync:
1. Uninstall the app completely
2. Reinstall the new version
3. Login fresh (this will create new local database)

### Step 5: Verify Server Connectivity
Test if the new server is accessible:
```bash
# Test basic connectivity
curl -I https://rlms.rlms.co.za/mobile/

# Test login endpoint
curl -X POST https://rlms.rlms.co.za/mobile/login.php \
  -d "email=test@test.com&password=test123"
```

## 🚨 Common Issues

### Issue 1: App Shows Old Server in Logs
**Cause**: Running old compiled version
**Solution**: Rebuild and reinstall the app

### Issue 2: Login Still Goes to Old Server
**Cause**: Cached configuration or old APK
**Solution**: 
1. `flutter clean`
2. `flutter build apk`
3. Install new APK

### Issue 3: Some Features Work, Others Don't
**Cause**: Mixed hardcoded URLs (some updated, some not)
**Solution**: All URLs have been updated, rebuild app

### Issue 4: "Connection Failed" Errors
**Cause**: New server not ready or SSL issues
**Solution**: Verify new server is properly configured

## 📱 Testing the Fix

### 1. Check App Logs
Look for these log messages:
```
[CONFIG] Base URL: https://rlms.rlms.co.za/mobile
```

### 2. Monitor Network Traffic
Use developer tools to see actual HTTP requests being made.

### 3. Test Login
Try logging in - the network request should go to `rlms.rlms.co.za`

## ✅ Final Verification

Once the app is rebuilt and reinstalled:

1. **Login Screen**: Should connect to new server
2. **Sync Operations**: Should use new server URLs
3. **API Calls**: All should go to `rlms.rlms.co.za`
4. **Image URLs**: Should use new domain for images

## 🔄 If Problem Persists

If the app is still connecting to the old server after following all steps:

1. **Double-check** that you're running the newly built APK
2. **Verify** the new server is accessible and configured correctly
3. **Check** if there are any proxy or DNS caching issues
4. **Ensure** the new server has all the required PHP files uploaded

The configuration change is complete in the code. The issue is likely that you need to rebuild and reinstall the app to see the changes take effect.