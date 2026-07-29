# 📤 ARPL Upload Checklist - All Endpoints

**Date:** July 15, 2026  
**Purpose:** Complete checklist for uploading ALL ARPL save endpoints to server

---

## 🚨 PRIORITY FILES (Upload These First)

### ❌ HIGH PRIORITY - Currently Causing 404 Errors

- [ ] **save_arpl_appendix_b.php** - Appendix B ratings save
  ```
  Local:  c:\projects\rlmss\mobile\save_arpl_appendix_b.php
  Server: /home/rlmsrlmsco/public_html/mobile/save_arpl_appendix_b.php
  Used by: ARPL Assessor → Appendix B tab
  Status: USER BLOCKED - 404 ERROR
  ```

- [ ] **save_arpl_toolkit_edits.php** - Complete toolkit save
  ```
  Local:  c:\projects\rlmss\mobile\save_arpl_toolkit_edits.php
  Server: /home/rlmsrlmsco/public_html/mobile/save_arpl_toolkit_edits.php
  Used by: Complete Toolkit Viewer → Save All
  Status: READY - Needs upload
  ```

---

## ✅ VERIFICATION FILES (Upload These Second)

### Test Scripts - For Verifying Endpoints Work

- [ ] **test_appendix_b_save.php**
  ```
  Local:  c:\projects\rlmss\mobile\test_appendix_b_save.php
  Server: /home/rlmsrlmsco/public_html/mobile/test_appendix_b_save.php
  URL: https://rlms.rlms.co.za/mobile/test_appendix_b_save.php
  ```

- [ ] **test_save_toolkit_edits.php**
  ```
  Local:  c:\projects\rlmss\mobile\test_save_toolkit_edits.php
  Server: /home/rlmsrlmsco/public_html/mobile/test_save_toolkit_edits.php
  URL: https://rlms.rlms.co.za/mobile/test_save_toolkit_edits.php
  ```

---

## 🔍 OTHER ARPL ENDPOINTS (Check If Needed)

### May Also Need Upload

Based on config.dart, these endpoints are also referenced:

- [ ] **save_arpl_appendix_d.php** - Appendix D save
  ```
  Config: saveArplAppendixDUrl
  Check: https://rlms.rlms.co.za/mobile/save_arpl_appendix_d.php
  ```

- [ ] **save_arpl_appendix_e.php** - Appendix E save
  ```
  Config: saveArplAppendixEUrl
  Check: https://rlms.rlms.co.za/mobile/save_arpl_appendix_e.php
  ```

- [ ] **save_arpl_appendix_f.php** - Appendix F save
  ```
  Config: saveArplAppendixFUrl
  Check: https://rlms.rlms.co.za/mobile/save_arpl_appendix_f.php
  Status: Reported as working
  ```

- [ ] **get_arpl_appendix_d.php** - Appendix D load
  ```
  Config: getArplAppendixDUrl
  ```

- [ ] **get_arpl_appendix_e.php** - Appendix E load
  ```
  Config: getArplAppendixEUrl
  ```

---

## 📋 Upload Methods

### Option 1: FTP/SFTP (Recommended)
Use FileZilla, WinSCP, or similar:
```
Host: rlms.rlms.co.za
Port: 21 (FTP) or 22 (SFTP)
Path: /home/rlmsrlmsco/public_html/mobile/
```

### Option 2: cPanel File Manager
1. Login to cPanel
2. Open File Manager
3. Navigate to `public_html/mobile/`
4. Click "Upload"
5. Select files

### Option 3: SSH/Command Line
```bash
scp mobile/*.php user@rlms.rlms.co.za:/home/rlmsrlmsco/public_html/mobile/
```

---

## ✅ Verification Steps

### For Each Uploaded File:

1. **Check file exists (should return JSON, not 404)**
   ```
   https://rlms.rlms.co.za/mobile/[filename].php
   ```

2. **Run corresponding test script (if exists)**
   ```
   https://rlms.rlms.co.za/mobile/test_[filename].php
   ```

3. **Test in app**
   - Login as ARPL Assessor
   - Perform the action
   - Verify success message (not 404)

---

## 🧪 Quick Test Commands

### Test All Endpoints At Once

Visit these URLs in your browser:

```
# Appendix B
https://rlms.rlms.co.za/mobile/save_arpl_appendix_b.php
https://rlms.rlms.co.za/mobile/test_appendix_b_save.php

# Toolkit Edits
https://rlms.rlms.co.za/mobile/save_arpl_toolkit_edits.php
https://rlms.rlms.co.za/mobile/test_save_toolkit_edits.php

# Other Appendices
https://rlms.rlms.co.za/mobile/save_arpl_appendix_d.php
https://rlms.rlms.co.za/mobile/save_arpl_appendix_e.php
https://rlms.rlms.co.za/mobile/save_arpl_appendix_f.php

# Load Endpoints
https://rlms.rlms.co.za/mobile/get_arpl_appendix_d.php
https://rlms.rlms.co.za/mobile/get_arpl_appendix_e.php
```

**Expected:** JSON response (even if error) - NOT 404

---

## 📊 Current Status Matrix

| Endpoint | Local Exists | Uploaded | Tested | Status |
|----------|-------------|----------|--------|--------|
| save_arpl_appendix_b.php | ✅ Yes | ❌ No | ⏳ Pending | 🚨 BLOCKING |
| save_arpl_toolkit_edits.php | ✅ Yes | ❓ Unknown | ⏳ Pending | 🚨 PRIORITY |
| save_arpl_appendix_d.php | ❓ Unknown | ❓ Unknown | ❓ Unknown | ⚠️ CHECK |
| save_arpl_appendix_e.php | ✅ Yes | ❓ Unknown | ❓ Unknown | ⚠️ CHECK |
| save_arpl_appendix_f.php | ✅ Yes | ✅ Yes | ✅ Working | ✅ GOOD |
| get_arpl_appendix_d.php | ❓ Unknown | ❓ Unknown | ❓ Unknown | ⚠️ CHECK |
| get_arpl_appendix_e.php | ✅ Yes | ❓ Unknown | ❓ Unknown | ⚠️ CHECK |

---

## 🎯 Success Criteria

After uploading ALL files:

- ✅ No 404 errors when saving any appendix
- ✅ Appendix B saves work (currently broken)
- ✅ Complete toolkit saves work
- ✅ All test scripts return success
- ✅ Works for all trades (bricklayer, electrician, plumber)

---

## 📝 Upload Log Template

Use this to track your uploads:

```
Date: _____________
Uploaded by: _____________

Files Uploaded:
[ ] save_arpl_appendix_b.php - Time: _____ Status: _____
[ ] save_arpl_toolkit_edits.php - Time: _____ Status: _____
[ ] test_appendix_b_save.php - Time: _____ Status: _____
[ ] test_save_toolkit_edits.php - Time: _____ Status: _____

Verification Results:
[ ] Appendix B - 404 Error: YES / NO
[ ] Appendix B - Test Script: PASS / FAIL
[ ] Appendix B - App Test: PASS / FAIL
[ ] Complete Toolkit - 404 Error: YES / NO
[ ] Complete Toolkit - Test Script: PASS / FAIL
[ ] Complete Toolkit - App Test: PASS / FAIL

Notes:
_________________________________
_________________________________
```

---

## 🚨 IMMEDIATE NEXT STEP

**RIGHT NOW - Upload this file:**

```
c:\projects\rlmss\mobile\save_arpl_appendix_b.php
```

This is causing the 404 error the user is experiencing. Once uploaded:

1. Test URL: `https://rlms.rlms.co.za/mobile/save_arpl_appendix_b.php`
2. Run test: `https://rlms.rlms.co.za/mobile/test_appendix_b_save.php`
3. Try saving Appendix B in app

---

**Generated:** July 15, 2026 09:40:00  
**Priority:** URGENT - User blocked by 404 error
