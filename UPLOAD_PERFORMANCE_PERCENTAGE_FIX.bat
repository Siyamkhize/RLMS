@echo off
echo ========================================
echo Uploading Performance Percentage Fix
echo ========================================
echo.

echo Uploading main API file...
pscp -batch -pw "Limpopo@123" "get_learners_with_poe_assigned.php" administrator@102.130.118.179:/var/www/html/

echo.
echo Uploading test file...
pscp -batch -pw "Limpopo@123" "test_temp_tables_logic.php" administrator@102.130.118.179:/var/www/html/

echo.
echo Uploading diagnostic file...
pscp -batch -pw "Limpopo@123" "check_assessments_marks_column.php" administrator@102.130.118.179:/var/www/html/

echo.
echo ========================================
echo Upload Complete!
echo ========================================
echo.
echo Test the fix:
echo 1. Check Structure: http://102.130.118.179/check_assessments_marks_column.php
echo 2. Test Logic: http://102.130.118.179/test_temp_tables_logic.php?moderator_id=77
echo 3. API: http://102.130.118.179/get_learners_with_poe_assigned.php?moderator_id=77
echo.
echo Performance is now calculated as: (marks_scored / assessments.marks) * 100
echo.
pause
