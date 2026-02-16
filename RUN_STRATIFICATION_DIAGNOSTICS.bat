@echo off
echo ========================================
echo STRATIFICATION DATA DIAGNOSTICS
echo ========================================
echo.
echo Opening diagnostic tools in browser...
echo.
echo ========================================
echo TEST 1: Temp Tables Diagnostic
echo ========================================
echo.
echo This will show if temp tables are created correctly
echo and contain data.
echo.
start https://rlms.rlms.co.za/test_temp_tables_issue.php?moderator_id=77
timeout /t 3 >nul

echo ========================================
echo TEST 2: Individual Learner Diagnostic
echo ========================================
echo.
echo This will show detailed calculation for
echo a specific learner.
echo.
start https://rlms.rlms.co.za/test_stratification_data.php?moderator_id=77
timeout /t 3 >nul

echo ========================================
echo TEST 3: API Response
echo ========================================
echo.
echo This will show what the API actually returns.
echo.
start https://rlms.rlms.co.za/get_learners_with_poe_assigned.php?moderator_id=77
timeout /t 3 >nul

echo.
echo ========================================
echo WHAT TO CHECK:
echo ========================================
echo.
echo ✅ Temp tables should have data
echo ✅ Unit standards count should be correct
echo ✅ Marking status should be correct
echo ✅ Performance level should be correct
echo.
echo Compare the diagnostic results with the API response
echo to identify where the issue is.
echo.
echo ========================================
echo COMMON ISSUES:
echo ========================================
echo.
echo ❌ Temp tables empty = Class filtering too restrictive
echo ❌ Unit standards 0 = Exercise column extraction failing
echo ❌ Always "Not Marked" = No SUMMATIVE marks found
echo ❌ Always "Not Assessed" = No marks_scored values
echo.
echo ========================================
echo NEXT STEPS:
echo ========================================
echo.
echo 1. Review the diagnostic output
echo 2. Identify the issue
echo 3. Apply fix to get_learners_with_poe_assigned.php
echo 4. Upload to server
echo 5. Test again
echo.
pause
