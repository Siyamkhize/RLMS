# 🚀 UPLOAD THESE 7 FILES TO SERVER NOW

**Server**: https://rlms.rlms.co.za/  
**Folder**: `/public_html/mobile/`

---

## 📁 FILES TO UPLOAD (7 files - ALL CRITICAL)

### 1️⃣ verify_fingerprint_and_get_signature.php
**Local**: `C:\projects\rlmss\mobile\verify_fingerprint_and_get_signature.php`  
**Server**: `/public_html/mobile/verify_fingerprint_and_get_signature.php`

**What it does**: Returns learner signature after fingerprint verification

---

### 2️⃣ get_arpl_toolkit_data.php  
**Local**: `C:\projects\rlmss\mobile\get_arpl_toolkit_data.php`  
**Server**: `/public_html/mobile/get_arpl_toolkit_data.php`

**What it does**: Returns all appendix data with secure signature handling (Appendix A, G, J)

---

### 3️⃣ get_arpl_application.php  
**Local**: `C:\projects\rlmss\mobile\get_arpl_application.php`  
**Server**: `/public_html/mobile/get_arpl_application.php`

**What it does**: Returns Appendix A (Application Form) with secure signature handling

---

### 4️⃣ get_arpl_appendix_f.php  
**Local**: `C:\projects\rlmss\mobile\get_arpl_appendix_f.php`  
**Server**: `/public_html/mobile/get_arpl_appendix_f.php`

**What it does**: Returns Appendix F (Practical Assessment) with secure signature handling

---

### 5️⃣ get_arpl_assessment_agreement.php  
**Local**: `C:\projects\rlmss\mobile\get_arpl_assessment_agreement.php`  
**Server**: `/public_html/mobile/get_arpl_assessment_agreement.php`

**What it does**: Returns Appendix G (Appeals) with secure signature handling

---

### 6️⃣ get_arpl_statement_of_results.php  
**Local**: `C:\projects\rlmss\mobile\get_arpl_statement_of_results.php`  
**Server**: `/public_html/mobile/get_arpl_statement_of_results.php`

**What it does**: Returns Appendix J (Pre-Assessment Agreement) with secure signature handling

---

### 7️⃣ view_pothole_checklists.php
**Local**: `C:\projects\rlmss\mobile\view_pothole_checklists.php`  
**Server**: `/public_html/mobile/view_pothole_checklists.php`

**What it does**: Returns pothole checklist data with secure signature handling

---

## 🔧 UPLOAD METHOD

### Option 1: Using FileZilla/WinSCP
1. Connect to server: `rlms.rlms.co.za`
2. Navigate to `/public_html/mobile/`
3. Drag and drop these 7 files from `C:\projects\rlmss\mobile\`
4. Overwrite existing files when prompted

### Option 2: Using cPanel File Manager
1. Login to cPanel
2. Open File Manager
3. Navigate to `public_html/mobile/`
4. Click Upload
5. Select these 7 files
6. Replace existing files

### Option 3: Using Command Line (if you have SSH)
```bash
# From your local machine (Windows)
cd C:\projects\rlmss\mobile

# Upload all 7 files
scp verify_fingerprint_and_get_signature.php user@rlms.rlms.co.za:/public_html/mobile/
scp get_arpl_toolkit_data.php user@rlms.rlms.co.za:/public_html/mobile/
scp get_arpl_application.php user@rlms.rlms.co.za:/public_html/mobile/
scp get_arpl_appendix_f.php user@rlms.rlms.co.za:/public_html/mobile/
scp get_arpl_assessment_agreement.php user@rlms.rlms.co.za:/public_html/mobile/
scp get_arpl_statement_of_results.php user@rlms.rlms.co.za:/public_html/mobile/
scp view_pothole_checklists.php user@rlms.rlms.co.za:/public_html/mobile/
```

---

## ✅ AFTER UPLOAD - TEST

### Test 1: Fingerprint Verification
1. Open ARPL app on device
2. Go to Appendix J (Pre-Assessment Agreement)
3. Click "Verify Identity with Fingerprint"
4. Scan Anele Cele's fingerprint (LearnerID: 11701)
5. ✅ **Expected**: Signature appears as image
6. ❌ **NOT**: Filename or URL appears

### Test 2: View Appendix A
1. Open saved Appendix A (Application Form)
2. Check candidate signature displays
3. ✅ **Expected**: Image displays correctly

### Test 3: View Appendix F
1. Open saved Appendix F (Practical Assessment)
2. Check candidate and assessor signatures display
3. ✅ **Expected**: Both images display correctly

### Test 4: View Appendix G
1. Open saved Appendix G (Appeals Form)
2. Check candidate and assessor signatures display
3. ✅ **Expected**: Both images display correctly

### Test 5: Check Browser Console
1. Open Chrome DevTools (F12)
2. Go to Network tab
3. Call the API
4. Check response JSON
5. ✅ **Expected**: `"candidate_signature": "data:image/png;base64,..."`
6. ❌ **NOT**: `"candidate_signature": "https://...png"`

---

## 🐛 IF SOMETHING GOES WRONG

### Problem: 500 Error after upload
**Solution**: Check file permissions
```bash
chmod 644 /public_html/mobile/*.php
```

### Problem: Signature still shows filename
**Solution**: Clear PHP cache or restart Apache
```bash
# On server
service apache2 restart
```

### Problem: File not found error
**Solution**: Check signatures folder exists
```bash
# Ensure these folders exist:
/public_html/mobile/signatures/
/public_html/signatures/
```

---

## 📝 QUICK VERIFICATION

After upload, test this URL in browser:
```
https://rlms.rlms.co.za/mobile/verify_fingerprint_and_get_signature.php
```

**Expected**: JSON error (missing parameters) - this confirms file is accessible  
**NOT Expected**: 404 error or PHP syntax error

---

**READY TO UPLOAD** ✅
