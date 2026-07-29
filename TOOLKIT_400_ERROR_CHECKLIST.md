# ✅ Bricklayer Toolkit 400 Error - Quick Checklist

## Files Ready for Upload

### ✅ Diagnostic Files (Upload These Now)
```
📁 c:\projects\rlmss\mobile\
  ├─ test_toolkit_simple.php          ← Upload to server
  └─ diagnose_bricklayer_toolkit.php  ← Upload to server
```

### ✅ Main Endpoint (Already Updated)
```
📁 c:\projects\rlmss\mobile\
  └─ get_bricklayer_toolkit_data.php  ← Upload to server (if not already done)
```

---

## Step-by-Step Checklist

### □ STEP 1: Upload Files to Server
- [ ] Upload `test_toolkit_simple.php` to `/mobile/` folder
- [ ] Upload `diagnose_bricklayer_toolkit.php` to `/mobile/` folder
- [ ] Verify file permissions are correct (644)

### □ STEP 2: Run Simple Test
- [ ] Open browser
- [ ] Navigate to: `https://rlms.rlms.co.za/mobile/test_toolkit_simple.php`
- [ ] Wait for page to load (may take 5-10 seconds)
- [ ] Copy ENTIRE output

### □ STEP 3: Check Results
**Look for this line:**
```
6. Testing actual endpoint call...
   HTTP Status: ???
```

**If HTTP Status is 200:**
✅ Success! Toolkit is working!

**If HTTP Status is 400:**
❌ Error found - copy the error message below this line

### □ STEP 4: Send Results Back
- [ ] Copy the entire output from test_toolkit_simple.php
- [ ] Send it in your response
- [ ] Include any error messages you see

---

## What Each Test Checks

| Test | Checks | If Failed |
|------|--------|-----------|
| 1 | Connection file exists | Upload connection.php |
| 2 | Test parameters set | Internal - no action needed |
| 3 | Learner exists in DB | Check LearnerID 11701 |
| 4 | Class exists in DB | Check ClassID 797 |
| 5 | Required tables exist | Need SQL to create tables |
| 6 | Endpoint returns 200 | **Main issue - send error** |

---

## Quick Visual Guide

```
┌─────────────────────────────────────────┐
│  1. UPLOAD FILES                         │
│     test_toolkit_simple.php              │
│     diagnose_bricklayer_toolkit.php      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  2. OPEN IN BROWSER                      │
│     https://rlms.rlms.co.za/mobile/      │
│     test_toolkit_simple.php              │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  3. COPY OUTPUT                          │
│     Select All (Ctrl+A)                  │
│     Copy (Ctrl+C)                        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  4. SEND TO ME                           │
│     Paste entire output in response      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  5. I WILL FIX THE ISSUE                 │
│     Based on error message               │
└─────────────────────────────────────────┘
```

---

## Expected Output Examples

### ✅ GOOD (Everything Working)
```
=== SIMPLE TOOLKIT TEST ===
Time: 2026-07-15 10:30:00

1. Testing connection.php...
   SUCCESS: Connected to database

2. Test Parameters:
   LearnerID: 11701
   ClassID: 797

3. Testing learner query...
   SUCCESS: Found learner Anele Cele

4. Testing class query...
   SUCCESS: Found class Bricklayer Class

5. Checking critical tables...
   OK: arplappxb_bricklaying_activities exists
   OK: arplappxb_activity_ratings exists
   OK: arpl_competency_scale exists

6. Testing actual endpoint call...
   HTTP Status: 200
   SUCCESS: Endpoint working!

=== RESPONSE ===
{
    "status": "success",
    "learnerID": 11701,
    ...
}

=== TEST COMPLETE ===
```

### ❌ BAD (Error Found)
```
=== SIMPLE TOOLKIT TEST ===
Time: 2026-07-15 10:30:00

1. Testing connection.php...
   SUCCESS: Connected to database

2. Test Parameters:
   LearnerID: 11701
   ClassID: 797

3. Testing learner query...
   SUCCESS: Found learner Anele Cele

4. Testing class query...
   SUCCESS: Found class Bricklayer Class

5. Checking critical tables...
   MISSING: arplappxb_bricklaying_activities  ← PROBLEM HERE!
   MISSING: arplappxb_activity_ratings
   OK: arpl_competency_scale exists

6. Testing actual endpoint call...
   HTTP Status: 400                           ← ERROR!
   ERROR: Endpoint failed!

=== ERROR RESPONSE ===
{
    "status": "error",
    "message": "Table 'arplappxb_bricklaying_activities' doesn't exist"
}

=== TEST COMPLETE ===
```

---

## Troubleshooting Tips

### "Page not found (404)"
→ File didn't upload correctly. Re-upload and refresh browser.

### "Blank white page"
→ PHP error. View page source (Ctrl+U) or check server error logs.

### "Connection refused"
→ Server firewall or wrong URL. Verify: `https://rlms.rlms.co.za`

### "Permission denied"
→ File permissions wrong. Set to 644 via FTP client.

---

## Time Estimate

| Task | Time |
|------|------|
| Upload files | 1-2 minutes |
| Run test | 30 seconds |
| Copy output | 10 seconds |
| Send to me | 1 minute |
| **TOTAL** | **~5 minutes** |

---

## Ready?

✅ You have the files  
✅ You have the instructions  
✅ You know what to look for  

**Just upload, run, and send me the output!**

---

**Last Updated:** 2026-07-15  
**Next Action:** Upload diagnostic files and run test
