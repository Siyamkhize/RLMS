@echo off
cls
echo ========================================
echo   CLEANUP OLD CLOCKING RECORDS
echo ========================================
echo.
echo This will delete all clocking records
echo from before today (keep only current day)
echo.
echo Target: Server database
echo.
pause
echo.

curl -X POST http://localhost/assessorReport2/mobile/cleanup_old_local_records.php

echo.
echo.
echo ========================================
echo Cleanup complete!
echo Check the output above for results.
echo ========================================
echo.
pause
