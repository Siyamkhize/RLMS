@echo off
echo ========================================
echo Building Fixed App - Correct Total Count
echo ========================================
echo.

echo Cleaning previous build...
flutter clean

echo.
echo Getting dependencies...
flutter pub get

echo.
echo Building APK with fixed total count...
flutter build apk --release

echo.
echo ========================================
echo Build Complete!
echo ========================================
echo.
echo APK Location: build\app\outputs\flutter-apk\app-release.apk
echo.
echo Next Steps:
echo 1. Install the APK on your device
echo 2. Open Moderation Sampling page
echo 3. Verify "Total Learners with POE" shows 1571 (not 273)
echo.
pause
