@echo off
echo ========================================
echo VERIFY SERVER HAS CLASS FILTERING CODE
echo ========================================
echo.
echo Opening verification page in browser...
echo.
start https://rlms.rlms.co.za/check_server_version.php
echo.
echo ========================================
echo WHAT TO LOOK FOR:
echo ========================================
echo.
echo ✅ NEW VERSION DETECTED - File has class filtering code
echo ✅ getModeratorClasses() function is present
echo ✅ getAvailableLearnersByStrata() has moderatorId parameter
echo ✅ Class filtering logic is present
echo.
echo If you see these, the upload was successful!
echo.
echo ========================================
echo TEST API WITH MODERATOR 77:
echo ========================================
echo.
echo Opening API test in browser...
timeout /t 3 >nul
start https://rlms.rlms.co.za/get_learners_with_poe_assigned.php?moderator_id=77
echo.
echo ========================================
echo WHAT TO VERIFY IN API RESPONSE:
echo ========================================
echo.
echo ✅ All learners have "classID": "74"
echo ✅ All learners have "className": "Class A"
echo ✅ No learners from other classes
echo.
echo ========================================
echo TEST DATABASE QUERIES:
echo ========================================
echo.
echo Opening database test in browser...
timeout /t 3 >nul
start https://rlms.rlms.co.za/test_moderator_77_data.php
echo.
echo This will show:
echo - Moderator's allocated classes
echo - Learners with POE in those classes
echo - Expected sampling results
echo.
pause
