@echo off
echo ========================================
echo DEPLOY STRATIFICATION FIX
echo ========================================
echo.
echo This will upload the fixed files to your server.
echo.
echo Files to upload:
echo 1. test_temp_tables_logic.php
echo 2. get_learners_with_poe_assigned.php
echo.
echo ========================================
echo MANUAL UPLOAD INSTRUCTIONS
echo ========================================
echo.
echo 1. Open your FTP client or file manager
echo 2. Navigate to your server root directory
echo 3. Upload these 2 files:
echo    - test_temp_tables_logic.php
echo    - get_learners_with_poe_assigned.php
echo.
echo 4. Test the diagnostic:
echo    https://rlms.rlms.co.za/test_temp_tables_logic.php?moderator_id=77
echo.
echo 5. Test the API:
echo    https://rlms.rlms.co.za/get_learners_with_poe_assigned.php?moderator_id=77
echo.
echo 6. Verify in mobile app
echo.
echo ========================================
echo EXPECTED RESULTS
echo ========================================
echo.
echo Diagnostic Test (Step 5):
echo - POE Count: 3, 2 (not 0)
echo - Completeness: Partial (not Incomplete)
echo - Marking: Not Marked (correct)
echo - Performance: Not Assessed (correct)
echo.
echo API Response:
echo - poe_count: 3, 2 (not 0)
echo - poe_completeness: Partial (not Incomplete)
echo - marking_status: Not Marked (correct)
echo - performance_level: Not Assessed (correct)
echo.
echo ========================================
echo.
pause
