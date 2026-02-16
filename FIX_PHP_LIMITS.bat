@echo off
echo ========================================
echo Fix PHP Upload Limits for Large Database
echo ========================================
echo.
echo This will increase PHP limits to allow large database imports
echo.

REM Backup php.ini first
if not exist "C:\xampp\php\php.ini.backup" (
    echo Creating backup of php.ini...
    copy "C:\xampp\php\php.ini" "C:\xampp\php\php.ini.backup"
    echo Backup created: php.ini.backup
)

echo.
echo Updating PHP settings...

REM Update upload_max_filesize
powershell -Command "(gc C:\xampp\php\php.ini) -replace 'upload_max_filesize = \d+M', 'upload_max_filesize = 128M' | Out-File -encoding ASCII C:\xampp\php\php.ini"

REM Update post_max_size
powershell -Command "(gc C:\xampp\php\php.ini) -replace 'post_max_size = \d+M', 'post_max_size = 128M' | Out-File -encoding ASCII C:\xampp\php\php.ini"

REM Update max_execution_time
powershell -Command "(gc C:\xampp\php\php.ini) -replace 'max_execution_time = \d+', 'max_execution_time = 300' | Out-File -encoding ASCII C:\xampp\php\php.ini"

REM Update memory_limit
powershell -Command "(gc C:\xampp\php\php.ini) -replace 'memory_limit = \d+M', 'memory_limit = 256M' | Out-File -encoding ASCII C:\xampp\php\php.ini"

echo.
echo ========================================
echo PHP Limits Updated Successfully!
echo ========================================
echo.
echo New Settings:
echo   upload_max_filesize = 128M
echo   post_max_size = 128M
echo   max_execution_time = 300
echo   memory_limit = 256M
echo.
echo IMPORTANT: You must restart Apache in XAMPP!
echo.
echo Steps:
echo 1. Open XAMPP Control Panel
echo 2. Click "Stop" next to Apache
echo 3. Wait 3 seconds
echo 4. Click "Start" next to Apache
echo 5. Now try importing your database again
echo.
echo Original php.ini backed up to: php.ini.backup
echo.
pause
