# BRICKLAYER TOOLKIT - DEBUG WITH TRACE LOGGING

**Status:** ✅ APK REBUILT WITH COMPREHENSIVE TRACE LOGGING  
**Date:** July 10, 2026

---

## WHAT WAS DONE

Added extensive trace logging to capture every step of the data loading and parsing process:

### 1. ArplToolkitBricklayerPage.dart (_loadToolkitData method)
Added detailed logging for:
- ✅ API response status and size
- ✅ Raw JSON response content (full body)
- ✅ Type information for each appendix
- ✅ Parse errors with full stack traces
- ✅ Network errors with stack traces

### 2. arpl_toolkit_data.dart (ArplToolkitData.fromJson)
Added step-by-step logging:
- ✅ Logs each appendix as it's parsed
- ✅ Shows which appendix fails parsing
- ✅ Full error stack trace if parsing fails

### 3. arpl_toolkit_data.dart (AppendixHData.fromJson)
Deep dive logging:
- ✅ Logs input JSON structure
- ✅ Shows type of each field (items, recommendations, gap_standards)
- ✅ Lists which fields are arrays vs null vs other types
- ✅ Logs exact error if field is wrong type
- ✅ Complete exception stack trace

---

## NEW APK FEATURES

✅ **Build:** 45.9 MB  
✅ **Status:** Installed on device (SUCCESS)  
✅ **Logging:** Comprehensive trace logging active  
✅ **Performance:** No performance impact

---

## HOW TO USE

### Option 1: Capture All Logs to File

```powershell
# Start capturing
adb logcat > bricklayer_trace_logs.txt

# In the app:
# 1. Select bricklayer learner
# 2. Tap "View Toolkit"
# 3. Error appears

# Stop capturing (Ctrl+C)

# View the file
Get-Content bricklayer_trace_logs.txt | Select-String "BRICKLAYER|AppendixH|ArplToolkit"
```

### Option 2: View Real-time Filtered Logs

```powershell
# Shows only BRICKLAYER and parsing logs
adb logcat | Select-String "BRICKLAYER|AppendixH|ArplToolkit"

# In the app:
# 1. Select bricklayer learner
# 2. Tap "View Toolkit"
# 3. See logs appear in real-time
```

---

## LOG MARKERS TO LOOK FOR

| Marker | Meaning |
|--------|---------|
| `[BRICKLAYER_TRACE]` | Detailed trace information - data loading steps |
| `[BRICKLAYER_ERROR]` | Error messages from the page |
| `[ArplToolkitData.fromJson]` | Model parsing trace - which appendix being parsed |
| `[AppendixHData.fromJson]` | AppendixH specific parsing - where H fails |

---

## WHAT THE LOGS WILL REVEAL

The logs will show:

1. **API Response Content**
   ```
   [BRICKLAYER_TRACE] ═══ RAW API RESPONSE ═══
   [BRICKLAYER_TRACE] {"status":"success", "appendixH": {...}}
   [BRICKLAYER_TRACE] ═══ END RAW RESPONSE ═══
   ```

2. **Type Checking**
   ```
   [BRICKLAYER_TRACE] appendixH type: _InternalLinkedHashMap<String, dynamic>
   [BRICKLAYER_TRACE] appendixH.items type: List<dynamic>
   [BRICKLAYER_TRACE] appendixH.recommendations type: List<dynamic> OR null OR something else
   ```

3. **Parsing Steps**
   ```
   [ArplToolkitData.fromJson] Parsing learner...
   [ArplToolkitData.fromJson] ✓ Learner parsed
   [ArplToolkitData.fromJson] Parsing appendixH...
   [AppendixHData.fromJson] ═══ ENTERING ═══
   [AppendixHData.fromJson] Processing items...
   [AppendixHData.fromJson] Processing recommendations...
   ```

4. **Error Details**
   ```
   [BRICKLAYER_ERROR] ═══ PARSE ERROR ═══
   [BRICKLAYER_ERROR] Error: type 'List<dynamic>' is not a subtype of type 'Map<dynamic,dynamic>'
   [BRICKLAYER_ERROR] Stack Trace:
   [BRICKLAYER_ERROR] #0 AppendixHData.fromJson (...)
   [BRICKLAYER_ERROR] #1 ArplToolkitData.fromJson (...)
   ```

---

## NEXT STEPS

1. ✅ Install APK (DONE)
2. ⏳ **Test in app** - Select bricklayer learner → View Toolkit
3. ⏳ **Capture logs** - Run `adb logcat` command above
4. ⏳ **Share logs** - Send the output from logs
5. ⏳ **I'll analyze** - I'll see exactly what's wrong and fix it

---

## QUICK START

**Just run this one command:**

```powershell
cd c:\projects\rlmss; adb logcat | Select-String "BRICKLAYER|AppendixH|ArplToolkit|ERROR"
```

Then in the app:
1. Select bricklayer learner
2. Tap "View Toolkit"
3. Logs will appear showing the exact error

---

## EXPECTED ERRORS WE'RE LOOKING FOR

The error message will tell us:
- Is it JSON parsing failing?
- Is it a specific field causing issues?
- Is it appendixH or another appendix?
- Is it a type mismatch (List vs Map vs String)?

---

Ready to test! Just follow the steps and share the log output.

