@echo off
echo ========================================
echo UPLOAD ASSESSMENTS TABLE JOIN FIX
echo ========================================
echo.
echo This fix uses the assessments table to determine summative marks.
echo.
echo Files to upload:
echo 1. get_learners_with_poe_assigned.php
echo 2. test_temp_tables_logic.php
echo.
echo After upload, test with:
echo http://your-server/test_temp_tables_logic.php?moderator_id=77
echo.
echo Check Step 3 - temp_learner_marks should have rows!
echo.
pause
