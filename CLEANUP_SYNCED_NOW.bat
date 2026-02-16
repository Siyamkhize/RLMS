@echo off
cls
echo ========================================
echo   DELETE SYNCED RECORDS (Keep Unsynced)
echo ========================================
echo.
echo This will:
echo  ✅ DELETE records with synced=1 (already on server)
echo  ✅ KEEP records with synced=0 (still need to upload)
echo.
echo This will clean up your 211 old synced records!
echo.
pause
echo.

echo Running cleanup...
curl -X POST http://localhost/assessorReport2/mobile/cleanup_synced_records.php

echo.
echo.
echo ========================================
echo Cleanup complete!
echo.
echo Check above to see:
echo - How many synced records were deleted
echo - How many unsynced records remain
echo - Breakdown by date
echo ========================================
echo.
pause