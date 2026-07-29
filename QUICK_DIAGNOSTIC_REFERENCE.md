# 🎯 Quick Diagnostic Reference Card

## One-Page Guide to Fix 400 Error

---

## 📤 UPLOAD (Do This First)

**File:** `c:\projects\rlmss\mobile\test_toolkit_simple.php`  
**To:** Server at `https://rlms.rlms.co.za/mobile/`  
**Method:** FTP, cPanel, or File Manager

---

## 🌐 ACCESS (Do This Second)

**URL:** `https://rlms.rlms.co.za/mobile/test_toolkit_simple.php`  
**Browser:** Any (Chrome, Firefox, Edge)  
**Expected:** Text output appears

---

## 📋 COPY (Do This Third)

**Action:** Select all text on page (Ctrl+A)  
**Copy:** Ctrl+C or right-click → Copy  
**Paste:** In your response to me

---

## 🔍 WHAT TO LOOK FOR

### ✅ SUCCESS (HTTP Status: 200)
```
6. Testing actual endpoint call...
   HTTP Status: 200        ← GOOD!
   SUCCESS: Endpoint working!
```
**Action:** Test on device, should work now!

### ❌ ERROR (HTTP Status: 400)
```
6. Testing actual endpoint call...
   HTTP Status: 400        ← PROBLEM!
   ERROR: Endpoint failed!

=== ERROR RESPONSE ===
{"status":"error","message":"[ERROR DETAILS HERE]"}
```
**Action:** Send me the entire error message!

---

## 🎬 3-STEP PROCESS

```
1. UPLOAD    → test_toolkit_simple.php to server
      ↓
2. ACCESS    → https://rlms.rlms.co.za/mobile/test_toolkit_simple.php
      ↓
3. SEND      → Copy entire output and send to me
```

---

## ⏱️ TIME: 5 Minutes Total

- Upload: 1 minute
- Access: 30 seconds  
- Copy: 30 seconds
- Send: 1 minute

---

## 🆘 COMMON ISSUES

| Problem | Solution |
|---------|----------|
| 404 Not Found | Re-upload file |
| Blank page | View source (Ctrl+U) |
| Permission denied | Set permissions to 644 |
| Slow loading | Wait 10-15 seconds |

---

## 📞 NEED HELP?

Just say: "I'm stuck at [step]" and describe what you see.

---

## 🎯 YOUR MISSION

**Upload → Access → Copy → Send**

That's it! I'll handle the rest.

---

## 🔗 QUICK LINKS

**Test URL:**  
`https://rlms.rlms.co.za/mobile/test_toolkit_simple.php`

**Alternative (HTML Report):**  
`https://rlms.rlms.co.za/mobile/diagnose_bricklayer_toolkit.php`

**Alternative (JSON Debug):**  
`https://rlms.rlms.co.za/mobile/debug_endpoint.php`

---

## ✅ CHECKLIST

- [ ] Uploaded file ✓
- [ ] Opened URL ✓
- [ ] Page loaded ✓
- [ ] Copied output ✓
- [ ] Ready to send ✓

---

**Let's fix this!** 🚀
