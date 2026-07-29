# LOCAL DEV REVERT COMPLETE

**Date:** July 14, 2026  
**Status:** ✅ COMPLETE

---

## CHANGES MADE

### Configuration Reverted

**File:** `lib/config.dart`

**Changed From:** Online server (rlms.rlms.co.za)  
**Changed To:** Local dev server (192.168.0.57:8080)

### Current Config (LOCAL DEV)

```dart
static const String serverHost = '192.168.0.57';      // Local dev IP
static const int serverPort = 8080;                   // Local dev port
static const String serverProtocol = 'http';          // Local dev uses HTTP
static const String basePath = '/assessorReport2/mobile';
```

**Result URL:** `http://192.168.0.57:8080/assessorReport2/mobile/`

---

## BUILD SUMMARY

✅ Flutter clean  
✅ Flutter pub get  
✅ Flutter build apk --release  
✅ APK uninstalled  
✅ APK installed (local dev version)  
✅ App launched on device  

---

## APK DETAILS

**Location:** `C:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk`  
**Size:** 45.9 MB  
**Status:** Ready for local testing  

---

## NEXT STEPS

1. Make sure your PC (192.168.0.57:8080) is running the XAMPP/PHP server
2. Device must be on same Wi-Fi as the PC
3. Login with test account
4. Test ARPL assessor login
5. Verify ARPL menu now shows (if local DB has Project_pathway set)

---

## SWITCHING BACK TO ONLINE

To switch back to online server:

**File:** `lib/config.dart`

**Change To:**
```dart
static const String serverHost = 'rlms.rlms.co.za';
static const int serverPort = 443;
static const String serverProtocol = 'https';
static const String basePath = '/mobile';
```

Then rebuild APK with:
```bash
flutter clean && flutter pub get && flutter build apk --release
```

---

## TROUBLESHOOTING

### Device Can't Connect to Local Server
- Verify device is on same Wi-Fi as PC
- Verify PC IP is 192.168.0.57 (may be different)
- Check firewall allows port 8080

### Wrong Local IP
- Run on PC: `ipconfig` and find IPv4 address
- Update `lib/config.dart` with correct IP
- Rebuild APK

### No ARPL Menu
- Local DB needs `Project_pathway` field set in `sites` table
- Check if you applied the `mobile/get_classes.php` fix locally

---

**Build Complete - Ready for Local Testing**

