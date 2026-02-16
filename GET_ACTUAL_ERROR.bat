@echo off
echo Getting detailed Flutter compilation error...
echo.

cd android
call gradlew --stop
cd ..

echo Cleaning...
call flutter clean > nul 2>&1

echo Getting dependencies...
call flutter pub get > nul 2>&1

echo.
echo Running Flutter build to capture actual error...
echo.

flutter build apk --debug 2>&1 | findstr /i "error Error ERROR exception Exception EXCEPTION failed Failed FAILED"

echo.
echo.
echo Check above for the actual Dart compilation error
echo.
pause
