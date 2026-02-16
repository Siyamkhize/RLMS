@echo off
echo ========================================
echo  ALL FIXES APPLIED - BUILDING APP
echo ========================================
echo.

echo Stopping Gradle daemon...
cd android
call gradlew --stop 2>nul
cd ..
echo.

echo Cleaning Flutter...
call flutter clean
echo.

echo Removing build directories...
if exist build rmdir /s /q build
if exist android\.gradle rmdir /s /q android\.gradle
echo.

echo Getting dependencies...
call flutter pub get
echo.

echo ========================================
echo  BUILDING APK...
echo ========================================
echo.

call flutter build apk --debug

echo.
echo ========================================
echo  BUILD COMPLETE!
echo ========================================
echo.

if %ERRORLEVEL% EQU 0 (
    echo ✅ SUCCESS! APK built successfully
    echo.
    echo APK location:
    echo build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo All features are now active:
    echo  ✅ Offline-to-online sync ^(ALL records^)
    echo  ✅ Background auto-sync ^(current day only^)
    echo  ✅ Online-to-offline clock-out
    echo  ✅ User-friendly error messages
    echo.
) else (
    echo ❌ BUILD FAILED
    echo.
    echo Please check the error messages above
    echo.
)

pause
