# 🔧 Complete Diagnostic Toolkit for 400 Error

## 📦 What We've Created

You now have **3 powerful diagnostic tools** to identify why the toolkit returns a 400 error:

| Tool | Type | Best For | URL |
|------|------|----------|-----|
| **test_toolkit_simple.php** | Plain Text | Quick diagnosis | https://rlms.rlms.co.za/mobile/test_toolkit_simple.php |
| **diagnose_bricklayer_toolkit.php** | HTML Report | Detailed analysis | https://rlms.rlms.co.za/mobile/diagnose_bricklayer_toolkit.php |
| **debug_endpoint.php** | JSON Debug | Developer-level | https://rlms.rlms.co.za/mobile/debug_endpoint.php |

---

## 🚀 Quick Start (Choose Your Method)

### Method 1: Simple Test (Recommended)
**Best if:** You want quick results in plain text

```
1. Upload: mobile/test_toolkit_simple.php
2. Visit: https://rlms.rlms.co.za/mobile/test_toolkit_simple.php
3. Copy: Entire page output
4. Send: To me for analysis
```

### Method 2: Comprehensive Report
**Best if:** You want visual HTML report with details

```
1. Upload: mobile/diagnose_bricklayer_toolkit.php
2. Visit: https://rlms.rlms.co.za/mobile/diagnose_bricklayer_toolkit.php
3. Review: Color-coded sections
4. Screenshot: TEST 12 (POST Request Simulation)
5. Send: Screenshots to me
```

### Method 3: JSON Debug
**Best if:** You're comfortable with JSON/developer tools

```
1. Upload: mobile/debug_endpoint.php
2. Visit: https://rlms.rlms.co.za/mobile/debug_endpoint.php
3. Review: JSON response
4. Send: JSON output to me
```

---

## 📁 Files to Upload

All files are in: `c:\projects\rlmss\mobile\`

Upload these to your server's `/mobile/` directory:

- [x] `test_toolkit_simple.php` - Simple diagnostic
- [x] `diagnose_bricklayer_toolkit.php` - HTML report
- [x] `debug_endpoint.php` - JSON debugger
- [x] `get_bricklayer_toolkit_data.php` - Main endpoint (if not already uploaded)

---

## 🎯 What Each Tool Tests

### test_toolkit_simple.php
```
✓ Connection file exists
✓ Database connection works
✓ Learner 11701 exists
✓ Class 797 exists
✓ Required tables exist
✓ Endpoint returns 200 (not 400)
```

### diagnose_bricklayer_toolkit.php
```
✓ All of the above PLUS:
✓ Table structure details
✓ Sample data from tables
✓ Query execution results
✓ Full endpoint simulation
✓ Detailed error messages
✓ Color-coded visual report
```

### debug_endpoint.php
```
✓ Step-by-step execution log
✓ Error capture and reporting
✓ Endpoint output analysis
✓ JSON structured results
✓ Stack traces for errors
```

---

## 🔍 How to Interpret Results

### ✅ SUCCESS Pattern
Any tool showing:
- HTTP Status: **200**
- Status: **"success"**
- No errors in output
- Response contains learner data

**Action:** Toolkit is working! Test on device.

### ❌ ERROR Pattern
Any tool showing:
- HTTP Status: **400**
- Status: **"error"**
- Error message visible
- Missing tables reported

**Action:** Copy error message and send to me.

---

## 📊 Common Errors and Fixes

### Error 1: "Table doesn't exist"
```
ERROR: Table 'arplappxb_bricklaying_activities' doesn't exist
```

**Fix:** Need to create tables on ONLINE database
- I'll provide SQL script
- Run on your online database
- Re-test

### Error 2: "Database connection failed"
```
ERROR: Database connection failed
```

**Fix:** Check connection.php
- Verify credentials
- Check database server status
- Ensure user has permissions

### Error 3: "Learner not found"
```
ERROR: Learner not found with LearnerID=11701
```

**Fix:** Data issue
- Verify LearnerID 11701 exists
- Check correct database
- Verify class 797 exists

### Error 4: "Unknown column"
```
ERROR: Unknown column 'competency_scale_id' in field list
```

**Fix:** Column name mismatch
- I'll update the query
- Provide corrected PHP file

---

## 🎬 Step-by-Step Usage

### Using test_toolkit_simple.php

```
STEP 1: Upload File
├─ Upload: c:\projects\rlmss\mobile\test_toolkit_simple.php
└─ To: https://rlms.rlms.co.za/mobile/

STEP 2: Access URL
└─ Open: https://rlms.rlms.co.za/mobile/test_toolkit_simple.php

STEP 3: Review Output
├─ Look for "HTTP Status: 200" or "HTTP Status: 400"
├─ Read error messages if any
└─ Copy entire output

STEP 4: Send Results
└─ Paste entire output in your response to me
```

### Using diagnose_bricklayer_toolkit.php

```
STEP 1: Upload File
├─ Upload: c:\projects\rlmss\mobile\diagnose_bricklayer_toolkit.php
└─ To: https://rlms.rlms.co.za/mobile/

STEP 2: Access URL
└─ Open: https://rlms.rlms.co.za/mobile/diagnose_bricklayer_toolkit.php

STEP 3: Review Report
├─ Scroll to TEST 12 (POST Request Simulation)
├─ Check HTTP Status Code
└─ Review response section

STEP 4: Send Results
├─ Screenshot TEST 12 section
└─ Send screenshot to me
```

---

## ⚡ Quick Troubleshooting

### "Page Not Found (404)"
→ File not uploaded or wrong URL
→ Re-upload and clear browser cache

### "Blank Page"
→ PHP syntax error
→ View page source (Ctrl+U)
→ Check server error logs

### "Permission Denied"
→ File permissions incorrect
→ Set to 644 via FTP

### "Connection Timeout"
→ Server slow or query taking too long
→ Try test_toolkit_simple.php (faster)

---

## 📞 What to Send Me

**Option 1: Text Output (Best)**
```
Copy entire output from test_toolkit_simple.php
Paste in your message
```

**Option 2: Screenshot**
```
Screenshot of TEST 12 from diagnose_bricklayer_toolkit.php
Show HTTP status and error message
```

**Option 3: JSON**
```
Copy JSON output from debug_endpoint.php
Look for "overall_status" and "errors" sections
```

---

## 🎯 Expected Timeline

| Step | Time | Details |
|------|------|---------|
| Upload files | 2 min | Via FTP/cPanel |
| Run diagnostic | 30 sec | Open URL in browser |
| Copy output | 30 sec | Select all, copy |
| Send to me | 1 min | Paste in response |
| I analyze | 2 min | Review error |
| I fix issue | 5 min | Update code |
| You test fix | 2 min | Upload and test |
| **TOTAL** | **~15 min** | End-to-end |

---

## 🔥 Priority Actions

### NOW (Required)
1. [ ] Upload test_toolkit_simple.php
2. [ ] Access the URL in browser
3. [ ] Copy entire output
4. [ ] Send output to me

### OPTIONAL (If Needed)
1. [ ] Upload diagnose_bricklayer_toolkit.php
2. [ ] Review detailed HTML report
3. [ ] Send screenshots of issues

### LATER (Reference)
1. [ ] Keep debug_endpoint.php for future debugging
2. [ ] Bookmark diagnostic URLs
3. [ ] Save error logs

---

## 💡 Pro Tips

1. **Clear browser cache** before testing
2. **Use incognito mode** to avoid cached results
3. **Check server time** matches your timezone
4. **Save diagnostic outputs** for reference
5. **Test on multiple browsers** if issues persist

---

## 📋 Checklist

Before sending me the diagnostic:

- [ ] Uploaded diagnostic file to server
- [ ] Accessed URL in browser
- [ ] Page loaded successfully (not 404)
- [ ] Copied ENTIRE output (not partial)
- [ ] Identified if HTTP status is 200 or 400
- [ ] Ready to send full output

---

## 🎁 Bonus: Test from Command Line

If you have SSH access to server:

```bash
# Test simple
curl https://rlms.rlms.co.za/mobile/test_toolkit_simple.php

# Test JSON debugger
curl https://rlms.rlms.co.za/mobile/debug_endpoint.php

# Test actual endpoint
curl -X POST https://rlms.rlms.co.za/mobile/get_bricklayer_toolkit_data.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID": 11701, "classID": 797}'
```

---

## 📚 Additional Resources

### Documentation
- `URGENT_TOOLKIT_DIAGNOSTIC_INSTRUCTIONS.md` - Detailed instructions
- `TOOLKIT_400_ERROR_CHECKLIST.md` - Quick checklist
- `ARPL_COMPLETE_TOOLKIT_FIXES_SUMMARY.md` - All previous fixes

### Files
- `mobile/get_bricklayer_toolkit_data.php` - Main endpoint
- `lib/ArplAssessorPage.dart` - Flutter app code
- `lib/models/arpl_toolkit_data.dart` - Data models

---

## 🚨 REMEMBER

**The 400 error is happening on the SERVER, not in the app.**

We need to:
1. ✅ Run diagnostics ON THE SERVER
2. ✅ Identify the exact server-side error
3. ✅ Fix the server-side PHP code
4. ✅ Test from the app

**Don't rebuild the app yet - we need to fix the server first!**

---

**Ready to start?**

Upload `test_toolkit_simple.php` and send me the output!

---

**Created:** 2026-07-15  
**Status:** Ready for deployment  
**Tools:** 3 diagnostic scripts  
**Estimated Fix Time:** 15 minutes once we see the error
