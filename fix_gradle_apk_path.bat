@echo off
echo ========================================
echo Flutter Gradle APK Path Fix
echo ========================================
echo.

REM Set paths
set "DEBUG_APK_SOURCE=android\app\build\outputs\apk\debug\app-debug.apk"
set "RELEASE_APK_SOURCE=android\app\build\outputs\apk\release\app-release.apk"
set "FLUTTER_DEBUG_TARGET=build\app\outputs\flutter-apk\app-debug.apk"
set "FLUTTER_RELEASE_TARGET=build\app\outputs\flutter-apk\app-release.apk"

echo Creating Flutter expected directory structure...
if not exist "build" mkdir "build"
if not exist "build\app" mkdir "build\app"
if not exist "build\app\outputs" mkdir "build\app\outputs"
if not exist "build\app\outputs\flutter-apk" mkdir "build\app\outputs\flutter-apk"

echo.
echo Checking for APK files...

REM Handle debug APK
if exist "%DEBUG_APK_SOURCE%" (
    echo ✓ Debug APK found: %DEBUG_APK_SOURCE%
    copy "%DEBUG_APK_SOURCE%" "%FLUTTER_DEBUG_TARGET%" >nul
    if exist "%FLUTTER_DEBUG_TARGET%" (
        echo ✓ Debug APK copied to Flutter location
    )
) else (
    echo ✗ Debug APK not found at: %DEBUG_APK_SOURCE%
)

REM Handle release APK
if exist "%RELEASE_APK_SOURCE%" (
    echo ✓ Release APK found: %RELEASE_APK_SOURCE%
    copy "%RELEASE_APK_SOURCE%" "%FLUTTER_RELEASE_TARGET%" >nul
    if exist "%FLUTTER_RELEASE_TARGET%" (
        echo ✓ Release APK copied to Flutter location
    )
) else (
    echo ✗ Release APK not found at: %RELEASE_APK_SOURCE%
)

echo.
echo ========================================
echo APK Path Fix Complete!
echo ========================================

REM Show available APKs
echo Available APK files:
if exist "%FLUTTER_DEBUG_TARGET%" (
    echo ✓ Debug APK: %FLUTTER_DEBUG_TARGET%
    dir "%FLUTTER_DEBUG_TARGET%" | findstr "app-debug.apk"
)
if exist "%FLUTTER_RELEASE_TARGET%" (
    echo ✓ Release APK: %FLUTTER_RELEASE_TARGET%
    dir "%FLUTTER_RELEASE_TARGET%" | findstr "app-release.apk"
)

echo.
echo You can now use:
echo - flutter install (for debug APK)
echo - flutter install --release (for release APK)
echo.
pause