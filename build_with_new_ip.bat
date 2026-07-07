@echo off
echo ========================================
echo  Building APK with IP: 192.168.68.112
========================================
echo.

cd /d C:\projects\rlmss

echo Cleaning previous build...
call flutter clean
echo.

echo Getting dependencies...
call flutter pub get
echo.

echo Building APK...
call flutter build apk --debug
echo.

if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo.
    echo ========================================
    echo  BUILD SUCCESS!
    echo ========================================
    echo.
    echo APK Location: build\app\outputs\flutter-apk\app-debug.apk
    echo IP Address: 192.168.68.112:8080
    echo.
    copy "build\app\outputs\flutter-apk\app-debug.apk" "app-debug-192.168.68.112.apk"
    echo.
    echo APK also copied to: app-debug-192.168.68.112.apk
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

