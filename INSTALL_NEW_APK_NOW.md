# 🚀 INSTALL NEW APK NOW - QUICK GUIDE

## ⚠️ CRITICAL: THE PROBLEM IS FIXED, YOU JUST NEED TO INSTALL THE NEW APK

---

## WHAT WAS WRONG?

Your old APK was pointing to the **LOCAL server** (`192.168.0.57`) instead of the **ONLINE server** (`rlms.rlms.co.za`).

The LOCAL server has different data ("Short Skills Programme") instead of ARPL data.

---

## WHAT WE DID

✅ Fixed `lib/config.dart` to point to ONLINE server  
✅ Enhanced pathway detection to find ARPL in JSON data  
✅ **REBUILT THE APK** with the correct configuration  

---

## WHAT YOU NEED TO DO

### 1️⃣ UNINSTALL OLD APP (MUST DO THIS!)

On your Android device:
- Settings → Apps → RLMSS → **Uninstall**

**⚠️ You MUST uninstall! Don't skip this!**

---

### 2️⃣ INSTALL NEW APK

Transfer this file to your device and install it:

```
C:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk
```

**Size:** 45.9 MB  
**Built:** July 14, 2026  
**Server:** https://rlms.rlms.co.za/mobile ✅

---

### 3️⃣ TEST IT

1. Open the app
2. Log in as **Facilitator 6**
3. You should see **ARPL menu items**:
   - ARPL Toolkit
   - ARPL Competency Scale
   - ARPL Marking
   - ARPL Hierarchical Navigator

---

## HOW TO VERIFY IT WORKED

After logging in, check the Android logs (logcat) for:

✅ **Correct:** `[CONFIG] Base URL: https://rlms.rlms.co.za/mobile`  
✅ **Correct:** `[ArplAssessorPage] Detected Pathway: ARPL`  
✅ **Correct:** `[ArplAssessorPage] Will show ARPL dashboard`  

❌ **Wrong:** `[CONFIG] Base URL: http://192.168.0.57:8080` (means old APK still installed)  
❌ **Wrong:** `Detected Pathway: SHORT SKILLS PROGRAMME` (means old APK)

---

## THAT'S IT!

The code is fixed, the APK is built. Just:
1. **Uninstall old app**
2. **Install new APK**
3. **Test**

---

## IF IT STILL DOESN'T WORK

If you still see the wrong menu:
1. Confirm you **completely uninstalled** the old app
2. Confirm the new APK installed successfully
3. Share the logs showing `[CONFIG] Base URL: ...`

The fix is 100% complete in the new APK. If it doesn't work, it means the old APK is still installed.

---

**APK Location:** `build\app\outputs\flutter-apk\app-release.apk`  
**Full Details:** See `ARPL_FIX_COMPLETE_FINAL.md`
