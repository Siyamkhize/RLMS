@echo off
REM Set Android home to current user's directory
set ANDROID_USER_HOME=%USERPROFILE%\.android

REM Run flutter with all passed arguments
flutter %*
