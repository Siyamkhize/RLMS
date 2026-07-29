# BRICKLAYER TOOLKIT - DETAILED TRACE LOG INSTRUCTIONS

## Updated APK Installed with Full Trace Logging

The new APK has comprehensive logging for debugging. Follow these steps to capture the error trace:

---

## STEP 1: Start Capturing Logs

Open PowerShell and run:
```powershell
cd c:\projects\rlmss
adb logcat > bricklayer_trace_logs.txt
```

Keep this window open - it will capture all logs in real-time.

---

## STEP 2: Trigger the Error in the App

1. On the device, open the RLMSS app
2. Log in
3. Navigate to where you can select a bricklayer learner
4. Select a bricklayer learner
5. Tap "View Toolkit"
6. **Error will appear** - This triggers the logging

---

## STEP 3: Stop the Logs

After the error appears (after ~5 seconds), go back to PowerShell and press:
```
Ctrl+C
```

This will save all logs to `bricklayer_trace_logs.txt`

---

## STEP 4: Check the Logs

The file `bricklayer_trace_logs.txt` will be created in `c:\projects\rlmss\`

Look for lines starting with:
- `[BRICKLAYER_TRACE]` - Detailed trace information
- `[BRICKLAYER_ERROR]` - Error messages
- `[ArplToolkitData.fromJson]` - Model parsing trace
- `[AppendixHData.fromJson]` - AppendixH parsing trace

---

## WHAT THE LOGS WILL SHOW

The logs will reveal:
1. **API Response** - The exact JSON being sent from PHP
2. **Type Information** - What types each field is
3. **Parsing Steps** - Exactly where parsing fails
4. **Stack Trace** - Full error stack trace

---

## EXAMPLE LOG OUTPUT YOU'LL SEE

```
[BRICKLAYER_TRACE] API Response Status: 200
[BRICKLAYER_TRACE] API Response Length: 2345 bytes
[BRICKLAYER_TRACE] ═══ RAW API RESPONSE ═══
[BRICKLAYER_TRACE] {"status":"success",...JSON content...}
[BRICKLAYER_TRACE] ═══ END RAW RESPONSE ═══
[BRICKLAYER_TRACE] ═══ TYPE CHECKING ═══
[BRICKLAYER_TRACE] appendixH type: _InternalLinkedHashMap<String, dynamic>
[BRICKLAYER_TRACE] appendixH.items type: List<dynamic>
[BRICKLAYER_TRACE] appendixH.recommendations type: ...
[ArplToolkitData.fromJson] ═══ STARTING ═══
[ArplToolkitData.fromJson] Parsing learner...
...
[AppendixHData.fromJson] ═══ ENTERING ═══
[BRICKLAYER_ERROR] ═══ PARSE ERROR ═══
[BRICKLAYER_ERROR] Error: ...
[BRICKLAYER_ERROR] Stack Trace: ...
```

---

## SEND ME THE LOGS

Once you have the file, please:
1. Copy the entire `bricklayer_trace_logs.txt` file
2. Share it with me in the next message
3. Or paste the relevant [BRICKLAYER_ERROR] and [AppendixHData.fromJson] sections

---

## ALTERNATIVE: Real-time View

If you want to see logs in real-time without saving:

```powershell
adb logcat | Select-String "BRICKLAYER|AppendixH|ArplToolkit"
```

This shows only the relevant logs as they happen.

---

## QUICK COMMAND REFERENCE

```powershell
# Start logging everything
adb logcat > logs.txt

# View logs in real-time (filtered)
adb logcat | Select-String "BRICKLAYER"

# Clear old logs before testing
adb logcat -c

# View only errors
adb logcat | Select-String "ERROR"
```

---

Once you run the test and get the logs, I'll be able to see exactly what's wrong and fix it!

