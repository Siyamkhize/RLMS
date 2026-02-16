@echo off
echo ========================================
echo Import RLMS Database to XAMPP
echo ========================================
echo.
echo Database File: rlmsrlmsco_ezxcmacd_rlms (1).sql
echo Location: C:\Users\Administrator\.android\studio\newApp\rlmss\
echo Target: XAMPP MySQL (localhost)
echo.

REM Check if MySQL is running
echo [1/4] Checking if MySQL is running...
tasklist /FI "IMAGENAME eq mysqld.exe" 2>NUL | find /I /N "mysqld.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo       [OK] MySQL is running
) else (
    echo       [ERROR] MySQL is not running!
    echo.
    echo Please start MySQL in XAMPP Control Panel:
    echo 1. Open XAMPP Control Panel
    echo 2. Click "Start" next to MySQL
    echo 3. Wait for green "Running" status
    echo 4. Run this script again
    echo.
    pause
    exit /b 1
)

echo.
echo [2/4] Creating database...

REM Create database
"C:\xampp\mysql\bin\mysql.exe" -u root -e "CREATE DATABASE IF NOT EXISTS rlmsrlmsco_ezxcmacd_rlms CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

if %ERRORLEVEL% EQU 0 (
    echo       [OK] Database created: rlmsrlmsco_ezxcmacd_rlms
) else (
    echo       [ERROR] Failed to create database
    pause
    exit /b 1
)

echo.
echo [3/4] Importing database file...
echo       This may take 2-5 minutes for large databases...
echo       Please wait...
echo.

REM Import database from specific location
"C:\xampp\mysql\bin\mysql.exe" -u root rlmsrlmsco_ezxcmacd_rlms < "C:\Users\Administrator\.android\studio\newApp\rlmss\rlmsrlmsco_ezxcmacd_rlms (1).sql"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [4/4] Verifying import...
    
    REM Count tables
    for /f %%i in ('"C:\xampp\mysql\bin\mysql.exe" -u root -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='rlmsrlmsco_ezxcmacd_rlms';"') do set TABLE_COUNT=%%i
    
    echo       [OK] Import completed successfully!
    echo       Tables imported: %TABLE_COUNT%
    echo.
    echo ========================================
    echo SUCCESS! Database is ready to use
    echo ========================================
    echo.
    echo Database Name: rlmsrlmsco_ezxcmacd_rlms
    echo Tables: %TABLE_COUNT%
    echo.
    echo Next Steps:
    echo 1. Verify in phpMyAdmin: http://localhost/phpmyadmin
    echo 2. Update your connection.php file
    echo 3. Test your application
    echo.
    echo Connection Settings:
    echo   Host: localhost
    echo   Username: root
    echo   Password: (leave empty)
    echo   Database: rlmsrlmsco_ezxcmacd_rlms
    echo.
) else (
    echo.
    echo ========================================
    echo [ERROR] Import failed!
    echo ========================================
    echo.
    echo Possible solutions:
    echo.
    echo 1. Try phpMyAdmin method instead:
    echo    - Go to: http://localhost/phpmyadmin
    echo    - Click "Databases" tab
    echo    - Create database: rlmsrlmsco_ezxcmacd_rlms
    echo    - Click "Import" tab
    echo    - Choose file: C:\Users\Administrator\.android\studio\newApp\rlmss\rlmsrlmsco_ezxcmacd_rlms (1).sql
    echo    - Click "Go"
    echo.
    echo 2. Increase MySQL limits:
    echo    - Edit: C:\xampp\mysql\bin\my.ini
    echo    - Find: max_allowed_packet = 1M
    echo    - Change to: max_allowed_packet = 64M
    echo    - Restart MySQL in XAMPP
    echo.
    echo 3. Check if file exists:
    echo    - Open: C:\Users\Administrator\.android\studio\newApp\rlmss\
    echo    - Verify file: rlmsrlmsco_ezxcmacd_rlms (1).sql
    echo.
)

pause
