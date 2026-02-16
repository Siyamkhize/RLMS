@echo off
echo Fixing APK path issue for Android Gradle Plugin 8.x...
echo.

REM Check if build directory exists
if not exist "build\app\outputs" (
    echo Error: Build directory not found. Please run 'flutter build apk' first.
    pause
    exit /b 1
)

REM Find the APK in the new AGP 8.x location
set "NEW_APK_PATH=build\app\outputs\apk\debug\app-debug.apk"
set "OLD_APK_PATH=build\app\outputs\flutter-apk\app-debug.apk"

echo Checking for APK in new AGP 8.x location: %NEW_APK_PATH%
if exist "%NEW_APK_PATH%" (
    echo Found APK in new location!
    
    REM Create the flutter-apk directory if it doesn't exist
    if not exist "build\app\outputs\flutter-apk" (
        echo Creating flutter-apk directory...
        mkdir "build\app\outputs\flutter-apk"
    )
    
    REM Copy the APK to the expected location
    echo Copying APK to expected Flutter location...
    copy "%NEW_APK_PATH%" "%OLD_APK_PATH%"
    
    if exist "%OLD_APK_PATH%" (
        echo Success! APK copied to: %OLD_APK_PATH%
        echo.
        echo File size:
        dir "%OLD_APK_PATH%" | findstr "app-debug.apk"
        echo.
        echo You can now find your APK at: %OLD_APK_PATH%
    ) else (
        echo Error: Failed to copy APK
    )
) else (
    echo APK not found in new location. Checking other possible locations...
    
    REM Check release build location
    set "RELEASE_APK_PATH=build\app\outputs\apk\release\app-release.apk"
    if exist "%RELEASE_APK_PATH%" (
        echo Found release APK: %RELEASE_APK_PATH%
        
        if not exist "build\app\outputs\flutter-apk" (
            mkdir "build\app\outputs\flutter-apk"
        )
        
        copy "%RELEASE_APK_PATH%" "build\app\outputs\flutter-apk\app-release.apk"
        echo Release APK copied to flutter-apk directory
    ) else (
        echo No APK found in expected locations.
        echo Please check if the build completed successfully.
        echo.
        echo Expected locations:
        echo - %NEW_APK_PATH%
        echo - %RELEASE_APK_PATH%
        echo - %OLD_APK_PATH%
    )
)

echo.
echo Listing all APK files in build directory:
dir /s build\*.apk 2>nul

pause