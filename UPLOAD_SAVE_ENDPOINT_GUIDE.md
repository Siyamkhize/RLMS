# 📤 Upload Save Endpoint to Server Guide

## Files to Upload

Upload these files to the server at `rlms.rlms.co.za`:

### 1. **Appendix B Save Endpoint** (REQUIRED - Currently 404)
```
Local:  c:\projects\rlmss\mobile\save_arpl_appendix_b.php
Server: /home/rlmsrlmsco/public_html/mobile/save_arpl_appendix_b.php
```
**Used by:** ARPL Assessor Page → Appendix B tab → Save button

### 2. **Unified Toolkit Save Endpoint** (REQUIRED)
```
Local:  c:\projects\rlmss\mobile\save_arpl_toolkit_edits.php
Server: /home/rlmsrlmsco/public_html/mobile/save_arpl_toolkit_edits.php
```
**Used by:** Complete Toolkit Viewer → Save All Changes

### 3. **Test Scripts** (OPTIONAL - for verification)
```
Local:  c:\projects\rlmss\mobile\test_appendix_b_save.php
Server: /home/rlmsrlmsco/public_html/mobile/test_appendix_b_save.php

Local:  c:\projects\rlmss\mobile\test_save_toolkit_edits.php
Server: /home/rlmsrlmsco/public_html/mobile/test_save_toolkit_edits.php
```

---

## 🔧 What Was Fixed

### **Issue:** 404 Error When Saving Toolkit
The endpoint `mobile/save_arpl_toolkit_edits.php` either:
- Did NOT exist on the server, OR
- Only supported bricklayer-specific tables

### **Solution:** Trade-Agnostic Endpoint
The endpoint now:
1. ✅ **Detects trade from OFO number**
   - `641201` → Bricklayer
   - `671201` → Electrician
   - `671402` → Plumber

2. ✅ **Dynamically constructs table names**
   - Appendix B: `arplappxb_activity_ratings` (shared across all trades)
   - Appendix D: `arpl_appendix_d_{trade}` (e.g., `arpl_appendix_d_bricklayer`)
   - Appendix E: `arplappxe_{trade}ing_activity_ratings` (e.g., `arplappxe_bricklaying_activity_ratings`)

3. ✅ **Transaction-safe saves** (all or nothing with rollback)

4. ✅ **Graceful handling** (checks table existence before saving)

---

## 📋 Upload Steps

### Option A: Using FileZilla/FTP Client
1. Connect to `rlms.rlms.co.za` via FTP/SFTP
2. Navigate to `/home/rlmsrlmsco/public_html/mobile/`
3. Upload `save_arpl_toolkit_edits.php` (overwrite if exists)
4. Set file permissions to `644` or `755`

### Option B: Using cPanel File Manager
1. Login to cPanel at `rlms.rlms.co.za/cpanel`
2. Open **File Manager**
3. Navigate to `public_html/mobile/`
4. Click **Upload**
5. Select `save_arpl_toolkit_edits.php`
6. Wait for upload to complete

### Option C: Using SSH/Terminal
```bash
scp c:\projects\rlmss\mobile\save_arpl_toolkit_edits.php user@rlms.rlms.co.za:/home/rlmsrlmsco/public_html/mobile/
```

---

## ✅ Verification Steps

### Step 1: Check Appendix B Endpoint Exists
Visit this URL in your browser:
```
https://rlms.rlms.co.za/mobile/save_arpl_appendix_b.php
```

**Expected Result:**
- ❌ NOT 404 error
- ✅ JSON response like:
  ```json
  {
    "status": "error",
    "message": "Missing required field: learnerID"
  }
  ```

### Step 2: Run Appendix B Test Script
Visit this URL in your browser:
```
https://rlms.rlms.co.za/mobile/test_appendix_b_save.php
```

**Expected Result:**
- ✅ HTTP Status Code: **200**
- ✅ Status: **success**
- ✅ Saved Count: **2 ratings**

### Step 3: Check Unified Toolkit Endpoint
Visit this URL in your browser:
```
https://rlms.rlms.co.za/mobile/save_arpl_toolkit_edits.php
```

**Expected Result:**
- ❌ NOT 404 error
- ✅ JSON response like:
  ```json
  {
    "status": "error",
    "message": "Missing learnerID or classID"
  }
  ```

### Step 4: Test in App - Appendix B
1. Open RLMS app
2. Login as ARPL Assessor (Facilitator ID: 6)
3. Select Class 797 (Bricklayer)
4. Select Learner: Anele Cele
5. Go to **Appendix B** tab
6. Rate 1-2 activities (1-5 scale)
7. Click **Save Appendix B** button

**Expected Result:**
- ✅ Green success message: "Appendix B saved successfully"
- ❌ NOT 404 error

### Step 5: Test in App - Complete Toolkit
1. From same screen, click **Open Complete Toolkit**
2. Edit any field in any appendix
3. Click **Save** (disk icon in top right)

**Expected Result:**
- ✅ Green success message: "✓ Changes saved successfully"
- ❌ NOT 404 error

---

## 🗂️ Table Names Reference

| Trade | OFO Code | Appendix D Table | Appendix E Table |
|-------|----------|------------------|------------------|
| Bricklayer | 641201 | `arpl_appendix_d_bricklayer` | `arplappxe_bricklaying_activity_ratings` |
| Electrician | 671201 | `arpl_appendix_d_electrician` | `arplappxe_electricianing_activity_ratings` |
| Plumber | 671402 | `arpl_appendix_d_plumber` | `arplappxe_plumbering_activity_ratings` |

**Note:** Appendix B uses shared table `arplappxb_activity_ratings` for all trades.

---

## 🔄 What the App Sends

The app sends this JSON payload:
```json
{
  "learnerID": 11701,
  "classID": 797,
  "ofoNumber": "641201",
  "appendixB": [
    {
      "activity_id": 1,
      "rating": 3,
      "comments": "Competent"
    }
  ],
  "appendixD": {
    "activity_1": "Yes",
    "activity_2": "No"
  },
  "appendixE": [
    {
      "activity_id": 1,
      "rating": 4,
      "comments": "Highly Competent"
    }
  ]
}
```

---

## 🐛 Troubleshooting

### Issue: Still Getting 404
**Cause:** File not uploaded or wrong location

**Fix:**
1. Verify file exists: `ls -la /home/rlmsrlmsco/public_html/mobile/save_arpl_toolkit_edits.php`
2. Check file permissions: Should be `644` or `755`
3. Check file size: Should be ~6KB

### Issue: 500 Internal Server Error
**Cause:** PHP syntax error or missing `connection.php`

**Fix:**
1. Check PHP error logs on server
2. Verify `connection.php` exists in same directory
3. Test syntax locally: `php -l save_arpl_toolkit_edits.php`

### Issue: "Unknown table" error
**Cause:** Trade-specific tables don't exist in database

**Fix:**
1. Run this query to check tables:
   ```sql
   SHOW TABLES LIKE 'arpl_appendix%';
   ```
2. Create missing tables using SQL scripts in project root

### Issue: Data saves but doesn't appear
**Cause:** Saved to wrong table or no reload after save

**Fix:**
1. Check response JSON - look at `tables_used` field
2. Verify table names match between load and save endpoints
3. App automatically reloads data after successful save

---

## 📝 Next Steps

1. ✅ Upload `save_arpl_toolkit_edits.php` to server
2. ✅ Verify file exists (Step 1 above)
3. ✅ Run test script (Step 2 above)
4. ✅ Test in app (Step 3 above)
5. ✅ Confirm success message appears
6. ✅ Verify data persists after closing and reopening toolkit

---

## 🎯 Success Criteria

- ❌ No more 404 errors when saving
- ✅ Works for ALL trades (bricklayer, electrician, plumber)
- ✅ Data persists in correct tables
- ✅ Transaction rollback works on errors
- ✅ Green success message appears in app

---

**Generated:** 2026-07-15 09:15:00  
**Status:** Ready to upload
