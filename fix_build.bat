@echo off
echo Fixing Flutter app build issues...
echo.

echo Step 1: Cleaning old error logs...
del /q hs_err_pid*.log 2>nul
del /q replay_pid*.log 2>nul
del /q android\hs_err_pid*.log 2>nul
del /q android\replay_pid*.log 2>nul

echo.
echo Step 2: Cleaning Flutter build cache...
flutter clean

echo.
echo Step 3: Removing Flutter build directory...
if exist build rmdir /s /q build

echo.
echo Step 4: Removing Gradle cache...
if exist android\.gradle rmdir /s /q android\.gradle

echo.
echo Step 5: Cleaning Gradle build...
cd android
call gradlew clean --no-daemon
cd ..

echo.
echo Step 6: Getting Flutter dependencies...
flutter pub get

echo.
echo Step 7: Ready to build!
echo.
echo You can now run:
echo   flutter run -d windows
echo   OR
echo   flutter build apk
echo.
pause

