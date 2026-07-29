# APK READY - TRACE LOGGING ENABLED FOR BRICKLAYER DEBUG

**Status:** ✅ APK BUILT, INSTALLED, AND READY FOR TESTING  
**Date:** July 10, 2026  
**Size:** 45.9 MB

---

## WHAT YOU HAVE NOW

A new APK with **comprehensive trace logging** that will show exactly what's happening when the bricklayer toolkit loads.

---

## QUICK TEST INSTRUCTIONS

### 1. Clear Old Logs (Optional)
```powershell
adb logcat -c
```

### 2. Start Capturing Logs

**Option A: Capture to File**
```powershell
cd c:\projects\rlmss
adb logcat > bricklayer_error_logs.txt
```

**Option B: View Real-time (Filtered)**
```powershell
adb logcat | Select-String "BRICKLAYER|AppendixH"
```

### 3. Trigger the Error in App

On your Android device:
1. Open RLMSS app
2. Log in
3. Navigate to bricklayer learner selection
4. **Select a bricklayer learner**
5. **Tap "View Toolkit"**
6. **Wait for error to appear** (should be immediate)

### 4. Stop and Review

If using file capture (Option A):
```powershell
# Stop capturing with Ctrl+C
# Then view the important logs:
Get-Content bricklayer_error_logs.txt | Select-String "BRICKLAYER_ERROR|AppendixHData|ArplToolkitData"
```

---

## WHAT TO LOOK FOR IN LOGS

### Raw API Response
```
[BRICKLAYER_TRACE] ═══ RAW API RESPONSE ═══
[BRICKLAYER_TRACE] {"status":"success",...entire JSON...}
```

### Type Information
```
[BRICKLAYER_TRACE] appendixH.recommendations type: ???
[BRICKLAYER_TRACE] appendixH.items type: ???
[BRICKLAYER_TRACE] appendixH.gap_standards type: ???
```

### The Error
```
[BRICKLAYER_ERROR] ═══ PARSE ERROR ═══
[BRICKLAYER_ERROR] Error: type 'List<dynamic>' is not a subtype...
[BRICKLAYER_ERROR] Stack Trace:
#0 ...
#1 ...
```

---

## SEND ME THE LOGS

Once you have the logs, share:
- The entire `bricklayer_error_logs.txt` file, OR
- Copy and paste the `[BRICKLAYER_ERROR]` and `[AppendixHData]` sections

---

## LOG SECTIONS ADDED

### ArplToolkitBricklayerPage.dart
- Full API response body logged
- Type of each appendix logged
- Parse errors with stack traces
- Network errors with full details

### ArplToolkitData.fromJson
- Each appendix logged as it's parsed
- Shows which one fails first
- Error location identified

### AppendixHData.fromJson
- Inputs and types logged
- Each field (items, recommendations, gap_standards) logged
- Exact error if type mismatch occurs

---

## TECHNICAL DETAILS

**Logging Tags:**
- `[BRICKLAYER_TRACE]` - Trace/debug info
- `[BRICKLAYER_ERROR]` - Errors
- `[ArplToolkitData.fromJson]` - Model parsing
- `[AppendixHData.fromJson]` - AppendixH parsing

**No Performance Impact:**
- Logging is only in debug/release modes
- Doesn't slow down the app
- Only outputs to logcat (console)

---

## EXPECTED FLOW

```
App starts load
     ↓
API called to get_bricklayer_toolkit_data.php
     ↓
Response received (logged)
     ↓
JSON parsed (type checked)
     ↓
ArplToolkitData.fromJson called
     ↓
Each appendix parsed (logged)
     ↓
Error occurs! (logged with full trace)
     ↓
Error message shown on screen
```

The logs will show **exactly** where in this flow the error happens.

---

## COMMANDS REFERENCE

```powershell
# Clear logs
adb logcat -c

# Capture to file
adb logcat > logs.txt

# Real-time view (all logs)
adb logcat

# Real-time view (filtered - recommended)
adb logcat | Select-String "BRICKLAYER|AppendixH"

# Stop capturing (when using file)
# Press: Ctrl+C

# View file later
Get-Content logs.txt | Select-String "BRICKLAYER_ERROR"
```

---

## SUMMARY

✅ APK installed with trace logging  
⏳ Ready for you to test in the app  
⏳ Will capture full error details  
⏳ Share logs so I can diagnose the exact issue  

**Next Step:** Test in the app and capture the logs!

