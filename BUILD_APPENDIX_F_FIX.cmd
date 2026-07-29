@echo off
echo ========================================
echo Building APK with Appendix F Fix
echo ========================================
echo.

echo Step 1: Cleaning previous build...
call flutter clean
if errorlevel 1 (
    echo ERROR: Flutter clean failed!
    pause
    exit /b 1
)
echo.

echo Step 2: Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: Flutter pub get failed!
    pause
    exit /b 1
)
echo.

echo Step 3: Building release APK...
call flutter build apk --release
if errorlevel 1 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)
echo.

echo ========================================
echo BUILD SUCCESSFUL!
echo ========================================
echo.
echo APK Location:
echo build\app\outputs\flutter-apk\app-release.apk
echo.
echo Next Steps:
echo 1. Upload mobile/save_appendix_f_data.php to server
echo 2. Copy app-release.apk to device
echo 3. Install APK on device
echo 4. Test Appendix F save functionality
echo.
pause
