# Debug Log Capture Instructions - Standalone Toolkit

## How to View Real-Time Logs

### Option 1: Using PowerShell (Recommended)
```powershell
# Clear existing logs
adb logcat -c

# Start capturing logs (filtered to [TOOLKIT_DEBUG] messages)
adb logcat | findstr TOOLKIT_DEBUG
```

The window will stay open and show all debug messages as they happen. Perform your test actions in the app while watching these logs.

### Option 2: Save Logs to File
```powershell
# Capture all logs to a file
adb logcat > C:\toolkit_debug.log

# Then stop it with Ctrl+C after you've done your test
# View the file:
Get-Content C:\toolkit_debug.log | findstr TOOLKIT_DEBUG
```

### Option 3: Real-Time with Full Output
```powershell
# See all logs in real-time (not just toolkit debug)
adb logcat
```

## Test Steps to Trigger Debug Logs

1. **Start the logcat capture** in PowerShell before opening the app
2. **Open ARPL Dashboard** in the app
3. **Click "View Complete Toolkit"** from the menu
4. **Watch the logs** - you should see:
   ```
   [TOOLKIT_DEBUG] === _openToolkit called ===
   [TOOLKIT_DEBUG] _selectedLearnerId: [value or null]
   [TOOLKIT_DEBUG] _selectedClassId: [value or null]
   [TOOLKIT_DEBUG] _selectedOfoNumber: [value or null]
   [TOOLKIT_DEBUG] _learners.length: [number]
   ```

5. **Select a learner** from dropdown - watch for:
   ```
   [TOOLKIT_DEBUG] Dropdown onChanged: value=[IDNumber]
   [TOOLKIT_DEBUG] Set _selectedLearnerId=[IDNumber]
   [TOOLKIT_DEBUG] Found learner: [Name] [Surname]
   [TOOLKIT_DEBUG] classID: [value]
   [TOOLKIT_DEBUG] Set _selectedOfoNumber=671101
   ```

6. **Click "Open Complete Toolkit"** button - watch for:
   ```
   [TOOLKIT_DEBUG] === _openToolkit called ===
   [TOOLKIT_DEBUG] _selectedLearnerId: [IDNumber]
   [TOOLKIT_DEBUG] _selectedClassId: [value]
   [TOOLKIT_DEBUG] _selectedOfoNumber: 671101
   [TOOLKIT_DEBUG] _learners.length: [number]
   [TOOLKIT_DEBUG] Searching for learner with IDNumber: [IDNumber]
   [TOOLKIT_DEBUG] Checking learner IDNumber: [value]
   [TOOLKIT_DEBUG] Found learner: [Name] [Surname]
   [TOOLKIT_DEBUG] Learner LearnerID: [ID]
   [TOOLKIT_DEBUG] Learner IDNumber: [IDNumber]
   [TOOLKIT_DEBUG] Learner classID: [value]
   [TOOLKIT_DEBUG] Parsed learnerId: [ID]
   [TOOLKIT_DEBUG] Parsed classId: [value]
   [TOOLKIT_DEBUG] All checks passed, navigating to toolkit
   ```

## Expected vs Actual Behavior

### Expected (If Working)
- After selection, info card shows
- Button click triggers "All checks passed, navigating to toolkit"
- Page navigates to toolkit viewer

### If Error (What to Look For)
- Look for ERROR messages like:
  ```
  [TOOLKIT_DEBUG] ERROR: _selectedLearnerId is null or empty
  [TOOLKIT_DEBUG] ERROR: _selectedClassId is null or empty
  [TOOLKIT_DEBUG] ERROR: No learner found with IDNumber: [value]
  [TOOLKIT_DEBUG] ERROR: learnerId is 0
  ```

## Debug Output Format

All debug messages use the format: `[TOOLKIT_DEBUG]`

This makes them easy to filter in logcat. The logs show:
1. Entry to functions with parameter values
2. State transitions
3. Database query results
4. Parsing results
5. Final navigation decision

## Collecting a Full Log

If you need to share the logs:
```powershell
# Run this BEFORE doing your test
adb logcat > C:\arpl_toolkit_full_log.txt

# Do your test in the app

# Let it run for 30 seconds after clicking button
# Press Ctrl+C to stop capture

# Then send the file C:\arpl_toolkit_full_log.txt
```

## Common Issues to Look For

1. **"No learner found with IDNumber"** → IDNumber column might not exist or has different name
2. **"learnerId is 0"** → LearnerID parsing failed or column doesn't exist
3. **_selectedLearnerId null after selection** → Dropdown onChanged not firing
4. **_selectedClassId empty** → Learner record missing classID field
5. **Navigation not happening** → learner search succeeded but parsing failed

## Next Steps

1. Capture the logs while performing the test
2. Look for the first ERROR line (if any)
3. Share the complete log output starting from the first time you click on menu
4. This will show exactly where the process breaks down
