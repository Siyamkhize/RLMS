@echo off
echo Copying APK to Flutter expected path...
echo.

REM Source: where AGP 8.x actually builds the APK
set "SOURCE=android\app\build\outputs\apk\debug\app-debug.apk"
REM Target: where Flutter expects to find it
set "TARGET=build\app\outputs\flutter-apk\app-debug.apk"

if exist "%SOURCE%" (
    echo ✓ Found APK: %SOURCE%
    
    REM Create target directory
    if not exist "build\app\outputs\flutter-apk" (
        echo Creating target directory...
        mkdir "build\app\outputs\flutter-apk"
    )
    
    REM Copy the file
    copy "%SOURCE%" "%TARGET%"
    
    if exist "%TARGET%" (
        echo ✓ APK copied successfully to: %TARGET%
        echo.
        echo File details:
        dir "%TARGET%" | findstr "app-debug.apk"
    ) else (
        echo ✗ Copy failed
    )
    
) else (
    echo ✗ APK not found at: %SOURCE%
    echo Please build your APK first with: flutter build apk
)

echo.
pause