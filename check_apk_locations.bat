@echo off
echo Checking APK locations for AGP 8.x compatibility...
echo.

echo Current directory: %CD%
echo.

echo Checking all possible APK locations:
echo.

REM Check new AGP 8.x debug location
set "NEW_DEBUG=build\app\outputs\apk\debug\app-debug.apk"
echo 1. New AGP 8.x debug location: %NEW_DEBUG%
if exist "%NEW_DEBUG%" (
    echo    ✓ FOUND
    dir "%NEW_DEBUG%" | findstr "app-debug.apk"
) else (
    echo    ✗ Not found
)
echo.

REM Check new AGP 8.x release location
set "NEW_RELEASE=build\app\outputs\apk\release\app-release.apk"
echo 2. New AGP 8.x release location: %NEW_RELEASE%
if exist "%NEW_RELEASE%" (
    echo    ✓ FOUND
    dir "%NEW_RELEASE%" | findstr "app-release.apk"
) else (
    echo    ✗ Not found
)
echo.

REM Check old Flutter expected location
set "OLD_DEBUG=build\app\outputs\flutter-apk\app-debug.apk"
echo 3. Old Flutter expected location: %OLD_DEBUG%
if exist "%OLD_DEBUG%" (
    echo    ✓ FOUND
    dir "%OLD_DEBUG%" | findstr "app-debug.apk"
) else (
    echo    ✗ Not found (this is where Flutter looks)
)
echo.

REM Check root directory APKs
echo 4. Root directory APKs:
if exist "*.apk" (
    dir *.apk
) else (
    echo    ✗ No APK files in root directory
)
echo.

REM List all APK files recursively
echo 5. All APK files in project:
dir /s *.apk 2>nul
if %ERRORLEVEL% neq 0 (
    echo    ✗ No APK files found anywhere in project
)

echo.
echo ========================================
echo DIAGNOSIS:
echo ========================================
if exist "%NEW_DEBUG%" (
    echo ✓ Your APK was built successfully in the new AGP 8.x location
    echo ✓ Run 'fix_apk_path.bat' to copy it to where Flutter expects it
) else if exist "%NEW_RELEASE%" (
    echo ✓ Your release APK was built successfully
    echo ✓ Run 'fix_apk_path.bat' to copy it to the Flutter location
) else if exist "%OLD_DEBUG%" (
    echo ✓ APK is already in the correct location
) else (
    echo ✗ No APK found - you may need to run 'flutter build apk' first
)

pause