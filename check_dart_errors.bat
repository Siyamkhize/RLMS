@echo off
echo Checking Dart files for errors...
echo.
echo Analyzing lib/services/random_prompt_service.dart...
dart analyze lib/services/random_prompt_service.dart 2>&1
echo.
echo Analyzing lib/monitoring_prompt_page.dart...
dart analyze lib/monitoring_prompt_page.dart 2>&1
echo.
echo Analyzing lib/utils/monitoring_mixin.dart...
dart analyze lib/utils/monitoring_mixin.dart 2>&1
echo.
echo Done!
pause

