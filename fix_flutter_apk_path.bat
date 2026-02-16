@echo off
echo Fixing Flutter APK path for AGP 8.x...
echo.

REM The actual APK location (AGP 8.x)
set "ACTUAL_APK=android\app\build\outputs\apk\debug\app-debug.apk"
REM Where Flutter expects to find it
set "FLUTTER_APK=build\app\outputs\flutter-apk\app-debug.apk"

echo Checking for APK in actual build location...
if exist "%ACTUAL_APK%" (
    echo ✓ Found APK: %ACTUAL_APK%
    
    REM Get file size for verification
    for %%A in ("%ACTUAL_APK%") do set "APK_SIZE=%%~zA"
    echo   Size: %APK_SIZE% bytes
    
    REM Create the Flutter expected directory structure
    echo Creating Flutter expected directory structure...
    if not exist "build" mkdir "build"
    if not exist "build\app" mkdir "build\app"
    if not exist "build\app\outputs" mkdir "build\app\outputs"
    if not exist "build\app\outputs\flutter-apk" mkdir "build\app\outputs\flutter-apk"
    
    REM Copy the APK to where Flutter expects it
    echo Copying APK to Flutter expected location...
    copy "%ACTUAL_APK%" "%FLUTTER_APK%"
    
    if exist "%FLUTTER_APK%" (
        echo ✓ Success! APK copied to: %FLUTTER_APK%
        
        REM Verify the copy
        for %%A in ("%FLUTTER_APK%") do set "COPIED_SIZE=%%~zA"
        echo   Copied size: %COPIED_SIZE% bytes
        
        if "%APK_SIZE%"=="%COPIED_SIZE%" (
            echo ✓ File sizes match - copy successful!
        ) else (
            echo ⚠ Warning: File sizes don't match
        )
        
        echo.
        echo Your APK is now available at: %FLUTTER_APK%
        echo Flutter should now be able to find it correctly.
        
    ) else (
        echo ✗ Error: Failed to copy APK to Flutter location
    )
    
) else (
    echo ✗ APK not found at: %ACTUAL_APK%
    echo.
    echo Please run 'flutter build apk' first, then try this script again.
    echo.
    echo Checking for other APK locations...
    
    REM Check release build
    set "ACTUAL_RELEASE=android\app\build\outputs\apk\release\app-release.apk"
    if exist "%ACTUAL_RELEASE%" (
        echo ✓ Found release APK: %ACTUAL_RELEASE%
        echo You can copy this manually if needed.
    )
    
    REM List all APKs in android build directory
    echo.
    echo All APKs in android build directory:
    dir /s android\*.apk 2>nul
)

echo.
pause