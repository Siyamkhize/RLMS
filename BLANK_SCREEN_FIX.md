# Blank Screen After Clicking Bricklaying - Fix
**Date: July 23, 2026**
**Issue: Gray/blank screen after selecting Bricklaying class**

---

## 🔍 Problem Analysis

**What's Happening:**
- User clicks on "Bricklaying" class
- App navigates to `ArplHierarchicalNavigatorPage`
- Screen shows blank/gray (loading forever or error)
- API call to `get_arpl_hierarchy.php` is failing

**Root Cause:**
The fixed `get_arpl_hierarchy.php` file has NOT been uploaded to the server yet!
The server still has the OLD version with local IP configuration.

---

## ✅ Solution: Upload Backend File

### UPLOAD THIS FILE:
```
Local File:  c:\projects\rlmss\mobile\get_arpl_hierarchy.php
Server Path: /public_html/mobile/get_arpl_hierarchy.php
Action:      REPLACE existing file
Permissions: 644
```

### Upload via FTP/cPanel:
1. Connect to server
2. Navigate to `/public_html/mobile/`
3. Upload `get_arpl_hierarchy.php`
4. Set permissions to `644`
5. Test immediately

---

## 🧪 Test After Upload

### Test 1: Direct API Test
```bash
curl "https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701"
```

**Expected Response:**
```json
{
  "pathways": {
    "ARPL": {
      "qualifications": {
        "Bricklayer": {
          "theory_papers": {...},
          "practical_papers": {...}
        }
      }
    }
  }
}
```

**If you see error:** The file wasn't uploaded correctly or has syntax issues.

### Test 2: Device Test
1. Close and reopen the app
2. Login as ARPL Assessor
3. Click on Bricklaying class
4. Should now show:
   - "Select Pathway" screen
   - Then pathway → trade → section → papers → questions

---

## 🔧 Alternative Diagnostic Steps

### Check Logs on Device:
```bash
# Clear logs first
adb logcat -c

# Then click Bricklaying in app and monitor logs:
adb logcat | findstr "ARPL"
```

**Look for:**
- `[ARPL_TRADE] ✅ Trade name: Bricklayer` ← Should see this
- `ARPL DEBUG DATA:` ← Should show debug info
- Any error messages

### Common Error Patterns:

#### Error 1: Connection Failed
```
Error: Failed to load data: Connection refused
```
**Fix:** Server is down or URL is wrong. Check internet connection.

#### Error 2: HTTP 500
```
Server error: 500
```
**Fix:** PHP file has syntax error or can't find connection.php
**Solution:** Upload the fixed `get_arpl_hierarchy.php`

#### Error 3: Invalid JSON
```
Error parsing response
```
**Fix:** PHP file outputting HTML error instead of JSON
**Solution:** Check PHP error logs on server

#### Error 4: Empty Response
```
pathways: {}
```
**Fix:** Database has no data for this trade
**Solution:** Check if arpl_papers table has data for OFO 641201

---

## 📋 Quick Checklist

Before testing on device:
- [ ] Upload `mobile/get_arpl_hierarchy.php` to server
- [ ] Set file permissions to 644
- [ ] Test endpoint with cURL (should return JSON)
- [ ] Verify JSON contains "Bricklayer" not "Electrician"
- [ ] Response has theory_papers and practical_papers sections
- [ ] Papers have questions arrays

After upload:
- [ ] Close and reopen app
- [ ] Login as ARPL Assessor
- [ ] Click Bricklaying class
- [ ] Should see "Select Pathway" screen
- [ ] Can navigate through hierarchy
- [ ] Papers and questions display

---

## 🎯 Expected Flow After Fix

### Screen 1: Select Pathway
```
┌─────────────────────────────────────┐
│ Bricklayer Portfolio                │
├─────────────────────────────────────┤
│ Select Pathway                      │
│                                     │
│  📚 ARPL                            │
│     Recognition of Prior Learning   │
│                                     │
└─────────────────────────────────────┘
```

### Screen 2: Select Trade
```
┌─────────────────────────────────────┐
│ Bricklayer Portfolio                │
├─────────────────────────────────────┤
│ Select Trade                        │
│                                     │
│  🔨 Bricklayer                      │
│     5 papers available              │
│                                     │
└─────────────────────────────────────┘
```

### Screen 3: Select Section
```
┌─────────────────────────────────────┐
│ Select Section Type                 │
│ Trade: Bricklayer                   │
├─────────────────────────────────────┤
│  📄 Theory                          │
│     3 papers                        │
│                                     │
│  🔧 Practical                       │
│     2 papers                        │
│                                     │
└─────────────────────────────────────┘
```

### Screen 4: Select Paper
```
┌─────────────────────────────────────┐
│ Select Paper                        │
│ Bricklayer - Theory                 │
├─────────────────────────────────────┤
│ Available Papers                    │
│ 3 papers available for upload       │
│                                     │
│  📄 Theory Paper 1                  │
│     10 questions                    │
│                                     │
│  📄 Theory Paper 2                  │
│     10 questions                    │
│                                     │
│  📄 Theory Paper 3                  │
│     10 questions                    │
│                                     │
└─────────────────────────────────────┘
```

### Screen 5: Question List
```
┌─────────────────────────────────────┐
│ Theory Paper 1                      │
│ Bricklayer - Theory                 │
├─────────────────────────────────────┤
│  ❓ Question 1 (10 marks)           │
│     Specific Outcome: ...           │
│     [UPLOAD PHOTO]                  │
│                                     │
│  ❓ Question 2 (10 marks)           │
│     Specific Outcome: ...           │
│     [UPLOAD PHOTO]                  │
│                                     │
└─────────────────────────────────────┘
```

---

## ⚠️ CRITICAL: Backend File Must Be Uploaded!

**The app CANNOT work without uploading the backend file!**

The current server file has this problem:
```php
// OLD VERSION (on server now):
$host = '192.168.0.57';  // ❌ Wrong - local IP
```

The new file has this fix:
```php
// NEW VERSION (needs to be uploaded):
require_once __DIR__ . '/../connection.php';  // ✅ Correct
```

---

## 📞 Quick Test Command

After uploading, run this immediately:
```bash
curl -s "https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701" | grep -o "Bricklayer\|Electrician"
```

**Expected output:** `Bricklayer`
**If shows:** `Electrician` → File not uploaded correctly

---

## ✅ Summary

**Problem:** Blank screen = API call failing
**Cause:** Backend file not uploaded to server
**Solution:** Upload `mobile/get_arpl_hierarchy.php`
**Test:** cURL command should return "Bricklayer" in JSON
**Result:** Screen will show full navigation hierarchy

---

**Status:** ⏳ Awaiting backend file upload
**ETA:** 2 minutes after upload
**Impact:** CRITICAL - App cannot work until file is uploaded
