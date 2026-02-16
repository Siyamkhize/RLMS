@echo off
echo ========================================
echo UPLOAD PERFORMANCE CALCULATION FIX
echo ========================================
echo.
echo This will upload the fixed files to the server:
echo 1. get_learners_with_poe_assigned.php
echo 2. test_temp_tables_logic.php
echo.
echo CHANGES:
echo - Fixed performance calculation to use SUM method
echo - Now correctly sums all marks per unit standard before calculating percentage
echo - Example: (3+5+6)/(5+10+15)*100 instead of AVG(60%%, 50%%, 40%%)
echo.
pause

echo.
echo Uploading get_learners_with_poe_assigned.php...
echo TODO: Use your FTP/SFTP client to upload this file
echo.

echo Uploading test_temp_tables_logic.php...
echo TODO: Use your FTP/SFTP client to upload this file
echo.

echo ========================================
echo TESTING INSTRUCTIONS
echo ========================================
echo.
echo 1. Open browser and navigate to:
echo    http://your-server.com/test_temp_tables_logic.php?moderator_id=77
echo.
echo 2. Check the results:
echo    - Avg Marks should be calculated correctly (SUM method)
echo    - Performance Level should match avg marks
echo    - High: 70%%+
echo    - Medium: 50-69%%
echo    - Low: 0-49%%
echo    - Not Assessed: NULL
echo.
echo 3. Test the API endpoint:
echo    http://your-server.com/get_learners_with_poe_assigned.php?moderator_id=77
echo.
echo 4. Verify performance_level field is correct for each learner
echo.
pause
