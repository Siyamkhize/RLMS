# CONFIG UPDATE - ONLINE SERVER DEPLOYMENT

**Date:** July 13, 2026  
**Status:** ✅ UPDATED

---

## CHANGE SUMMARY

Updated `lib/config.dart` to point to the online server instead of local development.

---

## CONFIGURATION CHANGE

### Previous Configuration (Local Development)
```dart
static const String serverHost = '192.168.0.57';      // Local IP
static const int serverPort = 8080;                    // Local port
static const String serverProtocol = 'http';           // HTTP
static const String basePath = '/assessorReport2/mobile';
```

**Result:** `http://192.168.0.57:8080/assessorReport2/mobile`

---

### NEW Configuration (Online Server) ✅
```dart
static const String serverHost = 'rlms.rlms.co.za';    // Online domain
static const int serverPort = 443;                     // HTTPS port (standard)
static const String serverProtocol = 'https';          // HTTPS secure
static const String basePath = '/assessorReport2/mobile';
```

**Result:** `https://rlms.rlms.co.za/assessorReport2/mobile`

---

## WHAT THIS MEANS

### All API Endpoints Now Point To
**`https://rlms.rlms.co.za/assessorReport2/mobile/`**

Examples:
- Login: `https://rlms.rlms.co.za/assessorReport2/mobile/login.php`
- Get Learners: `https://rlms.rlms.co.za/assessorReport2/mobile/get_learners.php`
- Save ARPL: `https://rlms.rlms.co.za/assessorReport2/mobile/save_arpl_appendix_b.php`
- Sync Data: `https://rlms.rlms.co.za/assessorReport2/mobile/sync_learner.php`

All 58 ARPL endpoints automatically redirect to the online server.

---

## AFFECTED COMPONENTS

### Mobile App (Flutter)
- All HTTP requests now point to online server
- SSL/HTTPS encryption enabled
- No need to rebuild for testing different environments (just update config)

### API Calls Affected (100% of app)
- ✓ Login & Authentication
- ✓ Learner synchronization
- ✓ POE uploads
- ✓ ARPL assessments
- ✓ Clocking (in/out)
- ✓ Material issuance
- ✓ Monitoring
- ✓ All 58 ARPL endpoints
- ✓ SDP projects & learning pathways
- ✓ All logistics operations

---

## DEPLOYMENT STEPS

### 1. Rebuild Flutter App (APK)
```bash
cd c:\projects\rlmss
flutter clean
flutter pub get
flutter build apk --release
```

### 2. Install on Test Device
```bash
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

### 3. Test Connectivity
- Open app
- Try to login with facilitator credentials
- Should connect to `https://rlms.rlms.co.za/assessorReport2/mobile/login.php`

### 4. Verify All Endpoints Working
- Check ARPL module loads
- Try saving assessments
- Verify sync operations
- Check POE uploads

---

## REVERTING TO LOCAL (If Needed)

To switch back to local development:

**Edit `lib/config.dart`:**
```dart
// Comment out online config
// static const String serverHost = 'rlms.rlms.co.za';
// static const int serverPort = 443;
// static const String serverProtocol = 'https';
// static const String basePath = '/assessorReport2/mobile';

// Uncomment local config
static const String serverHost = '192.168.0.57';
static const int serverPort = 8080;
static const String serverProtocol = 'http';
static const String basePath = '/assessorReport2/mobile';
```

Then rebuild APK.

---

## FILE MODIFIED

**File:** `c:\projects\rlmss\lib\config.dart`  
**Lines Changed:** 4-7 (swapped comments between online and local configs)  
**Impact:** All 100+ API endpoints  
**Requires:** APK rebuild and reinstall

---

## VERIFICATION

The mobile app will now:

✅ Connect securely to `https://rlms.rlms.co.za/assessorReport2/mobile/`  
✅ Use HTTPS encryption for all data transfers  
✅ Authenticate users against online database  
✅ Sync learner data with online server  
✅ Store assessments in online database  
✅ Upload POE documents to online storage  
✅ Access all 58 ARPL endpoints on online server  

---

## NEXT STEPS

1. **Rebuild APK**
   ```bash
   flutter build apk --release
   ```

2. **Install on Device**
   ```bash
   adb install -r app-release.apk
   ```

3. **Login and Test**
   - Use your facilitator credentials
   - App will now connect to online server

4. **Verify Endpoints Responding**
   - Check Logcat for connection messages
   - Verify learner data syncs
   - Test ARPL form submissions

---

## SUMMARY

✅ **Configuration updated**  
✅ **Online server URL set to: https://rlms.rlms.co.za/assessorReport2/mobile/**  
✅ **HTTPS/SSL enabled for secure connections**  
✅ **All 58 ARPL endpoints will use online server**  
✅ **Ready for APK rebuild and deployment**

**Status:** Ready to build new APK and install on devices.
