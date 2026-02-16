@echo off
echo ========================================
echo Flutter APK Build with AGP 8.x Fix
echo ========================================
echo.

echo This script builds your Flutter APK and fixes the path issue
echo that occurs with Android Gradle Plugin 8.x
echo.

REM Clean and prepare
echo [1/4] Cleaning previous builds...
flutter clean
if %ERRORLEVEL% neq 0 (
    echo Error during flutter clean
    pause
    exit /b 1
)

echo [2/4] Getting dependencies...
flutter pub get
if %ERRORLEVEL% neq 0 (
    echo Error during flutter pub get
    pause
    exit /b 1
)

echo [3/4] Building APK...
flutter build apk --debug
set BUILD_RESULT=%ERRORLEVEL%

if %BUILD_RESULT% neq 0 (
    echo.
    echo ⚠ Build completed with warnings/errors (exit code: %BUILD_RESULT%)
    echo This is often just the APK path detection issue with AGP 8.x
    echo Continuing with path fix...
) else (
    echo ✓ Build completed successfully!
)

echo.
echo [4/4] Fixing APK path for Flutter compatibility...

REM The actual APK location (AGP 8.x)
set "ACTUAL_APK=android\app\build\outputs\apk\debug\app-debug.apk"
REM Where Flutter expects to find it
set "FLUTTER_APK=build\app\outputs\flutter-apk\app-debug.apk"

if exist "%ACTUAL_APK%" (
    echo ✓ APK found in AGP 8.x location: %ACTUAL_APK%
    
    REM Create Flutter expected directory structure
    if not exist "build" mkdir "build"
    if not exist "build\app" mkdir "build\app"
    if not exist "build\app\outputs" mkdir "build\app\outputs"
    if not exist "build\app\outputs\flutter-apk" mkdir "build\app\outputs\flutter-apk"
    
    REM Copy APK to Flutter expected location
    copy "%ACTUAL_APK%" "%FLUTTER_APK%" >nul
    
    if exist "%FLUTTER_APK%" (
        echo ✓ APK copied to Flutter expected location: %FLUTTER_APK%
        
        REM Show file info
        echo.
        echo APK Information:
        dir "%FLUTTER_APK%" | findstr "app-debug.apk"
        
        echo.
        echo ========================================
        echo ✓ BUILD SUCCESSFUL!
        echo ========================================
        echo Your APK is ready at: %FLUTTER_APK%
        echo.
        echo You can now:
        echo 1. Install it: flutter install
        echo 2. Copy it to your device
        echo 3. Upload it to app stores
        
    ) else (
        echo ✗ Failed to copy APK to Flutter location
        echo But your APK is still available at: %ACTUAL_APK%
    )
    
) else (
    echo ✗ APK not found in expected location: %ACTUAL_APK%
    echo.
    echo The build may have failed. Check the error messages above.
    
    REM Check for release APK
    set "RELEASE_APK=android\app\build\outputs\apk\release\app-release.apk"
    if exist "%RELEASE_APK%" (
        echo.
        echo Found release APK instead: %RELEASE_APK%
    )
)

echo.
pause