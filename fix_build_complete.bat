@echo off
echo ========================================
echo COMPLETE BUILD FIX SCRIPT
echo ========================================
echo.

echo Step 1: Stopping any running Gradle daemons...
cd android
call gradlew --stop
cd ..
echo.

echo Step 2: Cleaning old error logs...
del /q hs_err_pid*.log 2>nul
del /q replay_pid*.log 2>nul
del /q android\hs_err_pid*.log 2>nul
del /q android\replay_pid*.log 2>nul
echo.

echo Step 3: Cleaning Flutter build cache...
flutter clean
echo.

echo Step 4: Removing build directories...
if exist build rmdir /s /q build
if exist android\.gradle rmdir /s /q android\.gradle
if exist android\app\build rmdir /s /q android\app\build
echo.

echo Step 5: Cleaning Gradle build...
cd android
call gradlew clean --no-daemon
cd ..
echo.

echo Step 6: Getting Flutter dependencies...
flutter pub get
echo.

echo Step 7: Running Flutter doctor...
flutter doctor
echo.

echo ========================================
echo BUILD FIX COMPLETE!
echo ========================================
echo.
echo You can now try building with:
echo   flutter build apk --debug
echo.
pause
