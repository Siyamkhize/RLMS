@echo off
echo ========================================
echo Flutter Clean Build Script
echo ========================================
echo.

echo Step 1: Cleaning Flutter build cache...
flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Flutter clean failed!
    pause
    exit /b 1
)
echo ✓ Clean completed
echo.

echo Step 2: Getting Flutter dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Flutter pub get failed!
    pause
    exit /b 1
)
echo ✓ Dependencies downloaded
echo.

echo Step 3: Running Flutter app...
echo NOTE: This will start the app. Watch the console for debug messages!
echo.
flutter run
if %errorlevel% neq 0 (
    echo ERROR: Flutter run failed!
    pause
    exit /b 1
)

pause
