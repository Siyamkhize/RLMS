@echo off
echo Rebuilding Flutter App for Facilitator Material Issue Fix
echo ========================================================

echo.
echo Step 1: Cleaning Flutter build cache...
flutter clean

echo.
echo Step 2: Getting Flutter dependencies...
flutter pub get

echo.
echo Step 3: Building APK with updated code...
flutter build apk --debug

echo.
echo Step 4: Checking for build errors...
if %ERRORLEVEL% EQU 0 (
    echo ✓ Build completed successfully!
    echo.
    echo The updated app should now navigate to the correct facilitator material issue page.
    echo APK location: build\app\outputs\flutter-apk\app-debug.apk
) else (
    echo ✗ Build failed with errors!
    echo Please check the error messages above.
)

echo.
echo Build process completed.
pause