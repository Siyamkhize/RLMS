# 🚨 URGENT: Bricklayer Toolkit 400 Error Diagnostic Instructions

## Current Status
- **Issue**: Getting 400 error when opening Complete Toolkit
- **Learner**: Anele Cele (ID: 9201151070088, LearnerID: 11701)
- **Class**: 797
- **OFO**: 641201 (Bricklayer)

## Diagnostic Scripts Created
We've created 2 diagnostic scripts to identify the exact error:

### 1. **test_toolkit_simple.php** (Recommended - Quick Test)
- **Purpose**: Fast, simple diagnostic with clear output
- **Best for**: Quick error identification

### 2. **diagnose_bricklayer_toolkit.php** (Comprehensive)
- **Purpose**: Detailed HTML report of all components
- **Best for**: Deep dive into database structure and queries

---

## 📋 STEP-BY-STEP INSTRUCTIONS

### STEP 1: Upload Diagnostic Scripts to Server

Upload these 2 files to your online server:

```
LOCAL PATH                                    → UPLOAD TO SERVER
-------------------------------------------------------------
c:\projects\rlmss\mobile\test_toolkit_simple.php
  → https://rlms.rlms.co.za/mobile/test_toolkit_simple.php

c:\projects\rlmss\mobile\diagnose_bricklayer_toolkit.php
  → https://rlms.rlms.co.za/mobile/diagnose_bricklayer_toolkit.php
```

**How to Upload:**
- Use FileZilla, cPanel File Manager, or your FTP client
- Upload to the `/mobile/` directory on your server
- Ensure files have `.php` extension

---

### STEP 2: Run Simple Test (Recommended First)

**Open in Browser:**
```
https://rlms.rlms.co.za/mobile/test_toolkit_simple.php
```

**What to Look For:**

✅ **If ALL tests pass:**
```
=== SIMPLE TOOLKIT TEST ===
1. Testing connection.php...
   SUCCESS: Connected to database

2. Test Parameters:
   LearnerID: 11701
   ClassID: 797

3. Testing learner query...
   SUCCESS: Found learner Anele Cele

4. Testing class query...
   SUCCESS: Found class [ClassName]

5. Checking critical tables...
   OK: arplappxb_bricklaying_activities exists
   OK: arplappxb_activity_ratings exists
   OK: arpl_competency_scale exists

6. Testing actual endpoint call...
   HTTP Status: 200
   SUCCESS: Endpoint working!
```

❌ **If you see errors:**
- Copy the ENTIRE output
- Send it back to me
- I'll identify and fix the exact issue

---

### STEP 3: Run Comprehensive Diagnostic (If Needed)

**Open in Browser:**
```
https://rlms.rlms.co.za/mobile/diagnose_bricklayer_toolkit.php
```

**What You'll See:**
- Beautiful HTML report with color coding
- ✅ Green sections = Working
- ❌ Red sections = Problems
- ⚠️ Yellow sections = Warnings

**Key Sections to Check:**
1. **TEST 1**: Connection File Check
2. **TEST 3**: Learner Details Query
3. **TEST 5**: Appendix B Tables Check
4. **TEST 12**: POST Request Simulation ← **MOST IMPORTANT**

---

### STEP 4: Verify File Upload (Important!)

Sometimes files don't upload correctly or get cached. Verify:

**Check File Exists:**
```
https://rlms.rlms.co.za/mobile/get_bricklayer_toolkit_data.php
```

**Should see:** Either JSON error or actual response (not 404)

**If you get 404 error:**
- File didn't upload correctly
- Re-upload the file
- Clear any server cache
- Check file permissions (should be 644)

---

## 🔍 COMMON ISSUES AND SOLUTIONS

### Issue 1: "connection.php not found"
**Solution:**
- Ensure `connection.php` exists in `/mobile/` directory
- Check file has correct database credentials

### Issue 2: "Database connection failed"
**Solution:**
- Check database credentials in `connection.php`
- Verify database server is running
- Check database user has correct permissions

### Issue 3: "Table does not exist"
**Solution:**
- Tables need to be created on ONLINE database
- I'll provide SQL scripts to create missing tables

### Issue 4: "HTTP Status: 400"
**Solution:**
- Look at the error message in the response
- Send me the exact error message
- This tells us the specific problem

---

## 📸 WHAT TO SEND BACK TO ME

Please send me **ONE** of the following:

### Option A: Simple Test Output (Preferred)
1. Open: `https://rlms.rlms.co.za/mobile/test_toolkit_simple.php`
2. Copy **ENTIRE** text output
3. Paste it in your response

### Option B: Comprehensive Report
1. Open: `https://rlms.rlms.co.za/mobile/diagnose_bricklayer_toolkit.php`
2. Take screenshots of:
   - TEST 5 (Appendix B Tables)
   - TEST 12 (POST Request Simulation) ← **MOST IMPORTANT**
3. Send screenshots

### Option C: Direct Error Message
If you can see the error in the app logs, send:
- The exact error message
- Stack trace if available

---

## ⚡ QUICK TROUBLESHOOTING

### If Files Won't Upload
1. Check FTP/cPanel connection
2. Verify you're in correct directory (`/mobile/`)
3. Try uploading one file at a time
4. Check file permissions after upload

### If Browser Shows Blank Page
1. Check PHP errors are enabled
2. View page source (Ctrl+U) to see hidden errors
3. Check server error logs

### If You Get "Permission Denied"
1. File permissions should be: `644`
2. Directory permissions should be: `755`
3. Use FTP client to fix permissions

---

## 🎯 NEXT STEPS AFTER DIAGNOSTIC

Once you send me the diagnostic output, I will:

1. ✅ **Identify the exact error** causing the 400 response
2. ✅ **Fix the issue** in the PHP endpoint
3. ✅ **Provide SQL scripts** if tables are missing
4. ✅ **Give you corrected file** to upload
5. ✅ **Test again** until it works

---

## 📞 NEED HELP?

If you're stuck at any step:
1. Tell me which step you're on
2. Copy any error messages you see
3. Describe what's happening

I'll guide you through it!

---

## 🔥 PRIORITY ORDER

Run diagnostics in this order:

1. **FIRST**: Upload `test_toolkit_simple.php` and run it
2. **THEN**: Send me the output
3. **WAIT**: For my fix based on the output
4. **OPTIONAL**: Run `diagnose_bricklayer_toolkit.php` if I need more details

---

**Created:** 2026-07-15  
**Status:** Ready for Testing  
**Files to Upload:** 2 diagnostic scripts  
**Expected Time:** 5-10 minutes to run diagnostics
