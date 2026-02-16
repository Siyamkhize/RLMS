@echo off
echo ========================================
echo Uploading SUM Calculation Test File
echo ========================================
echo.

echo This will upload the new test file to verify SUM-based calculation
echo.

echo File to upload:
echo - test_sum_based_calculation.php
echo.

echo Target server: 102.130.118.179
echo.

pause

echo.
echo Uploading test_sum_based_calculation.php...
pscp -pw Tiisetso@98 test_sum_based_calculation.php administrator@102.130.118.179:/var/www/html/

echo.
echo ========================================
echo Upload Complete!
echo ========================================
echo.

echo Test the file at:
echo http://102.130.118.179/test_sum_based_calculation.php?learner_id=1231
echo.

echo This will show:
echo 1. Individual exercise marks with percentages
echo 2. SUM-based calculation per unit standard
echo 3. Overall performance (average of unit standards)
echo 4. Verification against user example
echo.

pause
