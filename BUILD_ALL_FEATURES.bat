@echo off
cls
echo ========================================
echo   COMPLETE BUILD - ALL FEATURES
echo ========================================
echo.
echo ✅ All Features Implemented and Active:
echo.
echo 1. Offline-to-Online Sync
echo    - Syncs ALL offline records when online
echo    - Deletes old synced records
echo    - Keeps current day for offline access
echo.
echo 2. Background Auto-Sync
echo    - Every 15 minutes
echo    - Current day only
echo    - Efficient and fast
echo.
echo 3. Online-to-Offline Fetch
echo    - Current day only from server
echo    - Seamless clock-out
echo.
echo 4. User-Friendly Errors
echo    - Clear fingerprint messages
echo    - No system error codes
echo.
echo 5. Daily Cleanup
echo    - Automatic on app startup
echo    - Keeps ONLY current day locally
echo    - Fresh start every day
echo.
echo 6. Random Biometric Monitoring ⭐ NEW!
echo    - Background checking (30s interval)
echo    - Phone vibration + notifications
echo    - Full-screen verification prompts
echo    - Countdown timers
echo    - Prevents attendance fraud
echo.
pause
echo.

echo Step 1: Stopping Gradle...
cd android
call gradlew --stop 2>nul
cd ..

echo Step 2: Cleaning...
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
    echo 📊 Active Features:
    echo.
    echo [Sync System]
    echo ✅ Offline sync: ALL records
    echo ✅ Background sync: Current day only
    echo ✅ Auto-cleanup: Previous days deleted
    echo ✅ Smart deletion: Old records removed after sync
    echo ✅ Current day kept: Always available offline
    echo.
    echo [Monitoring System] ⭐
    echo ✅ Background checks: Every 30 seconds
    echo ✅ Phone vibration: When prompt arrives
    echo ✅ Notifications: Cannot be dismissed
    echo ✅ Full-screen prompt: With countdown timer
    echo ✅ Fingerprint verify: Required to dismiss
    echo.
    echo [User Experience]
    echo ✅ Error messages: User-friendly
    echo ✅ Offline support: Seamless transitions
    echo ✅ Daily cleanup: Automatic
    echo.
    echo 📱 Local Database:
    echo    - ONLY current day records
    echo    - Cleaned on every app start
    echo    - Minimal storage usage
    echo.
    echo 💾 Server Database:
    echo    - ALL historical records
    echo    - Complete audit trail
    echo    - Monitoring compliance tracking
    echo.
    echo 🎯 Setup Monitoring:
    echo    1. Create monitoring table (SQL provided)
    echo    2. Upload PHP files to server
    echo    3. Test with: create_monitoring_prompt.php
    echo    4. See: MONITORING_SYSTEM_ENABLED.md
    echo.
) else (
    echo ========================================
    echo   ❌ BUILD FAILED
    echo ========================================
    echo.
    echo Check error messages above.
    echo.
    echo Common issues:
    echo - Missing dependencies (run: flutter pub get)
    echo - Gradle memory issues (check gradle.properties)
    echo - Java version (needs JDK 17 or higher)
    echo.
)

pause
