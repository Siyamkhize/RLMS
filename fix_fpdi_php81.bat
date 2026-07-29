@echo off
echo ========================================
echo FPDI Fix for PHP 8.1
echo ========================================
echo.
echo Your PHP Version: 8.1.34
echo Required FPDI Version: 2.3.7 (compatible with PHP 8.1)
echo.

echo Step 1: Removing old composer files...
if exist "composer.lock" (
    del composer.lock
    echo - Deleted composer.lock
)

if exist "vendor" (
    rmdir /s /q vendor
    echo - Deleted vendor directory
)

echo.
echo Step 2: Installing FPDI 2.3.7 for PHP 8.1...
echo.

composer require setasign/fpdf:^1.8 setasign/fpdi:2.3.7 --ignore-platform-reqs

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo SUCCESS!
    echo ========================================
    echo.
    echo FPDI 2.3.7 installed successfully for PHP 8.1
    echo.
    echo Next steps:
    echo 1. Test merge: test_merge_poe_fixed.php?learner_id=152
    echo 2. Merge your POE documents
    echo.
) else (
    echo.
    echo ========================================
    echo Installation Failed
    echo ========================================
    echo.
    echo Try manual installation:
    echo 1. Delete vendor and composer.lock manually
    echo 2. Run: composer install --ignore-platform-reqs
    echo.
)

pause
