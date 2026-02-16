@echo off
echo FORCE COMPLETE REBUILD - Facilitator Material Issue Fix
echo ======================================================

echo.
echo Step 1: Stopping any running Flutter processes...
taskkill /f /im flutter.exe 2>nul
taskkill /f /im dart.exe 2>nul

echo.
echo Step 2: Cleaning ALL Flutter caches...
flutter clean

echo.
echo Step 3: Removing build directory completely...
if exist build rmdir /s /q build

echo.
echo Step 4: Removing .dart_tool directory...
if exist .dart_tool rmdir /s /q .dart_tool

echo.
echo Step 5: Getting fresh dependencies...
flutter pub get

echo.
echo Step 6: Building fresh APK...
flutter build apk --debug --verbose

echo.
echo Step 7: Checking build result...
if %ERRORLEVEL% EQU 0 (
    echo ✓ COMPLETE REBUILD SUCCESSFUL!
    echo.
    echo The app should now show the correct facilitator material issue page.
    echo Debug messages will appear in the console when you navigate.
    echo.
    echo APK location: build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo IMPORTANT: 
    echo 1. Uninstall the old app from your device first
    echo 2. Install the new APK
    echo 3. Check the console/logs for debug messages when navigating
) else (
    echo ✗ BUILD FAILED!
    echo Please check the error messages above.
)

echo.
echo Process completed.
pause