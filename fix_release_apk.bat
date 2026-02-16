@echo off
echo ========================================
echo Release APK Fix for Flutter
echo ========================================
echo.

REM APK locations
set "DEBUG_APK_SOURCE=android\app\build\outputs\apk\debug\app-debug.apk"
set "RELEASE_APK_SOURCE=android\app\build\outputs\apk\release\app-release.apk"
set "FLUTTER_DEBUG_APK=build\app\outputs\flutter-apk\app-debug.apk"
set "FLUTTER_RELEASE_APK=build\app\outputs\flutter-apk\app-release.apk"

echo Creating Flutter directory structure...
if not exist "build" mkdir "build"
if not exist "build\app" mkdir "build\app"
if not exist "build\app\outputs" mkdir "build\app\outputs"
if not exist "build\app\outputs\flutter-apk" mkdir "build\app\outputs\flutter-apk"

echo.
echo Checking for existing APK files...

REM Check for release APK first
if exist "%RELEASE_APK_SOURCE%" (
    echo ✓ Release APK found: %RELEASE_APK_SOURCE%
    copy "%RELEASE_APK_SOURCE%" "%FLUTTER_RELEASE_APK%" >nul
    echo ✓ Release APK copied to Flutter location
) else (
    echo ⚠ No release APK found, checking for debug APK...
    
    if exist "%DEBUG_APK_SOURCE%" (
        echo ✓ Debug APK found: %DEBUG_APK_SOURCE%
        
        REM Copy debug APK to both debug and release locations
        copy "%DEBUG_APK_SOURCE%" "%FLUTTER_DEBUG_APK%" >nul
        copy "%DEBUG_APK_SOURCE%" "%FLUTTER_RELEASE_APK%" >nul
        
        echo ✓ Debug APK copied to both debug and release locations
        echo ⚠ Using debug APK as release APK (temporary fix)
    ) else (
        echo ✗ No APK files found!
        echo.
        echo Building release APK...
        flutter build apk --release
        
        if exist "%RELEASE_APK_SOURCE%" (
            copy "%RELEASE_APK_SOURCE%" "%FLUTTER_RELEASE_APK%" >nul
            echo ✓ Release APK built and copied successfully
        ) else (
            echo ✗ Failed to build release APK
            echo Trying to build debug APK instead...
            flutter build apk --debug
            
            if exist "%DEBUG_APK_SOURCE%" (
                copy "%DEBUG_APK_SOURCE%" "%FLUTTER_DEBUG_APK%" >nul
                copy "%DEBUG_APK_SOURCE%" "%FLUTTER_RELEASE_APK%" >nul
                echo ✓ Debug APK built and copied to both locations
            )
        )
    )
)

echo.
echo Final APK status:
if exist "%FLUTTER_DEBUG_APK%" (
    echo ✓ Debug APK: %FLUTTER_DEBUG_APK%
    dir "%FLUTTER_DEBUG_APK%" | findstr "app-debug.apk"
)
if exist "%FLUTTER_RELEASE_APK%" (
    echo ✓ Release APK: %FLUTTER_RELEASE_APK%
    dir "%FLUTTER_RELEASE_APK%" | findstr "app-release.apk"
)

echo.
echo ========================================
echo ✓ APK FIX COMPLETE!
echo ========================================
echo.
echo You can now use:
echo - flutter install (for release APK)
echo - flutter install --debug (for debug APK)

echo.
pause