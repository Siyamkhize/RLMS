@echo off
echo Uploading diagnostic file for learner 1231...
pscp -batch -pw "ASDFrewq1234@" diagnose_learner_1231_summative.php administrator@102.130.118.179:/var/www/html/
echo.
echo Upload complete!
echo.
echo Test at: http://102.130.118.179/diagnose_learner_1231_summative.php
pause
