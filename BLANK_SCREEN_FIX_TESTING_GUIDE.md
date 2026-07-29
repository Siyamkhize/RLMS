# 🧪 BLANK SCREEN FIX - TESTING GUIDE

**Date:** July 23, 2026  
**Status:** ✅ APK Installed - Ready for Testing  
**Fix Applied:** Connection.php path corrected in backend

---

## 🎯 WHAT WAS FIXED

### Root Cause:
- Backend `get_arpl_hierarchy.php` was looking for `connection.php` in wrong directory
- Used `require_once __DIR__ . '/../connection.php'` (parent directory)
- But connection.php exists in `/public_html/mobile/` (same directory)

### Solution:
- Changed to `require_once 'connection.php'` (same directory)
- Matches working pattern from `get_class_trade_info.php`
- Backend now loads database connection correctly

### Changes Made:
1. ✅ **Backend:** Fixed connection.php include path
2. ✅ **Frontend:** Added extensive debug logging
3. ✅ **APK:** Rebuilt with both fixes (45.9 MB)
4. ✅ **Device:** Installed successfully

---

## 📋 TESTING STEPS

### STEP 1: Upload Fixed Backend (MUST DO FIRST!)

**Upload this file to server:**
- **Local:** `c:\projects\rlmss\mobile\get_arpl_hierarchy.php`
- **Server:** `/public_html/mobile/get_arpl_hierarchy.php`

**Test endpoint in browser:**
```
https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701
```

**Expected:** Valid JSON with trade "Bricklayer"  
**NOT Expected:** HTML error, PHP warnings, HTTP 500

**⚠️ DO NOT PROCEED TO APP TESTING UNTIL BACKEND IS UPLOADED AND VERIFIED!**

---

### STEP 2: Test on Device

#### 2.1 Prepare Device Logs:
```cmd
adb logcat -c
adb logcat | findstr "ARPL 🔍 📡 📦 ✅ ❌"
```
Leave this running in a separate terminal window.

#### 2.2 Open App and Navigate:
1. **Open** RLMS app on device
2. **Login** as ARPL Assessor
   - Username: (ARPL Assessor username)
   - User ID: 6
3. **Click** on "Bricklaying" class
   - Class ID: 797
   - Learner ID: 11701

#### 2.3 Expected Behavior:
- ✅ **Loading indicator** appears briefly
- ✅ **AppBar** shows "Bricklayer Portfolio" (already working)
- ✅ **Screen** shows "Select Pathway" with "ARPL" option
- ✅ **Card** is clickable and navigates to next step

#### 2.4 What You Should NOT See:
- ❌ **Blank gray screen**
- ❌ **Loading spinner forever**
- ❌ **Error message** in red text
- ❌ **App crash** or freeze

---

### STEP 3: Analyze Debug Logs

#### Look for these log entries:
```
🔍 ARPL API URL: https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701
📡 ARPL Response Status: 200
📦 ARPL Response Body Length: XXXX
✅ ARPL JSON Decoded Successfully
🔑 ARPL Top-level keys: [pathways, _debug]
📚 Pathways found: [ARPL]
✅ arplData set successfully
```

#### If you see error logs:
```
❌ HTTP Error: 500
❌ API returned error: [error message]
❌ Exception in fetchArplData: [exception]
```

---

## 🐛 TROUBLESHOOTING

### Issue 1: Still Shows Blank Screen

#### Possible Causes:
1. **Backend not uploaded** - API still returning old error
2. **App cached old error** - needs data clear
3. **Network issue** - no connectivity
4. **Wrong URL** - check config.dart

#### Solutions:
```cmd
# 1. Verify backend was uploaded and works:
# Open in browser: https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701
# Should return valid JSON

# 2. Clear app data and cache:
adb shell pm clear com.rlms.rlmss

# 3. Reinstall app completely:
adb uninstall com.rlms.rlmss
adb install build\app\outputs\flutter-apk\app-release.apk

# 4. Check device internet:
adb shell ping -c 3 rlms.rlms.co.za
```

---

### Issue 2: API Returns Error in Browser

#### If browser test shows error:

**Error:** "Failed to open stream: No such file or directory"
- **Solution:** Backend file not uploaded or in wrong location
- **Action:** Re-upload `get_arpl_hierarchy.php` to `/public_html/mobile/`

**Error:** "Database connection failed"
- **Solution:** Check connection.php exists in mobile folder
- **Action:** Verify connection.php is present and readable

**Error:** "No learner found"
- **Solution:** Wrong learner ID
- **Action:** Use test learner ID: 11701

**Error:** HTTP 500
- **Solution:** PHP error in backend
- **Action:** Check PHP error log in cPanel

---

### Issue 3: App Shows Error Message

#### If app displays error in red text:

**"Invalid learner_id provided"**
- App sent empty or invalid learner ID
- Check navigation parameters

**"Failed to load data: [exception]"**
- Network error or JSON parsing failed
- Check device logs for full exception
- Verify API returns valid JSON

**"Server error: 500"**
- Backend PHP error
- Backend not uploaded yet
- Check API endpoint in browser

---

## 📊 WHAT TO REPORT

### If Fix Works ✅:
Report:
- "Blank screen fixed! ✅"
- "Now shows: Select Pathway screen"
- "Trade name displayed: Bricklayer"

### If Fix Doesn't Work ❌:
Report:
1. **Backend Test Result:**
   - URL: https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701
   - Response: [JSON/Error/HTTP code]

2. **App Behavior:**
   - Blank screen / Error message / Crash / Other

3. **Device Logs:**
   - Copy relevant log entries with emojis (🔍 📡 ✅ ❌)
   - Include any error messages

4. **Steps Taken:**
   - Backend uploaded? Yes/No
   - App reinstalled? Yes/No
   - Data cleared? Yes/No

---

## 🔍 EXPECTED DATA FLOW

### Backend Response Structure:
```json
{
  "pathways": {
    "ARPL": {
      "qualifications": {
        "Bricklayer": {
          "theory_papers": {
            "Paper 1": {
              "paper_id": 1,
              "questions": [...]
            }
          },
          "practical_papers": {
            "Paper 2": {
              "paper_id": 2,
              "questions": [...]
            }
          }
        }
      }
    }
  },
  "_debug": [
    "Found learner: {...}",
    "From arpl_trades table - Trade: Bricklayer, OFO: 641201",
    "Total papers loaded: 2"
  ]
}
```

### Frontend Processing:
1. Parse JSON response
2. Extract `pathways` object
3. Show keys as selectable items ("ARPL")
4. Navigate through: Pathway → Trade → Section → Paper → Questions

---

## ✅ SUCCESS CRITERIA

### Backend (API Test):
- ✅ Returns HTTP 200
- ✅ Returns valid JSON (not HTML error)
- ✅ Contains "pathways" key
- ✅ Shows "Bricklayer" trade name
- ✅ Has theory and practical papers

### Frontend (App Test):
- ✅ No blank screen
- ✅ Shows "Select Pathway" title
- ✅ Displays "ARPL" card
- ✅ Card is clickable
- ✅ AppBar shows "Bricklayer Portfolio"
- ✅ No error messages

### Logs (ADB Test):
- ✅ API URL printed
- ✅ HTTP 200 response
- ✅ JSON decoded successfully
- ✅ Pathways found
- ✅ No exceptions or errors

---

## 🚀 NEXT STEPS AFTER SUCCESS

Once blank screen is fixed:

1. **Test Full Workflow:**
   - Select Pathway → Trade → Section → Paper
   - Upload a question via camera
   - Verify upload success

2. **Test with Other Learners:**
   - Try different learner IDs
   - Verify correct trade displayed for each

3. **Verify Data Persistence:**
   - Upload offline, then sync online
   - Check server receives data

4. **Test Other Trades:**
   - Electrician (OFO: 671101)
   - Plumber (OFO: 642601)

---

## 📞 SUPPORT

**If issues persist after following all troubleshooting:**

1. **Capture full logs:**
   ```cmd
   adb logcat > debug_log.txt
   ```

2. **Export backend response:**
   - Copy full JSON from browser test
   - Save as `backend_response.json`

3. **Describe exact behavior:**
   - What you see vs what you expect
   - Step-by-step reproduction steps
   - Any error messages (exact text)

4. **Provide test data:**
   - Learner ID used
   - Class ID used
   - User ID logged in as

---

## 📝 CHECKLIST

Before reporting issues, verify:

- [ ] Backend file uploaded to server
- [ ] API endpoint tested in browser and returns valid JSON
- [ ] App uninstalled and reinstalled (not just updated)
- [ ] Device has internet connectivity
- [ ] Logged in as correct user (ARPL Assessor)
- [ ] Using correct test data (Learner 11701, Class 797)
- [ ] ADB logs captured during test
- [ ] Tried clearing app data (`adb shell pm clear com.rlms.rlmss`)

---

**Ready to test! Start with backend upload, then test app.** 🚀
