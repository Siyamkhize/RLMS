@echo off
echo Starting Flutter build process...
echo.

echo Step 1: Cleaning previous build...
flutter clean
echo.

echo Step 2: Getting dependencies...
flutter pub get
echo.

echo Step 3: Building APK...
flutter build apk --debug
echo.

echo Build process completed!
echo Check the build/app/outputs/flutter-apk/ directory for the APK file.
pause