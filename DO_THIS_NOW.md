# 🚨 DO THIS NOW - BLANK SCREEN FIX

**Date:** July 23, 2026  
**Status:** Ready for Deployment

---

## ⚡ QUICK ACTION STEPS

### STEP 1: Upload Backend File (2 minutes)

**Upload this file:**
```
Local:  c:\projects\rlmss\mobile\get_arpl_hierarchy.php
Server: /public_html/mobile/get_arpl_hierarchy.php
```

**Via FileZilla/cPanel/FTP** - Upload and overwrite existing file

---

### STEP 2: Test Backend (30 seconds)

**Open in browser:**
```
https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701
```

**Should see:** JSON with "Bricklayer" trade ✅  
**Should NOT see:** HTML error or HTTP 500 ❌

---

### STEP 3: Test App (1 minute)

**On device:**
1. Open RLMS app
2. Login as ARPL Assessor
3. Click "Bricklaying" class
4. Should see "Select Pathway" screen (NOT blank!)

**✅ APK already installed - just test!**

---

### STEP 4: Monitor Logs (optional)

**In terminal:**
```cmd
adb logcat -c
adb logcat | findstr "ARPL 🔍 📡 📦 ✅ ❌"
```

**Look for:**
- 🔍 API URL
- 📡 Status 200
- ✅ JSON decoded
- 📚 Pathways found

---

## 🎯 WHAT WAS FIXED

**The Bug:**
- Backend looked for `connection.php` in wrong directory
- Returned error HTML instead of JSON
- App couldn't parse HTML → blank screen

**The Fix:**
- Changed: `require_once __DIR__ . '/../connection.php';`
- To: `require_once 'connection.php';`
- Now matches working file pattern

---

## 📋 SUCCESS CRITERIA

- [ ] Backend returns JSON (not error)
- [ ] App shows "Select Pathway" screen
- [ ] No blank gray screen
- [ ] Can click ARPL card

---

## 🐛 IF ISSUES

### Backend still errors?
- Check file uploaded correctly
- Verify permissions (644)
- Check PHP error log

### App still blank?
```cmd
# Reinstall completely:
adb uninstall com.rlms.rlmss
adb install build\app\outputs\flutter-apk\app-release.apk
```

---

## 📄 FULL DOCUMENTATION

- **ARPL_BLANK_SCREEN_FIX_COMPLETE.md** - Complete summary
- **UPLOAD_FIXED_BACKEND_NOW.md** - Detailed upload guide
- **BLANK_SCREEN_FIX_TESTING_GUIDE.md** - Full testing guide

---

## ✅ CHECKLIST

Before testing:
- [ ] Backend uploaded to `/public_html/mobile/`
- [ ] API tested in browser returns JSON
- [ ] Device connected (adb devices)
- [ ] App installed (already done ✅)

During testing:
- [ ] Login successful
- [ ] Click Bricklaying class
- [ ] Observe screen (not blank)
- [ ] Check logs (optional)

After success:
- [ ] Report: "Fixed! ✅"
- [ ] Test other classes
- [ ] Test full workflow

---

**⏱️ TOTAL TIME: ~5 MINUTES**

**🚀 START WITH STEP 1: UPLOAD BACKEND FILE NOW!**
