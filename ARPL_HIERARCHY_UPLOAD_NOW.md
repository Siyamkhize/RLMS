# ARPL Hierarchy - Upload and Test Instructions
**Date: July 23, 2026**
**Status: Ready for Upload**

---

## ✅ Diagnostic Results Summary

From the diagnostic run, we confirmed:
- ✅ Database connected successfully
- ✅ All tables exist (learnerdetails, class, arpl_trades, arpl_papers, arpl_questions)
- ✅ Trade query returns "Bricklayer" (not "Electrician")
- ✅ Learner 11701 found in classID 797 with trade_id=4
- ✅ OFO number: 641201 (Bricklayer)

**The database has correct data!** The issue was just the file path in the PHP include.

---

## 📁 Files to Upload

### 1. Main File (REQUIRED)
```
Local:  c:\projects\rlmss\mobile\get_arpl_hierarchy.php
Server: /public_html/mobile/get_arpl_hierarchy.php
Action: UPLOAD (replace if exists)
```

### 2. Test File (OPTIONAL - for verification)
```
Local:  c:\projects\rlmss\mobile\test_arpl_endpoint_direct.php
Server: /public_html/mobile/test_arpl_endpoint_direct.php
Action: UPLOAD
```

---

## 🚀 Upload Steps

### Step 1: Upload Main File

**Upload `get_arpl_hierarchy.php`:**
- Source: `c:\projects\rlmss\mobile\get_arpl_hierarchy.php`
- Destination: `/public_html/mobile/get_arpl_hierarchy.php`
- Permissions: `644`

**Key Change Made:**
```php
// OLD (was looking in wrong place):
include_once 'connection.php';

// NEW (looks in parent directory):
require_once __DIR__ . '/../connection.php';
```

### Step 2: Test the Endpoint

**Option A: Test with cURL (Recommended)**
```bash
curl "https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701"
```

**Option B: Test via browser**
```
https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701
```

**Option C: Use test script**
If you uploaded `test_arpl_endpoint_direct.php`:
```
https://rlms.rlms.co.za/mobile/test_arpl_endpoint_direct.php
```

---

## ✅ Expected Response

### Success Response Structure:
```json
{
  "pathways": {
    "ARPL": {
      "qualifications": {
        "Bricklayer": {
          "theory_papers": {
            "Theory Paper 1": {
              "paper_id": 1,
              "paper_number": 1,
              "paper_type": "theory",
              "total_marks": 100,
              "questions": [
                {
                  "question_number": 1,
                  "specific_outcome": "...",
                  "assessment_criteria": "...",
                  "exercise": "...",
                  "marks": 10
                }
              ]
            }
          },
          "practical_papers": {
            "Practical Paper 1": {
              "paper_id": 3,
              "paper_number": 1,
              "paper_type": "practical",
              "total_marks": 100,
              "questions": [...]
            }
          }
        }
      }
    }
  },
  "_debug": [
    "Found learner: {...}",
    "Found class with trade_id: 4",
    "From arpl_trades table - Trade: Bricklayer, OFO: 641201",
    "Final trade selected: Bricklayer (OFO: 641201)",
    "Total papers loaded: 5",
    "Created paper structure with 5 papers",
    "Total questions processed: 50"
  ]
}
```

### Key Checks:
- ✅ Trade name is "Bricklayer" (NOT "Electrician")
- ✅ Papers are organized by type (theory_papers, practical_papers)
- ✅ Questions are grouped under their respective papers
- ✅ Debug shows "From arpl_trades table - Trade: Bricklayer"

---

## 📱 Device Testing

### Step 1: Ensure APK is Installed
```bash
# Check if already installed
adb devices

# Install if needed (from previous session)
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Step 2: Monitor Logs
```bash
adb logcat | findstr "ARPL"
```

### Step 3: Test Flow
1. Open app
2. Login as **ARPL Assessor** (User ID: 6)
3. Select **Bricklayer** class
4. Select learner (e.g., 11701)
5. View ARPL Portfolio breakdown

### Expected UI:
```
┌─────────────────────────────────────┐
│ ARPL Portfolio - Bricklayer         │ ← Should show "Bricklayer"
├─────────────────────────────────────┤
│ Theory Papers                       │
│  ├─ Theory Paper 1                  │
│  ├─ Theory Paper 2                  │
│  └─ Theory Paper 3                  │
│                                     │
│ Practical Papers                    │
│  ├─ Practical Paper 1               │
│  └─ Practical Paper 2               │
└─────────────────────────────────────┘
```

### Expected Logs:
```
[ARPL_TRADE] ✅ Trade name: Bricklayer
ARPL API Response: {"pathways":{"ARPL":{"qualifications":{"Bricklayer":{...}}}}}
ARPL DEBUG DATA: ["From arpl_trades table - Trade: Bricklayer, OFO: 641201"]
```

---

## 🔍 Troubleshooting

### Issue: Still shows "Electrician"

**Check 1: File uploaded correctly**
```bash
# SSH into server
ls -la /home/rlmsrlmsco/public_html/mobile/get_arpl_hierarchy.php
```

**Check 2: Clear PHP OpCache**
Create file: `/public_html/clear_cache.php`
```php
<?php
opcache_reset();
echo "Cache cleared";
?>
```
Access: `https://rlms.rlms.co.za/clear_cache.php`

**Check 3: Verify file content**
```bash
# Check the include line in uploaded file
head -20 /home/rlmsrlmsco/public_html/mobile/get_arpl_hierarchy.php
```
Should show:
```php
require_once __DIR__ . '/../connection.php';
```

### Issue: HTTP 500 error

**Check error logs:**
```bash
tail -f /home/rlmsrlmsco/logs/error.log
```

**Check PHP errors:**
```
https://rlms.rlms.co.za/mobile/test_arpl_endpoint_direct.php
```
This will show detailed error messages.

### Issue: No papers showing

**Check database:**
```sql
-- Check if papers exist for Bricklayer OFO
SELECT COUNT(*) FROM arpl_papers WHERE trade_ofo_code = '641201';

-- Check if questions exist
SELECT COUNT(*) FROM arpl_questions;
```

---

## 📊 Quick Verification Checklist

Before device testing:
- [ ] Uploaded `mobile/get_arpl_hierarchy.php` to server
- [ ] File permissions set to 644
- [ ] Tested endpoint with cURL
- [ ] Response shows "Bricklayer" not "Electrician"
- [ ] Response contains valid JSON
- [ ] Papers are organized correctly
- [ ] Questions are present

For device testing:
- [ ] APK installed on device
- [ ] adb logcat running
- [ ] Login as ARPL Assessor works
- [ ] Can see Bricklayer class
- [ ] Can select learner 11701
- [ ] ARPL breakdown shows correct trade name
- [ ] Papers display correctly
- [ ] No errors in logcat

---

## 🎯 Success Criteria

**Backend Success:**
- ✅ Endpoint returns HTTP 200
- ✅ Valid JSON response
- ✅ Trade name is "Bricklayer"
- ✅ Papers organized by type
- ✅ Questions present under correct papers
- ✅ Debug logs show correct workflow

**Frontend Success:**
- ✅ AppBar shows "ARPL Portfolio - Bricklayer"
- ✅ Cards show "Bricklayer" not "Electrician"
- ✅ Theory papers section visible
- ✅ Practical papers section visible
- ✅ Can expand papers to see questions
- ✅ No errors in device logs

---

## 🧹 Cleanup (After Testing)

### Remove test files from server:
```bash
# If you uploaded test files, delete them after verification:
rm /home/rlmsrlmsco/public_html/mobile/test_arpl_endpoint_direct.php
rm /home/rlmsrlmsco/public_html/mobile/diagnose_arpl_500_error.php
rm /home/rlmsrlmsco/public_html/clear_cache.php
```

### Keep these files:
- ✅ `/public_html/mobile/get_arpl_hierarchy.php` (production file)
- ✅ `/public_html/connection.php` (database connection)
- ✅ `/public_html/security_functions.php` (security utilities)

---

## 📝 What Changed

### Problem:
- Frontend AppBar showed "Bricklayer" ✅ (from `get_class_trade_info.php`)
- Backend cards showed "Electrician" ❌ (from `get_arpl_hierarchy.php`)

### Root Cause:
- `get_arpl_hierarchy.php` had hardcoded local IP configuration
- File used `include_once 'connection.php'` which failed on server
- Server structure: `connection.php` in root, `get_arpl_hierarchy.php` in mobile/

### Solution:
- Removed hardcoded local IP configuration
- Changed to: `require_once __DIR__ . '/../connection.php'`
- This looks in parent directory (`/public_html/`) for connection.php
- Workflow already correct (class → arpl_trades → arpl_papers → arpl_questions)

---

## 🎉 Final Notes

**The fix is simple:** Just upload the updated file!

The diagnostic confirmed:
- Database structure is correct ✅
- Trade data is correct ("Bricklayer" not "Electrician") ✅
- Workflow logic is correct ✅
- Only issue was the PHP include path ✅ (now fixed)

**Upload `mobile/get_arpl_hierarchy.php` and test!**

---

**File:** `mobile/get_arpl_hierarchy.php`
**Status:** ✅ Ready for upload
**Server Path:** `/public_html/mobile/get_arpl_hierarchy.php`
**Test URL:** `https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701`

**Expected Result:** Trade name shows "Bricklayer" throughout the entire system! 🎉
