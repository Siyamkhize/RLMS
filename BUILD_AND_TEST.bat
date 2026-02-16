@echo off
cls
echo ========================================
echo   BUILD AND TEST - ALL FIXES
echo ========================================
echo.
echo This will:
echo  1. Clean build directories
echo  2. Get dependencies
echo  3. Build debug APK
echo  4. Show what to test
echo.
pause
echo.

echo Step 1: Cleaning...
call flutter clean
echo.

echo Step 2: Getting dependencies...
call flutter pub get
echo.

echo Step 3: Building debug APK...
call flutter build apk --debug
echo.

echo ========================================
echo   BUILD COMPLETE!
echo ========================================
echo.
echo 📋 WHAT TO TEST:
echo.
echo 1. LEARNER CLOCKING:
echo    - Clock in online → Should show "synced to server" (green)
echo    - Clock in offline → Should show "saved locally" (orange)
echo.
echo 2. FACILITATOR ENROLLMENT:
echo    - Enroll fingerprint → Check DB has template
echo    - Press REFRESH → Template should NOT be deleted
echo    - Check SQL: SELECT LENGTH(zkteco_left_template) FROM facilitator WHERE facilitator_id=?
echo.
echo 3. FACILITATOR CLOCK-IN:
echo    - After enrollment, tap "Clock In"
echo    - Place finger → Should verify and clock in
echo    - Check DB: SELECT * FROM facilitator_clocking WHERE facilitator_id=?
echo.
echo 4. ATTENDANCE COUNT:
echo    - Clock in several learners
echo    - Check dashboard shows correct count (only today)
echo.
echo 5. DATABASE CLEANUP:
echo    - Check only current day records remain
echo    - Induction records NOT deleted
echo.
echo ========================================
echo   SQL QUERIES TO RUN:
echo ========================================
echo.
echo -- Check learner clocking
echo SELECT COUNT(*), synced FROM learner_clocking WHERE clock_date = CURDATE() GROUP BY synced;
echo.
echo -- Check facilitator templates (SHOULD NOT BE NULL after refresh!)
echo SELECT facilitator_id, LENGTH(zkteco_left_template) FROM facilitator;
echo.
echo -- Check facilitator clocking
echo SELECT * FROM facilitator_clocking WHERE clock_date = CURDATE();
echo.
echo ========================================
echo   CONSOLE LOGS TO LOOK FOR:
echo ========================================
echo.
echo ✅ [CLOCK_IN] ✅ Clock-in synced to server successfully
echo ✅ [DB] Preserving existing fingerprint templates
echo ✅ [DB] ✅ Preserved fingerprint templates during update
echo ✅ [FAC_CLOCK] ✅ ZKTeco verification successful!
echo.
echo ========================================
pause

