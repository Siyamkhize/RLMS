@echo off
echo ========================================
echo TEST STRATIFICATION FIX
echo ========================================
echo.
echo This will help you test the unit standard extraction fix.
echo.
echo ========================================
echo TEST SEQUENCE:
echo ========================================
echo.
echo 1. Check MySQL Version
echo    URL: http://your-server.com/check_server_version.php
echo.
echo 2. Verify Fix is Working
echo    URL: http://your-server.com/verify_unit_standard_fix.php?moderator_id=77
echo.
echo 3. Test Extraction Logic
echo    URL: http://your-server.com/test_unit_standard_extraction_fixed.php?moderator_id=77^&learner_id=1231
echo.
echo 4. Test Temp Tables Logic
echo    URL: http://your-server.com/test_temp_tables_logic.php?moderator_id=77
echo.
echo 5. Test API Endpoint
echo    URL: http://your-server.com/get_learners_with_poe_assigned.php?moderator_id=77
echo.
echo ========================================
echo WHAT TO CHECK:
echo ========================================
echo.
echo Step 1 - MySQL Version:
echo   - Shows MySQL/MariaDB version
echo   - Shows if REGEXP_SUBSTR is supported
echo   - Shows which extraction method will be used
echo.
echo Step 2 - Verify Fix:
echo   - Quick diagnostic
echo   - Shows sample data from database
echo   - Indicates if fix should work
echo.
echo Step 3 - Test Extraction:
echo   - Shows extracted unit standard IDs
echo   - Tests all 3 tables (POE, Marks, Logbook)
echo   - Shows expected vs actual results
echo.
echo Step 4 - Test Temp Tables:
echo   - Shows stratification calculations
echo   - Displays POE count, marking status, performance level
echo   - Shows final query results
echo.
echo Step 5 - Test API:
echo   - Tests the actual endpoint used by Flutter app
echo   - Shows complete stratification data
echo   - Displays strata summary
echo.
echo ========================================
echo EXPECTED RESULTS:
echo ========================================
echo.
echo POE Count: Should be ^> 0 (e.g., 1, 2, 3, etc.)
echo Marking Status: "Marked" if summative marks exist
echo Performance Level: "High", "Medium", "Low", or "Not Assessed"
echo POE Completeness: "Complete", "Partial", or "Incomplete"
echo.
echo ========================================
echo TROUBLESHOOTING:
echo ========================================
echo.
echo If POE count is still 0:
echo   1. Check verify_unit_standard_fix.php output
echo   2. Verify learner has data with unit standard IDs
echo   3. Check exercise column format in database
echo   4. Try a different learner ID
echo.
echo If you need to reset assignments:
echo   Run this SQL: DELETE FROM moderator_assignments WHERE moderator_id = '77';
echo   Then test the API again
echo.
echo ========================================
echo FILES TO UPLOAD:
echo ========================================
echo.
echo REQUIRED:
echo   - get_learners_with_poe_assigned.php (MAIN FILE)
echo.
echo OPTIONAL (for testing):
echo   - test_temp_tables_logic.php
echo   - test_unit_standard_extraction_fixed.php
echo   - check_server_version.php
echo   - verify_unit_standard_fix.php
echo.
echo ========================================
pause
