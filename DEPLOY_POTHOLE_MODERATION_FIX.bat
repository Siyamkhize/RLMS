@echo off
echo ========================================
echo Pothole Moderation Per-Unit-Standard Fix
echo ========================================
echo.
echo This will help you deploy the fixed files.
echo.
echo FILES TO UPLOAD:
echo 1. view_pothole_checklists.php (FIXED - uses connection.php now)
echo 2. test_pothole_unit_standards.php (NEW - for testing)
echo.
echo UPLOAD TO: https://rlms.rlms.co.za/mobile/
echo.
echo ========================================
echo DEPLOYMENT STEPS:
echo ========================================
echo.
echo 1. Upload view_pothole_checklists.php to server
echo    - This fixes the "checklists not showing" issue
echo.
echo 2. Upload test_pothole_unit_standards.php to server
echo    - This helps check if marks exist in database
echo.
echo 3. Test checklist display:
echo    https://rlms.rlms.co.za/mobile/view_pothole_checklists.php?learner_id=TEST_ID
echo.
echo 4. Check if marks exist:
echo    https://rlms.rlms.co.za/mobile/test_pothole_unit_standards.php?learner_id=TEST_ID
echo.
echo 5. If no marks found:
echo    - Assessor needs to save marks for pothole checklist first
echo    - Then moderator can moderate
echo.
echo ========================================
echo IMPORTANT NOTES:
echo ========================================
echo.
echo - The "Missing required fields" error happens when marks don't exist yet
echo - Assessor must save marks BEFORE moderator can moderate
echo - Each unit standard (13958 and 14555) needs marks saved
echo - The recordId comes from the 'id' field in logbook_marks table
echo.
echo ========================================
echo.
pause
