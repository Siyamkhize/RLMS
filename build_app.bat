@echo off
echo ========================================
echo BUILDING APP WITH TYPE CASTING FIX V2
echo ========================================
echo.
echo Fix Applied: Using for-loop instead of cast
echo This should resolve the CastList error
echo.

echo Step 1: Cleaning build cache...
call flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Flutter clean failed!
    pause
    exit /b 1
)
echo Clean complete!
echo.

echo Step 2: Getting dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Flutter pub get failed!
    pause
    exit /b 1
)
echo Dependencies updated!
echo.

echo Step 3: Building and running app...
echo This will take 2-3 minutes...
call flutter run
if %errorlevel% neq 0 (
    echo ERROR: Flutter run failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo BUILD COMPLETE!
echo ========================================
echo.
echo The app should now be running with the fix applied.
echo Check the console for the load summary.
echo You should see: [LOAD] Total unique learners: 33
echo.
pause
