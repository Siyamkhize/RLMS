@echo off
echo ========================================
echo Starting Local PHP Server
echo ========================================
echo.
echo Server URL: http://192.168.0.65:8000
echo Base Path: /mobile
echo.
echo Press Ctrl+C to stop the server
echo.
echo ========================================
echo.

cd /d C:\projects\rlmss
php -S 192.168.0.65:8000 -t .

pause
