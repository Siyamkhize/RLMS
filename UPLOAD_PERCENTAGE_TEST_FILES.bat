@echo off
echo ========================================
echo Uploading Percentage Calculation Test Files
echo ========================================
echo.

echo Uploading assessments table checker...
pscp -batch -pw "Limpopo@123" "check_assessments_marks_column.php" administrator@102.130.118.179:/var/www/html/

echo.
echo Uploading percentage calculation test...
pscp -batch -pw "Limpopo@123" "test_percentage_calculation.php" administrator@102.130.118.179:/var/www/html/

echo.
echo ========================================
echo Upload Complete!
echo ========================================
echo.
echo Test the percentage calculation:
echo 1. Check Structure: http://102.130.118.179/check_assessments_marks_column.php
echo 2. Test Calculation: http://102.130.118.179/test_percentage_calculation.php?learner_id=1231
echo 3. Test Temp Tables: http://102.130.118.179/test_temp_tables_logic.php?moderator_id=77
echo 4. Test API: http://102.130.118.179/get_learners_with_poe_assigned.php?moderator_id=77
echo.
pause
