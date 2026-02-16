@echo off
echo ========================================
echo Moderation Sampling Performance Fix
echo ========================================
echo.
echo This will deploy the stratification metadata storage fix
echo.
echo STEPS:
echo 1. Backup database (IMPORTANT!)
echo 2. Run SQL migration to add columns
echo 3. Upload updated PHP file
echo 4. Test with moderators
echo.
echo ========================================
echo.

echo Step 1: Database Migration
echo ---------------------------
echo.
echo Run this SQL script on your database:
echo   add_stratification_metadata_columns.sql
echo.
echo This adds the following columns to moderator_assignments:
echo   - site_id
echo   - poe_completeness
echo   - marking_status
echo   - performance_level
echo   - poe_count
echo.
pause

echo.
echo Step 2: Upload PHP File
echo -----------------------
echo.
echo Upload this file to your server:
echo   get_learners_with_poe_assigned.php
echo.
echo Location: /mobile/get_learners_with_poe_assigned.php
echo.
pause

echo.
echo Step 3: Test
echo ------------
echo.
echo Test URL:
echo   https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php?moderator_id=TEST001
echo.
echo Expected results:
echo   - Response time: less than 1 second
echo   - No 504 timeout errors
echo   - Stratification data shows real values (not "Unknown")
echo   - POE count shows actual numbers (not 0)
echo.
echo ========================================
echo Deployment Complete!
echo ========================================
echo.
echo Check the UI to verify:
echo   1. Strata Breakdown table shows real data
echo   2. Selected Learners show POE Status, Marking, Performance
echo   3. Unit Standards count is not 0
echo.
pause
