# UPLOAD NOW - Quick Checklist

## FILES TO UPLOAD (Priority Order)

### 🔥 CRITICAL - Upload These First

**1. OFO Number Fix (View Complete Toolkit)** ⚠️ CORRECTED
```
File: mobile/get_class_trade_info.php
Why: Fixes "OFO Number: Not Set" in View Complete Toolkit route
Status: CORRECTED - now queries sites.Project_pathway (not class.Project_pathway)
Upload to: /home/rlmsrlmsco/public_html/mobile/
NOTE: First upload had schema error - this version is fixed!
```

**2. Activities Loading Fix (Assessor Review)**
```
File: mobile/get_arpl_competency_data.php
Why: Fixes "activities not loading" in Assessor Review - currently hardcoded for Electrician only
Upload to: /home/rlmsrlmsco/public_html/mobile/
```

**3. Save Endpoints (Fix 404 Errors)**
```
File: mobile/save_arpl_appendix_b.php
File: mobile/save_arpl_appendix_d.php  
File: mobile/save_arpl_appendix_e.php
Why: Currently missing on server - causing 404 errors when saving
Upload to: /home/rlmsrlmsco/public_html/mobile/
```

### ⚡ IMPORTANT - Upload These Next

**3. Additional Save Endpoints**
```
File: mobile/save_arpl_appendix_f.php
File: mobile/save_arpl_criteria.php
Why: Needed for complete workflow
Upload to: /home/rlmsrlmsco/public_html/mobile/
```

### 📊 OPTIONAL - Test Scripts

**4. Diagnostic Scripts**
```
File: mobile/test_get_arpl_competency_fixed.php
Why: Test that activities endpoint works
Upload to: /home/rlmsrlmsco/public_html/mobile/
```

---

## QUICK UPLOAD STEPS

### Method 1: cPanel File Manager (Easiest)

1. Login to cPanel
2. Open **File Manager**
3. Navigate to: `public_html/mobile/`
4. Click **Upload**
5. Select files:
   - `get_class_trade_info.php` ← NEW - Fix "OFO Not Set"
   - `get_arpl_competency_data.php`
   - `save_arpl_appendix_b.php`
   - `save_arpl_appendix_d.php`
   - `save_arpl_appendix_e.php`
   - `save_arpl_appendix_f.php`
   - `save_arpl_criteria.php`
6. Wait for upload to complete
7. Overwrite existing files if prompted

### Method 2: FTP Client

1. Connect to: `rlms.rlms.co.za`
2. Navigate to: `/public_html/mobile/`
3. Upload files (drag & drop)
4. Overwrite existing files

---

## VERIFY UPLOAD WORKED

### Test 0: OFO Endpoint (NEW)
```
Open in browser:
https://rlms.rlms.co.za/mobile/get_class_trade_info.php?classID=797

✅ SUCCESS = Shows JSON with "ofo_number":"641201"
❌ FAILURE = Shows "404 Not Found"
```

### Test 1: Activities Endpoint
```
Open in browser:
https://rlms.rlms.co.za/mobile/test_get_arpl_competency_fixed.php

✅ SUCCESS = Shows "Activities Loaded" with count > 0
❌ FAILURE = Shows 0 activities or error
```

### Test 2: Save Endpoints Exist
```
Open in browser (each should NOT be 404):
https://rlms.rlms.co.za/mobile/save_arpl_appendix_b.php
https://rlms.rlms.co.za/mobile/save_arpl_appendix_d.php
https://rlms.rlms.co.za/mobile/save_arpl_appendix_e.php

✅ SUCCESS = Returns PHP error or JSON (not 404)
❌ FAILURE = Shows "404 Not Found"
```

---

## TEST IN APP AFTER UPLOAD

### Test Activities Loading

**Route 1: Assessor Review (D,E,F)**
1. Menu → **Assessor Review (D,E,F)**
2. Select: Anele Cele
3. Check Appendix B tab
4. **EXPECTED**: 
   - Shows "OFO: 641201" ✅ (already working)
   - Shows list of activities ✅ (NEW - should work after upload)

**Route 2: View Complete Toolkit**
1. Menu → **View Complete Toolkit**
2. Select: Anele Cele
3. **CHECK**: OFO Number shows "641201" (NOT "Not Set") ✅ (NEW - works after upload)
4. Open Complete Toolkit
5. **EXPECTED**: 
   - Activities load ✅

---

### Test Save Functionality

**After activities load, try saving:**

**Route 1: Assessor Review**
1. Rate some activities in Appendix B
2. Click **Save** button
3. **EXPECTED**: 
   - ❌ OLD: "404 Not Found"
   - ✅ NEW: "Appendix B saved successfully"

**Route 2: View Complete Toolkit**
1. Make edits in toolkit
2. Click **Save** button
3. **EXPECTED**:
   - ❌ OLD: "404 Not Found"
   - ✅ NEW: "Saved successfully"

---

## IF SOMETHING DOESN'T WORK

### Activities Still Don't Load

**Check 1**: Did endpoint upload correctly?
```
Visit: https://rlms.rlms.co.za/mobile/get_arpl_competency_data.php?learnerID=11701&ofo_number=641201
Should return JSON (not 404)
```

**Check 2**: Is database empty?
```
Run SQL:
SELECT COUNT(*) FROM arplappxb_bricklaying_activities WHERE ofo_number = '641201';

If 0 = Database needs activities populated
If > 0 = Activities exist, endpoint issue
```

---

### Save Still Returns 404

**Check 1**: Did files upload to correct location?
```
Location must be: /home/rlmsrlmsco/public_html/mobile/save_arpl_appendix_b.php
NOT: /home/rlmsrlmsco/public_html/save_arpl_appendix_b.php
NOT: /home/rlmsrlmsco/mobile/save_arpl_appendix_b.php
```

**Check 2**: File permissions
```
Should be: 644 or 755
Check in cPanel File Manager → Right click file → Permissions
```

**Check 3**: Clear browser cache
```
Hard refresh: Ctrl+F5 (Windows) or Cmd+Shift+R (Mac)
Or test in incognito/private window
```

---

## SUMMARY

### What Gets Fixed

✅ **Activities not loading** → Fixed by `get_arpl_competency_data.php`
- Was hardcoded for Electrician only
- Now dynamically queries correct table based on OFO

✅ **404 save errors** → Fixed by uploading save endpoints
- Files exist locally but not on server
- Simple upload fixes the issue

### No Rebuild Needed

These are **server-side only** fixes:
- ✅ No app rebuild required
- ✅ Changes take effect immediately
- ✅ Just upload and test

---

## ESTIMATED TIME

- **Upload files**: 2-3 minutes
- **Test endpoints**: 2 minutes
- **Test in app**: 5 minutes
- **Total**: ~10 minutes

---

## CONTACT AFTER UPLOAD

**If everything works**:
✅ Reply: "Uploaded - activities loading and save working!"

**If issues**:
❌ Share:
1. Which test failed (activities or save)
2. Error message from browser/app
3. URL you're testing

---

**Ready to upload?** Start with the 5 critical files and test!

Files to upload:
1. ✅ `get_class_trade_info.php` ← NEW - Fix "OFO Not Set"
2. ✅ `get_arpl_competency_data.php`
3. ✅ `save_arpl_appendix_b.php`
4. ✅ `save_arpl_appendix_d.php`
5. ✅ `save_arpl_appendix_e.php`
6. ✅ `save_arpl_appendix_f.php`
7. ✅ `save_arpl_criteria.php`
