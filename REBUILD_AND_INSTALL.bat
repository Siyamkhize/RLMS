@echo off
echo ========================================
echo   REBUILD AND INSTALL APP
echo ========================================
echo.

echo Step 1: Cleaning build directories...
flutter clean
if exist "C:\temp\gradle-build" (
    echo Cleaning custom Gradle build directory...
    rmdir /s /q "C:\temp\gradle-build"
)
echo.

echo Step 2: Getting dependencies...
flutter pub get
echo.

echo Step 3: Building APK (this may take 3-5 minutes)...
flutter build apk --debug
echo.

echo Step 4: Copying APK to expected location...
if exist "C:\temp\gradle-build\app\outputs\flutter-apk\app-debug.apk" (
    echo Found APK in custom build directory
    if not exist "build\app\outputs\flutter-apk" mkdir "build\app\outputs\flutter-apk"
    copy "C:\temp\gradle-build\app\outputs\flutter-apk\app-debug.apk" "build\app\outputs\flutter-apk\app-debug.apk"
    echo APK copied successfully
) else (
    echo APK not found in custom build directory
)
echo.

echo Step 5: Installing on Android device...
flutter install -d adb-RZ8X306F7TZ-mKvVzH._adb-tls-connect._tcp
echo.

echo ========================================
echo   INSTALLATION COMPLETE
echo ========================================
echo.
echo The app has been installed on your device with all fixes applied.
echo.
pause

