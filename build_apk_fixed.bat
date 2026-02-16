@echo off
echo Building Flutter APK with AGP 8.x path fix...
echo.

REM Clean previous builds
echo Cleaning previous builds...
flutter clean
flutter pub get

echo.
echo Building APK...
flutter build apk --debug

REM Check build result
if %ERRORLEVEL% neq 0 (
    echo Build failed with error code %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Build completed! Now fixing APK path...

REM Run the APK path fix
call fix_apk_path.bat

echo.
echo Build and path fix complete!
echo Your APK should now be available in the correct location.

pause