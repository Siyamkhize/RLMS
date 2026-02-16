@echo off
echo ========================================
echo DEPLOY UNIT STANDARD EXTRACTION FIX
echo ========================================
echo.
echo This will upload the fixed files to the server.
echo.
echo Files to upload:
echo   1. get_learners_with_poe_assigned.php (MAIN API FILE)
echo   2. test_temp_tables_logic.php (TEST FILE)
echo   3. test_unit_standard_extraction_fixed.php (NEW TEST FILE)
echo   4. check_server_version.php (VERSION CHECK)
echo.
echo ========================================
echo DEPLOYMENT STEPS:
echo ========================================
echo.
echo 1. Upload these files to your server:
echo    - get_learners_with_poe_assigned.php
echo    - test_temp_tables_logic.php
echo    - test_unit_standard_extraction_fixed.php
echo    - check_server_version.php
echo.
echo 2. Test the version detection:
echo    http://your-server.com/check_server_version.php
echo.
echo 3. Test the extraction logic:
echo    http://your-server.com/test_unit_standard_extraction_fixed.php?moderator_id=77^&learner_id=1231
echo.
echo 4. Test the temp tables logic:
echo    http://your-server.com/test_temp_tables_logic.php?moderator_id=77
echo.
echo 5. Test the API endpoint:
echo    http://your-server.com/get_learners_with_poe_assigned.php?moderator_id=77
echo.
echo ========================================
echo EXPECTED RESULTS:
echo ========================================
echo.
echo - POE Count should be ^> 0 (not 0)
echo - Marking Status should be "Marked" if summative marks exist
echo - Performance Level should match average marks:
echo   * High: 70%+
echo   * Medium: 50-69%%
echo   * Low: 0-49%%
echo   * Not Assessed: No marks
echo - POE Completeness should match unit standards count:
echo   * Complete: 10+ unit standards
echo   * Partial: 1-9 unit standards
echo   * Incomplete: 0 unit standards
echo.
echo ========================================
echo TROUBLESHOOTING:
echo ========================================
echo.
echo If POE count is still 0:
echo   1. Check check_server_version.php to see which method is being used
echo   2. Check test_unit_standard_extraction_fixed.php to see extracted IDs
echo   3. Verify exercise column format in database
echo   4. Check for SQL errors in test_temp_tables_logic.php
echo.
echo If you need to reset moderator assignments:
echo   DELETE FROM moderator_assignments WHERE moderator_id = '77';
echo.
echo ========================================
pause
