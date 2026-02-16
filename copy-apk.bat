@echo off
REM Create the Flutter expected output directory
if not exist "build\app\outputs\flutter-apk" mkdir "build\app\outputs\flutter-apk"

REM Copy the APK from Gradle output to Flutter expected location
if exist "android\app\build\outputs\apk\debug\app-debug.apk" (
    copy "android\app\build\outputs\apk\debug\app-debug.apk" "build\app\outputs\flutter-apk\app-debug.apk"
    echo APK copied successfully to build\app\outputs\flutter-apk\app-debug.apk
) else (
    echo Error: APK not found at android\app\build\outputs\apk\debug\app-debug.apk
)

REM Also copy release APK if it exists
if exist "android\app\build\outputs\apk\release\app-release.apk" (
    copy "android\app\build\outputs\apk\release\app-release.apk" "build\app\outputs\flutter-apk\app-release.apk"
    echo Release APK copied successfully
)
