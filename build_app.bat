@echo off
echo ========================================
echo Building Flutter App
echo ========================================
echo.

echo Step 1: Cleaning...
call flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Flutter clean failed
    pause
    exit /b 1
)
echo Clean complete!
echo.

echo Step 2: Getting dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Pub get failed
    pause
    exit /b 1
)
echo Dependencies retrieved!
echo.

echo Step 3: Building APK (this may take a few minutes)...
call flutter build apk --debug
if %errorlevel% neq 0 (
    echo ERROR: Build failed
    echo Check the error messages above
    pause
    exit /b 1
)

echo.
echo ========================================
echo BUILD SUCCESSFUL!
echo ========================================
echo APK Location: build\app\outputs\flutter-apk\app-debug.apk
echo.
pause

