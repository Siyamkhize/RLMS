@echo off
echo Testing Random Biometric Monitoring System...
echo.

echo Step 1: Testing database connection and table...
curl -X POST http://localhost/assessorReport2/mobile/test_monitoring_system.php
echo.
echo.

echo Step 2: Creating test prompt for random learner...
curl -X POST http://localhost/assessorReport2/mobile/create_random_prompts_batch.php -d "class_id=TEST&num_prompts=1&countdown_duration=60"
echo.
echo.

echo Step 3: Checking if prompts were created...
curl -X POST http://localhost/assessorReport2/mobile/check_monitoring_prompts.php -d "learner_id=1"
echo.
echo.

echo Test completed!
echo.
echo If you see successful responses above, the monitoring system is working.
echo If you see errors, check:
echo 1. Database connection
echo 2. Monitoring table exists
echo 3. Learners are clocked in
echo 4. PHP files are in the correct directory
echo.
pause
