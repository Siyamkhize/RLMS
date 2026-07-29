# Fix "OFO Number: Not Set" Issue - Quick Guide

## PROBLEM

When you go to **View Complete Toolkit** and select a learner, it shows:
```
OFO Number: Not Set
```

## ROOT CAUSE ✅ IDENTIFIED

The file `mobile/get_class_trade_info.php` is **MISSING from the ONLINE server**.

- The code exists **LOCALLY** ✅
- The code is correct ✅
- The app calls it when you select a learner ✅
- But it returns **404** because the file was never uploaded ❌

## SOLUTION

Upload **ONE file** to fix this issue.

---

## UPLOAD THIS FILE

```
File: mobile/get_class_trade_info.php
From: c:\projects\rlmss\mobile\get_class_trade_info.php
To: https://rlms.rlms.co.za/mobile/get_class_trade_info.php
```

### How to Upload

**Option 1: cPanel File Manager**
1. Login to cPanel
2. File Manager → `public_html/mobile/`
3. Upload → Select `get_class_trade_info.php`
4. Done!

**Option 2: FTP**
1. Connect to `rlms.rlms.co.za`
2. Navigate to `/public_html/mobile/`
3. Upload `get_class_trade_info.php`
4. Done!

---

## TEST AFTER UPLOAD

### Browser Test
```
https://rlms.rlms.co.za/mobile/get_class_trade_info.php?classID=797
```

**Expected**:
```json
{
  "status": "success",
  "classID": 797,
  "trade_name": "Bricklayer",
  "ofo_number": "641201"
}
```

If you see **404 Not Found** = Upload didn't work, try again

---

### App Test

1. Open app
2. Menu → **View Complete Toolkit**
3. Select: **Anele Cele**
4. Check OFO Number field

**BEFORE**:
```
OFO Number: Not Set  ❌
```

**AFTER**:
```
OFO Number: 641201  ✅
```

---

## WHY THIS HAPPENED

Two different routes use two different methods:

### Route 1: Assessor Review (D,E,F) ✅ WORKING
- Uses `mobile/get_arpl_data.php` (already on server)
- Returns OFO with learner data
- That's why this route works

### Route 2: View Complete Toolkit ❌ NOT WORKING
- Uses `mobile/get_class_trade_info.php` (NOT on server)
- Must fetch OFO separately by classID
- File was created but never uploaded
- That's why it shows "Not Set"

---

## COMPLETE UPLOAD LIST (ALL ISSUES)

Since you need to upload files anyway, here's the complete list to fix ALL issues:

### 🔥 CRITICAL FILES TO UPLOAD

1. **Fix "OFO Not Set" (View Complete Toolkit)**
   - `mobile/get_class_trade_info.php` ← YOU ARE HERE

2. **Fix "Activities Not Loaded" (Assessor Review)**
   - `mobile/get_arpl_competency_data.php`

3. **Fix 404 Save Errors (Both Routes)**
   - `mobile/save_arpl_appendix_b.php`
   - `mobile/save_arpl_appendix_d.php`
   - `mobile/save_arpl_appendix_e.php`
   - `mobile/save_arpl_appendix_f.php`
   - `mobile/save_arpl_criteria.php`

**Total**: 7 files to upload

---

## AFTER ALL UPLOADS

### Route 1: Assessor Review (D,E,F)
- ✅ OFO shows correctly (already working)
- ✅ Activities load (works after upload #2)
- ✅ Save works (works after uploads #3)

### Route 2: View Complete Toolkit
- ✅ OFO shows correctly (works after upload #1)
- ✅ Activities load (works after upload #2)
- ✅ Save works (works after uploads #3)

---

## NO APP REBUILD NEEDED

These are **server-side only** fixes:
- Just upload the PHP files
- Changes work immediately
- No need to rebuild or reinstall app

---

## QUICK CHECKLIST

- [ ] Upload `get_class_trade_info.php`
- [ ] Test browser URL shows JSON (not 404)
- [ ] Test app shows OFO number (not "Not Set")
- [ ] Upload remaining 6 files (for activities & save)
- [ ] Test complete workflows

---

**Time Needed**: 5 minutes  
**Complexity**: Simple file upload  
**Risk**: None - these files don't exist on server yet

**Ready to upload?** Start with `get_class_trade_info.php` and test!

