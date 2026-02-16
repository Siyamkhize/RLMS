@echo off
echo ========================================
echo UPLOADING EXERCISE COLUMN JOIN FIX
echo ========================================
echo.
echo This will upload the corrected files that join marks with assessments using the exercise column.
echo.
echo Files to upload:
echo 1. get_learners_with_poe_assigned.php
echo 2. test_temp_tables_logic.php
echo.
pause

echo.
echo Uploading get_learners_with_poe_assigned.php...
pscp -batch get_learners_with_poe_assigned.php administrator@102.130.118.179:/var/www/html/

echo.
echo Uploading test_temp_tables_logic.php...
pscp -batch test_temp_tables_logic.php administrator@102.130.118.179:/var/www/html/

echo.
echo ========================================
echo UPLOAD COMPLETE!
echo ========================================
echo.
echo NEXT STEPS:
echo 1. Test with: http://102.130.118.179/test_temp_tables_logic.php?moderator_id=77
echo 2. Check Step 3 (temp_learner_marks) - should have rows with data
echo 3. Check Final Query - should show correct marking status and performance levels
echo 4. Test API: http://102.130.118.179/get_learners_with_poe_assigned.php?moderator_id=77
echo.
pause
