# URGENT: Server Fix Instructions

## Problem
The file `mobile/get_bricklayer_toolkit_data.php` on the server has wrong column names causing 400 errors.

## Solution
Edit the file on the server and replace the incorrect column names.

---

## Step-by-Step Fix (Use cPanel File Manager)

### 1. Login to cPanel
- Go to: https://rlms.rlms.co.za:2083 (or your cPanel URL)
- Login with your credentials

### 2. Open File Manager
- Click "File Manager" in cPanel
- Navigate to: `/home/rlmsrlmsco/public_html/mobile/`
- Find file: `get_bricklayer_toolkit_data.php`
- Right-click → **Edit**

### 3. Make These 2 Changes

#### Change #1 (Around line 105-115)
**Find this code:**
```php
SELECT 
    aar.activity_id,
    aar.competency_level,
    aar.rating as rating_score,
    aar.comments,
    aar.assessment_date as rating_date,
    acs.proficiency_level,
    acs.description as scale_description
FROM " . $conn->real_escape_string($appendixB_ratings_table) . " aar
LEFT JOIN arpl_competency_scale acs ON aar.competency_level = acs.level
```

**Replace with:**
```php
SELECT 
    aar.activity_id,
    aar.competency_level,
    aar.rating as rating_score,
    aar.comments,
    aar.assessment_date as rating_date,
    acs.rating_name,
    acs.rating_description
FROM " . $conn->real_escape_string($appendixB_ratings_table) . " aar
LEFT JOIN arpl_competency_scale acs ON aar.competency_level = acs.level
```

**What changed:**
- `acs.proficiency_level` → `acs.rating_name`
- `acs.description as scale_description` → `acs.rating_description`

---

#### Change #2 (Around line 180)
**Find this code:**
```php
$sql_ratings = "SELECT activity_id, competency_level, rating as rating_score, comments, assessment_date as rating_date FROM " . $conn->real_escape_string($appendixE_ratings_table) . " WHERE learnerID = ? AND ofo_number = ?";
```

**No change needed** - This one is already correct from the previous upload.

---

### 4. Save the File
- Click "Save Changes" button (usually top-right)
- Close the editor

### 5. Test the Fix
From your computer, run:
```bash
php test_online_bricklayer_toolkit.php
```

Expected output:
```
HTTP Status Code: 200
✓ API call successful!
```

---

## Quick Reference: What's Wrong vs What's Right

### WRONG Column Names (OLD):
- `acs.proficiency_level` ❌
- `acs.description` ❌

### CORRECT Column Names (NEW):
- `acs.rating_name` ✅
- `acs.rating_description` ✅

---

## After Fix is Deployed

1. The existing APK will work immediately (no rebuild needed)
2. Test on device:
   - Login as facilitator 6
   - View Complete Toolkit
   - Select candidate
   - Click "Open Complete Toolkit"
   - Should load without 400 error

---

## If You Prefer to Upload the Whole File

Instead of editing, you can upload the fixed file:
- Source: `c:\projects\rlmss\mobile\get_bricklayer_toolkit_data.php`
- Destination: `/home/rlmsrlmsco/public_html/mobile/get_bricklayer_toolkit_data.php`
- Method: FTP, cPanel Upload, or File Manager upload

---

## Current Status

- ✅ APK is correct and ready
- ⏳ Server file needs this fix uploaded
- ⏳ After upload, everything will work

---

**Time to fix: 2-3 minutes**
