@echo off
echo ========================================
echo APK Path Fix for Flutter
echo ========================================
echo.

REM The actual APK location (AGP 8.x)
set "ACTUAL_APK=android\app\build\outputs\apk\debug\app-debug.apk"
REM Where Flutter expects to find it
set "FLUTTER_APK=build\app\outputs\flutter-apk\app-debug.apk"

echo Checking for APK files...

if exist "%ACTUAL_APK%" (
    echo ✓ APK found in AGP 8.x location: %ACTUAL_APK%
    
    REM Create Flutter expected directory structure
    echo Creating Flutter directory structure...
    if not exist "build" mkdir "build"
    if not exist "build\app" mkdir "build\app"
    if not exist "build\app\outputs" mkdir "build\app\outputs"
    if not exist "build\app\outputs\flutter-apk" mkdir "build\app\outputs\flutter-apk"
    
    REM Copy APK to Flutter expected location
    echo Copying APK to Flutter expected location...
    copy "%ACTUAL_APK%" "%FLUTTER_APK%" >nul
    
    if exist "%FLUTTER_APK%" (
        echo ✓ APK copied successfully to: %FLUTTER_APK%
        
        REM Show file info
        echo.
        echo APK Information:
        dir "%FLUTTER_APK%" | findstr "app-debug.apk"
        
        echo.
        echo ========================================
        echo ✓ APK PATH FIX SUCCESSFUL!
        echo ========================================
        echo Your APK is now available at: %FLUTTER_APK%
        echo.
        echo You can now use: flutter install
        
    ) else (
        echo ✗ Failed to copy APK to Flutter location
        echo But your APK is still available at: %ACTUAL_APK%
    )
    
) else (
    echo ✗ APK not found in expected location: %ACTUAL_APK%
    echo.
    echo Please run 'flutter build apk --debug' first
    
    REM Check if there's an APK in flutter-apk directory already
    if exist "android\app\build\outputs\flutter-apk\app-debug.apk" (
        echo.
        echo Found APK in flutter-apk directory already!
        copy "android\app\build\outputs\flutter-apk\app-debug.apk" "%FLUTTER_APK%" >nul
        echo ✓ APK copied from flutter-apk directory
    )
)

echo.
pause