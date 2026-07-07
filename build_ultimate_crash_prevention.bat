@echo off
echo ========================================
echo ULTIMATE Document Scanner Crash Prevention
echo Build and Deploy Script
echo ========================================
echo.

echo Step 1: Cleaning previous build...
flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Flutter clean failed!
    pause
    exit /b 1
)

echo Step 2: Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Flutter pub get failed!
    pause
    exit /b 1
)

echo Step 3: Analyzing code for errors...
flutter analyze
if %errorlevel% neq 0 (
    echo WARNING: Flutter analyze found issues, but continuing...
)

echo Step 4: Building APK with ultimate crash prevention...
flutter build apk --release
if %errorlevel% neq 0 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ BUILD SUCCESSFUL!
echo ========================================
echo.
echo ULTIMATE Crash Prevention System Features:
echo ✅ Memory leak prevention
echo ✅ Plugin state reset after 3 scans  
echo ✅ Aggressive cleanup between scans
echo ✅ Critical state detection
echo ✅ User-friendly warnings and recovery
echo.
echo APK Location: build\app\outputs\flutter-apk\app-release.apk
echo.
echo TESTING INSTRUCTIONS:
echo 1. Install the fresh APK
echo 2. Test scanning 5+ documents in sequence
echo 3. Verify system shows warnings at scan 3
echo 4. Verify automatic reset after scan 3
echo 5. Verify NO CRASHES occur
echo.
echo The scanner should now work reliably for unlimited scans!
echo.
pause