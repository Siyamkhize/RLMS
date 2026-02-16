@echo off
echo Testing Flutter compilation...
flutter assemble -dTargetPlatform=android-arm --output=build\test debug_android_application > compile_output.txt 2>&1
type compile_output.txt
pause

