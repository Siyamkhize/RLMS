@echo off
echo ========================================
echo Import Database to XAMPP MySQL
echo ========================================
echo.
echo Database Name: rlmsrlmsco_ezxcmacd_rlms
echo.

REM Check if MySQL is running
echo Checking if MySQL is running...
tasklist /FI "IMAGENAME eq mysqld.exe" 2>NUL | find /I /N "mysqld.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [OK] MySQL is running
) else (
    echo [ERROR] MySQL is not running!
    echo Please start MySQL in XAMPP Control Panel first.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Step 1: Create Database
echo ========================================
echo.

REM Create database
"C:\xampp\mysql\bin\mysql.exe" -u root -e "CREATE DATABASE IF NOT EXISTS rlmsrlmsco_ezxcmacd_rlms CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

if %ERRORLEVEL% EQU 0 (
    echo [OK] Database created successfully
) else (
    echo [ERROR] Failed to create database
    echo Make sure MySQL is running in XAMPP
    pause
    exit /b 1
)

echo.
echo ========================================
echo Step 2: Import Database File
echo ========================================
echo.

REM Prompt for database file location
set /p DB_FILE="Enter the full path to your .sql file: "

REM Check if file exists
if not exist "%DB_FILE%" (
    echo [ERROR] File not found: %DB_FILE%
    echo.
    echo Please check the file path and try again.
    echo Example: C:\Users\Administrator\Downloads\database.sql
    pause
    exit /b 1
)

echo.
echo Importing database from: %DB_FILE%
echo This may take a few minutes for large databases...
echo.

REM Import database
"C:\xampp\mysql\bin\mysql.exe" -u root rlmsrlmsco_ezxcmacd_rlms < "%DB_FILE%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo [SUCCESS] Database imported successfully!
    echo ========================================
    echo.
    echo Database Name: rlmsrlmsco_ezxcmacd_rlms
    echo.
    echo Next Steps:
    echo 1. Open phpMyAdmin: http://localhost/phpmyadmin
    echo 2. Click on database: rlmsrlmsco_ezxcmacd_rlms
    echo 3. Verify tables are imported
    echo 4. Update connection.php with database name
    echo.
) else (
    echo.
    echo ========================================
    echo [ERROR] Import failed!
    echo ========================================
    echo.
    echo Possible issues:
    echo 1. SQL file is corrupted
    echo 2. MySQL max_allowed_packet is too small
    echo 3. Insufficient memory
    echo.
    echo Try using phpMyAdmin instead:
    echo 1. Go to http://localhost/phpmyadmin
    echo 2. Create database: rlmsrlmsco_ezxcmacd_rlms
    echo 3. Click Import tab
    echo 4. Choose your .sql file
    echo 5. Click Go
    echo.
)

pause
