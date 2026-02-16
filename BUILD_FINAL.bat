@echo off
cls
echo ========================================
echo   FINAL BUILD - ALL FEATURES READY
echo ========================================
echo.
echo Features Implemented:
echo  ✅ Offline-to-online sync (ALL records)
echo  ✅ Background sync (current day only)
echo  ✅ Online-to-offline fetch (current day)
echo  ✅ User-friendly error messages
echo  ✅ Auto-cleanup (keep only current day)
echo  ✅ Smart deletion (old synced records)
echo.
pause
echo.

echo Step 1: Stopping Gradle...
cd android
call gradlew --stop 2>nul
cd ..

echo Step 2: Deep cleaning...
call flutter clean

echo Step 3: Removing build directories...
if exist build rmdir /s /q build
if exist android\.gradle rmdir /s /q android\.gradle

echo Step 4: Getting dependencies...
call flutter pub get

echo.
echo ========================================
echo   BUILDING APK...
echo ========================================
echo.

call flutter build apk --debug

echo.
if %ERRORLEVEL% EQU 0 (
    echo ========================================
    echo   ✅ BUILD SUCCESSFUL!
    echo ========================================
    echo.
    echo APK Location:
    echo build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo 📊 What's Active:
    echo.
    echo 1. Offline Sync:
    echo    - Clock in/out offline → Syncs ALL when online
    echo    - Old records deleted after sync
    echo    - Today's records kept for offline access
    echo.
    echo 2. Background Sync:
    echo    - Every 15 minutes
    echo    - Only syncs current day
    echo    - Efficient and fast
    echo.
    echo 3. Daily Cleanup:
    echo    - App startup deletes old records
    echo    - Keeps ONLY current day locally
    echo    - Fresh start every day
    echo.
    echo 4. User-Friendly Errors:
    echo    - Clear fingerprint error messages
    echo    - No more system errors
    echo.
    echo 📱 Local Database:
    echo    - Contains ONLY current day records
    echo    - Cleaned automatically on startup
    echo    - Minimal storage usage
    echo.
    echo 💾 Server Database:
    echo    - Contains ALL historical records
    echo    - Complete audit trail
    echo    - Permanent storage
    echo.
) else (
    echo ========================================
    echo   ❌ BUILD FAILED
    echo ========================================
    echo.
    echo Please check error messages above.
    echo.
)

pause
