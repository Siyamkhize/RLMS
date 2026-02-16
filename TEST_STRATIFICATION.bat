@echo off
echo ========================================
echo TEST STRATIFICATION CALCULATIONS
echo ========================================
echo.
echo This will open diagnostic tests in your browser
echo.
pause
echo.
echo Opening Test 1: Stratification Calculations...
start https://rlms.rlms.co.za/test_stratification_calculations.php?moderator_id=77
echo.
timeout /t 3 >nul
echo Opening Test 2: Temp Tables Logic...
start https://rlms.rlms.co.za/test_temp_tables_logic.php?moderator_id=77
echo.
timeout /t 3 >nul
echo Opening API Response for comparison...
start https://rlms.rlms.co.za/get_learners_with_poe_assigned.php?moderator_id=77
echo.
echo ========================================
echo WHAT TO CHECK:
echo ========================================
echo.
echo Test 1 (Stratification Calculations):
echo   - Unit standards count from each table
echo   - Combined unit standards count
echo   - Performance level calculation
echo   - Marking status
echo   - Comparison with stored values
echo.
echo Test 2 (Temp Tables Logic):
echo   - Moderator's classes
echo   - POE learners count
echo   - Temp table contents
echo   - Final query results
echo.
echo API Response:
echo   - Check if values match Test 1 calculations
echo   - Look for poe_count, marking_status, performance_level
echo.
echo ========================================
echo COMMON ISSUES:
echo ========================================
echo.
echo If poe_count is 0:
echo   - REGEXP pattern not matching exercise format
echo   - Check extraction logic
echo.
echo If performance_level is "Not Assessed":
echo   - temp_learner_marks table is empty
echo   - Check summative marks filter
echo.
echo If marking_status is "Not Marked":
echo   - Not filtering by type = 'Summative'
echo   - Check marks table structure
echo.
echo ========================================
pause
