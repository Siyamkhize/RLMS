@echo off
echo ========================================
echo APK Path Verification
echo ========================================
echo.

echo Checking APK locations...
echo.

REM Check Android Gradle Plugin locations
echo Android Gradle Plugin locations:
if exist "android\app\build\outputs\apk\debug\app-debug.apk" (
    echo ✓ Debug APK: android\app\build\outputs\apk\debug\app-debug.apk
    dir "android\app\build\outputs\apk\debug\app-debug.apk" | findstr "app-debug.apk"
) else (
    echo ✗ Debug APK not found in AGP location
)

if exist "android\app\build\outputs\apk\release\app-release.apk" (
    echo ✓ Release APK: android\app\build\outputs\apk\release\app-release.apk
    dir "android\app\build\outputs\apk\release\app-release.apk" | findstr "app-release.apk"
) else (
    echo ✗ Release APK not found in AGP location
)

echo.
echo Flutter expected locations:
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo ✓ Debug APK: build\app\outputs\flutter-apk\app-debug.apk
    dir "build\app\outputs\flutter-apk\app-debug.apk" | findstr "app-debug.apk"
) else (
    echo ✗ Debug APK not found in Flutter location
    echo   Run fix_gradle_apk_path.bat to copy APKs
)

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ✓ Release APK: build\app\outputs\flutter-apk\app-release.apk
    dir "build\app\outputs\flutter-apk\app-release.apk" | findstr "app-release.apk"
) else (
    echo ✗ Release APK not found in Flutter location
    echo   Run fix_gradle_apk_path.bat to copy APKs
)

echo.
echo ========================================
echo Verification Complete
echo ========================================
echo.
pause