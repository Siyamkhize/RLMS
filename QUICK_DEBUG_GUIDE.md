# QUICK DEBUG GUIDE - GET THE ERROR LOGS

## 🎯 YOUR GOAL
Capture the exact error that appears when you click "View Toolkit" for bricklayer

## 📱 ON YOUR ANDROID DEVICE

### Step 1: Open the app
- Tap RLMSS icon

### Step 2: Log in
- Enter credentials
- Wait for home screen

### Step 3: Navigate to bricklayer
- Go to whatever section shows learners
- Find and **select a bricklayer learner**

### Step 4: Click "View Toolkit"
- Tap the "View Toolkit" button
- **Error screen will appear** (the one you showed me)

### Step 5: Keep device ready
- Don't close the app
- Leave it on the error screen

---

## 💻 ON YOUR COMPUTER

### Step 1: Open PowerShell
- Press Windows key
- Type: `powershell`
- Press Enter

### Step 2: Navigate to project
```powershell
cd c:\projects\rlmss
```

### Step 3: Run EITHER Option A OR Option B

#### 🅰️ **Option A: Quick View (Real-time)**
```powershell
adb logcat | Select-String "BRICKLAYER|AppendixH|ERROR"
```
- See logs appear in real-time as you use the app
- Stop with: Ctrl+C
- Copy the error output

#### 🅱️ **Option B: Save to File**
```powershell
adb logcat > error_logs.txt
```
- Logs save to file while running
- Do the error test (Step 1-4 above on device)
- Press Ctrl+C to stop
- File created: `c:\projects\rlmss\error_logs.txt`

### Step 4: View the captured logs

**If you used Option A:**
- Look at the PowerShell output showing in the window
- Copy any lines with `[BRICKLAYER_ERROR]` or `[AppendixHData]`

**If you used Option B:**
```powershell
Get-Content error_logs.txt | Select-String "BRICKLAYER_ERROR"
```

---

## 📋 WHAT TO SEND ME

Copy and paste one of these:

**Option 1:** The entire log file content
```powershell
Get-Content error_logs.txt | Out-String
```

**Option 2:** Just the error section
```powershell
Get-Content error_logs.txt | Select-String "ERROR|BRICKLAYER|AppendixH"
```

**Option 3:** Manual copy from PowerShell
- Highlight the text in PowerShell
- Right-click → Copy
- Paste in message to me

---

## ⏱️ TIMING

| Step | Time |
|------|------|
| Run PowerShell command | Immediate |
| On device: Log in | ~30 seconds |
| On device: Select learner | ~5 seconds |
| On device: Click View Toolkit | Immediate (error appears) |
| Stop capture (Ctrl+C) | Immediate |
| View logs | Immediate |
| Send to me | Copy & paste |

**Total time: ~1-2 minutes**

---

## ✅ CHECKLIST

- [ ] PowerShell command running on your computer
- [ ] On device: At the error screen (after clicking "View Toolkit")
- [ ] Saw logs appear (if using Option A)
- [ ] Stopped capture with Ctrl+C
- [ ] Viewed the logs to see the error
- [ ] Copied the relevant error sections
- [ ] Ready to send logs to me

---

## 🔍 WHAT I'LL SEE IN THE LOGS

The logs will show me:

1. **The exact JSON** being sent from the server
2. **The exact types** of each field
3. **Exactly where** the parsing fails
4. **The exact error** with full stack trace
5. **Which field** is causing the type mismatch

From this, I can immediately fix the issue.

---

## EXAMPLE: What the logs look like

```
[BRICKLAYER_TRACE] API Response Status: 200
[BRICKLAYER_TRACE] appendixH type: _InternalLinkedHashMap<String, dynamic>
[BRICKLAYER_TRACE] appendixH.recommendations type: List<dynamic>
[BRICKLAYER_ERROR] ═══ PARSE ERROR ═══
[BRICKLAYER_ERROR] Error: type 'SomeType' is not a subtype of type 'ExpectedType'
[AppendixHData.fromJson] Processing recommendations...
[AppendixHData.fromJson] ERROR: recommendations is not a List, it is String
```

---

## 🚀 GET STARTED NOW

```powershell
cd c:\projects\rlmss
adb logcat | Select-String "BRICKLAYER|AppendixH|ERROR"
```

Then on your device, trigger the error and share what you see!

