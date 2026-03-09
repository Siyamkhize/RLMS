@echo off
echo ============================================
echo FORCE REBUILD - TYPE CASTING FIX
echo ============================================
echo.
echo This will completely rebuild your app.
echo Please wait 2-3 minutes...
echo.
pause

echo.
echo Step 1: Stopping any running Flutter processes...
taskkill /F /IM flutter.exe 2>nul
taskkill /F /IM dart.exe 2>nul
echo Done!
echo.

echo Step 2: Cleaning build cache...
call flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Flutter clean failed!
    echo Make sure you're in the correct project folder.
    pause
    exit /b 1
)
echo Clean complete!
echo.

echo Step 3: Getting dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Flutter pub get failed!
    pause
    exit /b 1
)
echo Dependencies updated!
echo.

echo Step 4: Building and running app...
echo This takes 2-3 minutes - please be patient...
echo.
call flutter run --no-hot
if %errorlevel% neq 0 (
    echo ERROR: Flutter run failed!
    pause
    exit /b 1
)

echo.
echo ============================================
echo BUILD COMPLETE!
echo ============================================
echo.
echo Check the console output above.
echo You should see: [LOAD] Total unique learners: 33
echo NO error message!
echo.
pause
