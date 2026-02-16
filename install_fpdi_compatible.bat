@echo off
echo ========================================
echo FPDI Installation Fix for PHP 7.4+
echo ========================================
echo.

echo This will install FPDI 2.3.x (compatible with PHP 7.4+)
echo.

REM Check if composer is installed
where composer >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Composer is not installed or not in PATH
    echo.
    echo Please install Composer first:
    echo https://getcomposer.org/download/
    echo.
    pause
    exit /b 1
)

echo Composer found!
echo.

REM Remove old installation
if exist "vendor" (
    echo Removing old vendor directory...
    rmdir /s /q vendor
)

if exist "composer.lock" (
    echo Removing old composer.lock...
    del composer.lock
)

echo.
echo Installing FPDI 2.3.x...
echo.

REM Install with platform check
composer require setasign/fpdi:^2.3

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo SUCCESS! FPDI 2.3.x installed
    echo ========================================
    echo.
    echo You can now use the PDF merge functionality.
    echo.
    echo Test it by visiting:
    echo http://localhost/test_merge_poe.php
    echo.
) else (
    echo.
    echo ========================================
    echo Installation failed!
    echo ========================================
    echo.
    echo Try manual installation:
    echo 1. Delete vendor folder and composer.lock
    echo 2. Run: composer install --ignore-platform-reqs
    echo.
)

pause
