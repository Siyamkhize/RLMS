# How to Build the App - Simple Instructions

## Option 1: Use the Build Script (EASIEST)

I've created a build script for you. Just double-click this file:

```
build_app.bat
```

It will automatically:
1. Clean the build cache
2. Get dependencies
3. Build and run the app

**Time**: 2-3 minutes

---

## Option 2: Manual Commands

If the script doesn't work, open Command Prompt in your project folder and run:

### Step 1: Clean
```cmd
flutter clean
```
Wait for it to finish (10-20 seconds)

### Step 2: Get Dependencies
```cmd
flutter pub get
```
Wait for it to finish (10-20 seconds)

### Step 3: Build and Run
```cmd
flutter run
```
Wait for build to complete (2-3 minutes)

---

## Option 3: Use Your IDE

### In Android Studio:
1. Click "Stop" button (red square) to stop current app
2. Click "Run" menu → "Flutter Clean"
3. Click "Run" menu → "Flutter Pub Get"
4. Click "Run" button (green play icon)

### In VS Code:
1. Press Ctrl+C in terminal to stop app
2. Type: `flutter clean` and press Enter
3. Type: `flutter pub get` and press Enter
4. Type: `flutter run` and press Enter

---

## What to Expect

### During Build:
```
Running "flutter pub get" in project...
Launching lib\main.dart on Windows in debug mode...
Building Windows application...
```

This takes 2-3 minutes. Be patient!

### After Build:
The app will launch and you should see:
```
[LOAD] ========== LOADING LEARNERS FROM LOCAL DATABASE ==========
[LOAD] Found 33 learners for classID: 134
[LOAD] ========== LOAD SUMMARY ==========
[LOAD] Total unique learners: 33
[LOAD] Clocked IN: X
[LOAD] Clocked OUT: Y
[LOAD] ========== LOAD COMPLETE ==========
```

**No error message!** ✅

---

## Troubleshooting

### If "flutter: command not found":
1. Make sure Flutter is installed
2. Make sure Flutter is in your PATH
3. Restart Command Prompt
4. Try again

### If build fails:
1. Check you're in the correct project folder
2. Make sure no other Flutter app is running
3. Close Android Studio/VS Code
4. Try the manual commands again

### If app doesn't start:
1. Make sure your device/emulator is connected
2. Run: `flutter devices` to see available devices
3. Try: `flutter run -d windows` for Windows
4. Try: `flutter run -d <device-id>` for specific device

---

## Quick Start (Copy-Paste)

Open Command Prompt in your project folder and paste this:

```cmd
flutter clean && flutter pub get && flutter run
```

Press Enter and wait 2-3 minutes.

---

## Summary

**Easiest Way**: Double-click `build_app.bat`
**Manual Way**: Run the 3 commands in Command Prompt
**IDE Way**: Use Run menu in Android Studio/VS Code

**Time Required**: 2-3 minutes
**Result**: App runs with fix applied, no more error!

The fix is ready in the code - you just need to build it! 🚀
