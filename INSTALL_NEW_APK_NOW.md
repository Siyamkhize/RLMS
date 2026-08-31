# 📲 Install New APK Now

**APK Location**: `C:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk`  
**Size**: 47.2 MB  
**Status**: Ready to install ✅

---

## Quick Install (USB)

```powershell
# Connect your Android phone via USB
adb devices

# Install (this overwrites the old version)
adb install -r C:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk
```

**Expected output**: `Success`

---

## Alternative: Copy to Phone

1. Open folder (already open): `build\app\outputs\flutter-apk\`
2. Copy `app-release.apk` to your phone (USB, Bluetooth, or cloud)
3. On phone: Open the APK file
4. Tap "Install"
5. If blocked: Settings → Security → Enable "Install from Unknown Sources"

---

## Test Immediately

1. Open app
2. Login as **SDP user**
3. Go to **Learner Details**
4. Capture a **signature**
5. **Look for**: ✅ "Signature uploaded successfully"

**Success!** The fix is working if you see that message.

---

## Check Server

Visit: `https://rlms.rlms.co.za/mobile/signatures/`  
You should now see signature files uploaded there.

---

## 🍎 For iPhone Users

See: `IOS_BUILD_QUICK_GUIDE.md`  
**Note**: Requires Mac or cloud build service (Codemagic.io)

---

**NEXT**: Install the APK and test! 🚀
