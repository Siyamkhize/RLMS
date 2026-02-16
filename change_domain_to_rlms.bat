@echo off
REM Change domain from rlms.rlms.co.za to rlms.rlms.co.za in all files

echo Changing domain in all files...
echo.

REM Use PowerShell to do find and replace in all files
powershell -Command "(Get-ChildItem -Path . -Recurse -Include *.md,*.php,*.txt,*.html,*.js,*.dart,*.sql,*.bat,*.sh -Exclude node_modules,vendor,build,.dart_tool,.git | ForEach-Object { (Get-Content $_.FullName -Raw) -replace 'tesing\.mtltechnical\.co\.za', 'rlms.rlms.co.za' | Set-Content $_.FullName -NoNewline })"

echo.
echo Domain changed successfully!
echo.
echo Changed: rlms.rlms.co.za
echo To: rlms.rlms.co.za
echo.
echo Please rebuild your Flutter app for changes to take effect:
echo flutter clean
echo flutter pub get
echo flutter build apk
echo.
pause
