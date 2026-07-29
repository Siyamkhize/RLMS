# 🚨 URGENT: UPLOAD APPENDIX F BACKEND FILE

**Issue**: 404 error when saving Appendix F  
**Cause**: Backend file `save_appendix_f_data.php` is NOT uploaded to server  
**Status**: ⏳ WAITING FOR FILE UPLOAD

---

## 🎯 FILE TO UPLOAD

**Local Location**:
```
C:\projects\rlmss\mobile\save_appendix_f_data.php
```

**Server Destination**:
```
https://rlms.rlms.co.za/mobile/save_appendix_f_data.php
```

**File Size**: ~9 KB  
**Status**: ✅ Complete and ready for upload

---

## 📤 UPLOAD INSTRUCTIONS

### Step 1: Locate the File
Navigate to:
```
C:\projects\rlmss\mobile\save_appendix_f_data.php
```

### Step 2: Upload via FTP/cPanel
1. Connect to your server (FTP or cPanel File Manager)
2. Navigate to the `mobile` directory
3. Upload `save_appendix_f_data.php`
4. Verify permissions (should be 644 or 755)

### Step 3: Verify Upload
Open in browser:
```
https://rlms.rlms.co.za/mobile/save_appendix_f_data.php
```

**Expected**: You should see a PHP error or JSON response (not 404)

---

## ✅ WHAT THIS FILE DOES

**Purpose**: Saves Appendix F workplace observation ratings

**Accepts**:
- learnerID
- ofoNumber
- workplace_observations array with:
  - activity_id
  - task_observed
  - technical_knowledge (1-3)
  - interpretation_of_instructions (1-3)
  - team_work_attitude (1-3)

**Returns**:
- Status: success/error
- Number of records saved
- Any errors encountered

---

## 🧪 TEST AFTER UPLOAD

### Test 1: Verify File Exists
Open URL in browser:
```
https://rlms.rlms.co.za/mobile/save_appendix_f_data.php
```

**Expected**: NOT 404 (any PHP error or JSON is fine, just not 404)

### Test 2: Test from App
1. Open app on device
2. Go to Appx F
3. Change workplace observation ratings
4. Tap Save
5. **Expected**: "✓ Changes saved successfully" (no 404 error)

---

## 📋 FILES THAT SHOULD BE ON SERVER

After upload, these files should exist on server:

✅ `mobile/get_arpl_toolkit_data.php` - Loads main toolkit (already uploaded)  
✅ `mobile/save_arpl_toolkit_edits.php` - Saves B/D/E (already uploaded)  
✅ `mobile/get_appendix_f_data.php` - Loads F data (already uploaded)  
⏳ `mobile/save_appendix_f_data.php` - **NEEDS TO BE UPLOADED NOW**

---

## 🚨 WHY THIS IS NEEDED

**Current Situation**:
- App displays 15 workplace activities ✅
- User can edit ratings ✅
- User clicks Save...
- App tries to call: `https://rlms.rlms.co.za/mobile/save_appendix_f_data.php`
- **Server returns 404** (file doesn't exist) ❌

**After Upload**:
- App displays 15 workplace activities ✅
- User can edit ratings ✅
- User clicks Save...
- App calls: `https://rlms.rlms.co.za/mobile/save_appendix_f_data.php`
- **Server saves data and returns success** ✅

---

## 📊 VERIFICATION CHECKLIST

After uploading, verify:
- ✅ File exists at correct path
- ✅ File has correct permissions
- ✅ Browser doesn't show 404
- ✅ App save function works
- ✅ Ratings persist after save

---

## 🔧 IF UPLOAD FAILS

### Issue: Permission Denied
**Solution**: Set file permissions to 644 or 755

### Issue: Wrong Directory
**Solution**: Make sure file is in `mobile/` folder, not root

### Issue: File Corrupted
**Solution**: Re-upload the file

### Issue: Still 404 After Upload
**Solution**: 
1. Clear browser cache
2. Check exact URL spelling
3. Verify file actually uploaded (check via FTP/cPanel)
4. Check server Apache/Nginx config allows access to PHP files

---

**Status**: ⏳ WAITING FOR YOU TO UPLOAD THE FILE  
**Action Required**: Upload `mobile/save_appendix_f_data.php` to server NOW

**Once uploaded, the APK will work perfectly!**
