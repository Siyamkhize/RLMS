@echo off
echo ========================================
echo POE Document System Deployment
echo ========================================
echo.

echo Step 1: Checking required files...
if not exist "upload_poe_document.php" (
    echo ERROR: upload_poe_document.php not found!
    pause
    exit /b 1
)
if not exist "get_poe_documents.php" (
    echo ERROR: get_poe_documents.php not found!
    pause
    exit /b 1
)
if not exist "create_poe_documents_table.sql" (
    echo ERROR: create_poe_documents_table.sql not found!
    pause
    exit /b 1
)
echo All required files found!
echo.

echo Step 2: Flutter dependencies...
echo Add these to pubspec.yaml:
echo   cunning_document_scanner: ^1.2.2
echo   pdf: ^3.10.4
echo   image: ^4.0.17
echo   path_provider: ^2.1.1
echo.
echo Then run: flutter pub get
echo.
pause

echo Step 3: Database setup...
echo Run this command on your server:
echo mysql -u root -p your_database ^< create_poe_documents_table.sql
echo.
pause

echo Step 4: Upload directory...
echo Create directory on server:
echo mkdir -p uploads/poe_documents
echo chmod 777 uploads/poe_documents
echo.
pause

echo Step 5: PHP configuration...
echo Edit php.ini and set:
echo   upload_max_filesize = 200M
echo   post_max_size = 200M
echo   max_execution_time = 300
echo   memory_limit = 256M
echo.
echo Then restart web server
echo.
pause

echo Step 6: Upload PHP files to server...
echo Upload these files:
echo   - upload_poe_document.php
echo   - get_poe_documents.php
echo   - delete_poe_document.php
echo   - test_poe_document_upload.php
echo.
pause

echo Step 7: Test the system...
echo Open in browser:
echo http://your-server/test_poe_document_upload.php
echo.
echo Verify:
echo   [x] Table exists
echo   [x] Upload directory exists and writable
echo   [x] PHP settings correct
echo   [x] Test upload works
echo.
pause

echo Step 8: Build Flutter app...
echo Run: flutter build apk --release
echo.
pause

echo ========================================
echo Deployment checklist complete!
echo ========================================
echo.
echo Next: Test scanning a document in the app
echo.
pause
