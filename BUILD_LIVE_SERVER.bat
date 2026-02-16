@echo off
echo ========================================
echo  BUILDING APK FOR LIVE SERVER
echo  https://rlms.rlms.co.za/
echo ========================================
echo.

cd /d C:\temp\rlmss

echo Step 1: Cleaning Flutter...
call flutter clean
echo.

echo Step 2: Getting dependencies...
call flutter pub get
echo.

echo Step 3: Building APK...
call flutter build apk --release
echo.

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo.
    echo ========================================
    echo  BUILD SUCCESS!
    echo ========================================
    echo.
    echo APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo Server: https://rlms.rlms.co.za/assessorReport2/mobile
    echo.
    copy "build\app\outputs\flutter-apk\app-release.apk" "rlms-live-server.apk"
    echo.
    echo APK also copied to: rlms-live-server.apk
    echo.
    echo Ready to install on device!
    echo.
) else (
    echo.
    echo ========================================
    echo  BUILD FAILED
    echo ========================================
    echo.
    echo Please check error messages above
    echo.
)

pause

