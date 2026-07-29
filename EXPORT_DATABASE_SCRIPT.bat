@echo off
REM Script to export app database from device for inspection
REM This bypasses Android Studio's Device Explorer permission issues

echo ========================================
echo Exporting RLMSS App Database
echo ========================================
echo.

REM Step 1: Copy database from app directory to sdcard
echo Step 1: Copying database to accessible location...
adb shell "run-as com.example.rlmss cp /data/data/com.example.rlmss/databases/local_data.db /data/data/com.example.rlmss/local_data.db"
adb shell "run-as com.example.rlmss chmod 644 /data/data/com.example.rlmss/local_data.db"
adb shell "run-as com.example.rlmss cp /data/data/com.example.rlmss/local_data.db /sdcard/local_data.db"

REM Step 2: Pull database to computer
echo Step 2: Downloading database to computer...
adb pull /sdcard/local_data.db exported_database\local_data.db

REM Step 3: Clean up
echo Step 3: Cleaning up temporary files...
adb shell "rm /sdcard/local_data.db"

echo.
echo ========================================
echo SUCCESS: Database exported to exported_database\local_data.db
echo You can now open it with SQLite browser or DB Browser for SQLite
echo ========================================
pause
