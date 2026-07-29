# ARPL PDF Generator - Quick Fix & Troubleshooting

**Problem**: Files were deployed to wrong XAMPP path. Wrapper was using absolute URL redirect.

**Solution**: 
1. Wrapper now uses relative path redirect
2. All files confirmed at correct source location

---

## ⚡ Quick Test URLs

### 1. Diagnostic Tool (No learnerID needed)
```
http://localhost:8080/web/test_arpl_setup.php
```
This will tell you if database, files, and learner data are all OK.

### 2. Full PDF Generation (Requires learnerID)
```
http://localhost:8080/web/generate_pdf.php?learnerID=16389&ofo_code=671101
```
This generates the complete 30+ page ARPL portfolio.

### 3. Direct Generator (Full parameters)
```
http://localhost:8080/web/arpl_pdf.php?learnerID=16389&classID=782&ofo_code=671101
```
Bypasses wrapper, goes straight to PDF generation.

---

## 🔍 What Was Fixed

### Before (Broken)
```javascript
// wrapper used absolute URL
const url = `http://localhost:8080/web/arpl_pdf.php?learnerID=${learnerID}&classID=${classID}&ofo_code=${ofo_code}`;
```

### After (Fixed)
```javascript
// wrapper uses relative path
const url = `arpl_pdf.php?learnerID=${learnerID}&classID=${classID}&ofo_code=${ofo_code}`;
```

**Why this matters**: Relative paths are more reliable and don't depend on hardcoded URLs.

---

## 🛠️ Troubleshooting

### Issue 1: "Connection file not found"
**Cause**: Connection path is incorrect

**Check**: 
- Does `C:\projects\rlmss\connection.php` exist?
- Test: `http://localhost:8080/web/test_arpl_setup.php` → Check database connection

**Solution**:
If missing, you need to ensure `connection.php` is in the root directory (`C:\projects\rlmss\`).

---

### Issue 2: Blank page or 500 error
**Cause**: Could be missing learner data or parameter issue

**Check**:
1. Run diagnostic: `http://localhost:8080/web/test_arpl_setup.php`
2. Verify learnerID exists: Look for "Learner 16389 found" message
3. Check console for JavaScript errors (F12)

**Solution**:
Use a learnerID that exists in your database, or update test files with correct ID.

---

### Issue 3: PDF won't generate
**Cause**: Could be session authentication or database issue

**Check**:
1. Are you logged into the system as a facilitator or SDP user?
2. Does your session have `$_SESSION['facilitator_id']` or `$_SESSION['sdp_id']`?
3. Run: `http://localhost:8080/web/test_arpl_setup.php` - Check all tests pass

**Solution**:
Make sure you're logged in with appropriate user role before generating PDF.

---

### Issue 4: "classID=0" or wrong class selected
**Cause**: Learner might not have classID in database

**Check**:
1. Run diagnostic tool
2. Look for: "Class ID: 782" (or whatever value)
3. If blank, learner has no class assigned

**Solution**:
Either:
- Provide classID in URL: `...&classID=782&...`
- Assign learner to a class in the system
- Update learnerdetails table

---

## 📋 File Locations Reference

```
C:\projects\rlmss\
├─ connection.php                      ← Database connection
└─ web\
   ├─ generate_pdf.php                 ← Wrapper/loader page
   ├─ arpl_pdf.php                     ← PDF generator
   ├─ test_arpl_setup.php              ← Diagnostic tool
   ├─ ARPL_PDF_DEPLOYMENT_FIXED.md     ← Full documentation
   └─ ARPL_QUICK_FIX_GUIDE.md          ← This file
```

**Web Server Base**: `http://localhost:8080/web/`

---

## ✅ Verification Checklist

Before testing, verify these files exist:

- [ ] `C:\projects\rlmss\connection.php` exists
- [ ] `C:\projects\rlmss\web\generate_pdf.php` exists
- [ ] `C:\projects\rlmss\web\arpl_pdf.php` exists
- [ ] `C:\projects\rlmss\web\test_arpl_setup.php` exists

Run this to check:
```powershell
Test-Path "C:\projects\rlmss\connection.php"
Test-Path "C:\projects\rlmss\web\generate_pdf.php"
Test-Path "C:\projects\rlmss\web\arpl_pdf.php"
Test-Path "C:\projects\rlmss\web\test_arpl_setup.php"
```

All should return `True`.

---

## 🎯 Expected Results

### Diagnostic Tool Should Show
```
✅ Database connected successfully
✅ generate_pdf.php exists
✅ connection.php exists
✅ Learner found: John Doe
   Learner ID: 16389
   Class ID: 782
✅ Class found: Class A
```

### PDF Generation Should Show
```
1. Loading spinner (1-2 seconds)
2. Page redirects silently
3. 30+ page ARPL portfolio displays
4. Learner name visible
5. All 11 appendices visible
6. Trade: Electrician (671101)
```

---

## 📞 Quick Help

| Symptom | Test First | Most Likely Cause |
|---------|-----------|-------------------|
| Blank page | Diagnostic tool | Missing files or connection |
| 500 error | Check console (F12) | Session not authenticated |
| Wrong learner | Check URL parameters | Typo in learnerID |
| Missing class | Diagnostic tool | Learner not assigned to class |
| Redirect loop | Browser console | Session issue |

---

## 🚀 Test Now!

```
http://localhost:8080/web/test_arpl_setup.php
```

Then if diagnostic passes:

```
http://localhost:8080/web/generate_pdf.php?learnerID=16389&ofo_code=671101
```

---

**Status**: ✅ Ready to test
**Last Updated**: July 11, 2026
**All Fixes Applied**: Yes

