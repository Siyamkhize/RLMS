# Quick Debug Setup - Run This Now

## One-Command Setup

Open PowerShell and run this command:

```powershell
adb logcat | findstr TOOLKIT_DEBUG
```

**That's it!** The window will display debug messages in real-time.

## What You'll See

When you test the toolkit in the app, you'll see messages like:

```
[TOOLKIT_DEBUG] === _openToolkit called ===
[TOOLKIT_DEBUG] _selectedLearnerId: 9603125720088
[TOOLKIT_DEBUG] _selectedClassId: null
[TOOLKIT_DEBUG] _selectedOfoNumber: null
[TOOLKIT_DEBUG] _learners.length: 5
```

These show the exact state of variables when the button is clicked.

## Test Flow

1. **Open PowerShell → Run the command above** (logcat will wait for messages)
2. **Open the app → Go to ARPL Dashboard**
3. **Click "View Complete Toolkit"**
4. **Select a candidate from dropdown** → Watch logs
5. **Click "Open Complete Toolkit" button** → Watch for error messages
6. **Share the log output** if there's an error

## To Stop Capturing

Press `Ctrl+C` in the PowerShell window

## See Full Details

For more options and detailed instructions, see:
[DEBUG_LOG_CAPTURE_INSTRUCTIONS.md](./DEBUG_LOG_CAPTURE_INSTRUCTIONS.md)

## APK Status

✅ **Latest APK installed with debug logging**
- Location: `build/app/outputs/flutter-apk/app-debug.apk`
- Build time: 31.7 seconds
- Installation: Success

Ready to capture logs!
