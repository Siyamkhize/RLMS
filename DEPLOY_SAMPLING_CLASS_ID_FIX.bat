@echo off
echo ============================================
echo DEPLOY MODERATION SAMPLING CLASS_ID FIX
echo ============================================
echo.

echo This will deploy the fix for "Unknown column 'class_id'" error
echo.

echo Files to upload:
echo   1. get_learners_with_poe_assigned.php (UPDATED)
echo   2. test_sampling_table_fix.php (NEW - for testing)
echo.

echo DEPLOYMENT STEPS:
echo.
echo 1. Upload get_learners_with_poe_assigned.php to server
echo    Location: /mobile/get_learners_with_poe_assigned.php
echo.
echo 2. Upload test_sampling_table_fix.php to server
echo    Location: /mobile/test_sampling_table_fix.php
echo.
echo 3. Test the fix by running:
echo    php test_sampling_table_fix.php
echo.
echo 4. Or test from browser:
echo    https://rlms.rlms.co.za/mobile/test_sampling_table_fix.php
echo.
echo 5. Test from mobile app:
echo    - Open Moderator page
echo    - Click "Get Learners with POE"
echo    - Should see learners with stratification data
echo.

echo WHAT THE FIX DOES:
echo   - Checks if moderator_assignments table exists
echo   - Adds missing columns: class_id, site_id, stratum_type, etc.
echo   - Stores stratification metadata for fast retrieval
echo   - No more "Unknown column" errors
echo   - No more 504 timeouts
echo.

echo EXPECTED RESULTS:
echo   - Table updated with all required columns
echo   - Sampling completes in 2-5 seconds
echo   - Learners displayed with stratification info
echo   - No errors in logs
echo.

pause
