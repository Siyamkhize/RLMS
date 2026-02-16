@echo off
REM Copy the backup logistics file to current workspace for comparison
if exist "C:\projects\rlmss_backup\lib\logistics_LearningMaterialFormPage.dart" (
    copy "C:\projects\rlmss_backup\lib\logistics_LearningMaterialFormPage.dart" "lib\logistics_LearningMaterialFormPage_BACKUP.dart"
    echo Backup file copied to lib\logistics_LearningMaterialFormPage_BACKUP.dart
    echo You can now compare the two files
) else (
    echo Error: Backup file not found at C:\projects\rlmss_backup\lib\logistics_LearningMaterialFormPage.dart
)
pause
