@echo off
cls
echo ========================================
echo  NUCLEAR CLEAN - AGGRESSIVE FIX
echo ========================================
echo.
echo This will:
echo  - Kill all Dart/Java processes
echo  - Delete all build caches
echo  - Rebuild from scratch
echo.
pause
echo.

echo Step 1: Killing processes...
taskkill /F /IM dart.exe /T 2>nul
taskkill /F /IM java.exe /T 2>nul
timeout /t 2 /nobreak >nul

echo Step 2: Stopping Gradle...
cd android
call gradlew --stop 2>nul
cd ..

echo Step 3: Flutter clean...
call flutter clean

echo Step 4: Deleting build directories...
if exist build rmdir /s /q build
if exist android\.gradle rmdir /s /q android\.gradle
if exist android\app\build rmdir /s /q android\app\build
if exist .dart_tool rmdir /s /q .dart_tool
if exist .flutter-plugins rmdir /s /q .flutter-plugins

echo Step 5: Getting dependencies...
call flutter pub get

echo Step 6: Building APK...
echo.
call flutter build apk --debug

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo  ✅ BUILD SUCCESSFUL!
    echo ========================================
) else (
    echo.
    echo ========================================
    echo  ❌ STILL FAILING
    echo ========================================
    echo.
    echo The issue is not build cache.
    echo We need to revert some code changes.
    echo.
)

pause
