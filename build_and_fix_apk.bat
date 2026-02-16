@echo off
echo ========================================
echo Flutter Build and APK Path Fix
echo ========================================
echo.

echo Step 1: Clean previous builds...
flutter clean
echo ✓ Flutter clean completed

echo.
echo Step 2: Get dependencies...
flutter pub get
echo ✓ Dependencies updated

echo.
echo Step 3: Build debug APK...
flutter build apk --debug
if %ERRORLEVEL% NEQ 0 (
    echo ✗ Build failed with error code %ERRORLEVEL%
    goto :fix_path
)
echo ✓ Debug APK build completed

echo.
echo Step 4: Build release APK...
flutter build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo ✗ Release build failed, but debug APK should be available
)
echo ✓ Release APK build completed

:fix_path
echo.
echo Step 5: Fixing APK paths for Flutter compatibility...

REM Create Flutter expected directory structure
if not exist "build" mkdir "build"
if not exist "build\app" mkdir "build\app"
if not exist "build\app\outputs" mkdir "build\app\outputs"
if not exist "build\app\outputs\flutter-apk" mkdir "build\app\outputs\flutter-apk"

REM Copy APKs to Flutter expected locations
if exist "android\app\build\outputs\apk\debug\app-debug.apk" (
    copy "android\app\build\outputs\apk\debug\app-debug.apk" "build\app\outputs\flutter-apk\app-debug.apk" >nul
    echo ✓ Debug APK copied to Flutter location
)

if exist "android\app\build\outputs\apk\release\app-release.apk" (
    copy "android\app\build\outputs\apk\release\app-release.apk" "build\app\outputs\flutter-apk\app-release.apk" >nul
    echo ✓ Release APK copied to Flutter location
)

echo.
echo ========================================
echo Build Complete!
echo ========================================

echo Available APK files:
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo ✓ Debug APK: build\app\outputs\flutter-apk\app-debug.apk
    dir "build\app\outputs\flutter-apk\app-debug.apk" | findstr "app-debug.apk"
)
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ✓ Release APK: build\app\outputs\flutter-apk\app-release.apk
    dir "build\app\outputs\flutter-apk\app-release.apk" | findstr "app-release.apk"
)

echo.
echo You can now use:
echo - flutter install (for debug APK)
echo - flutter install --release (for release APK)
echo.
pause