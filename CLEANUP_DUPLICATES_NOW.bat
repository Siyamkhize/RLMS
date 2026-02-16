@echo off
echo ========================================
echo CLEANING UP DUPLICATE CLOCKING RECORDS
echo ========================================
echo.

echo This will clean up duplicate clocking records for the same learner on the same day.
echo Only the newest record will be kept for each learner.
echo.

pause

echo.
echo Starting Flutter app to run cleanup...
echo.

flutter run --debug

echo.
echo Cleanup completed!
echo Check the console output above for details.
echo.

pause
