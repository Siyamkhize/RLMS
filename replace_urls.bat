@echo off
echo Replacing rlms.rlms.co.za with rlms.rlms.co.za in all files...
echo.

powershell -Command "$files = Get-ChildItem -Path . -Include *.dart,*.php,*.md,*.txt,*.js,*.bat,*.sql,*.sh,*.json,*.yaml,*.yml -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(build|linux|windows|\\.dart_tool|android\\build|\\.git)\\' }; $count = 0; foreach ($file in $files) { try { $content = Get-Content $file.FullName -Raw; if ($content -match 'rlms\\.rlms\\.co\\.za') { $newContent = $content -replace 'rlms\\.rlms\\.co\\.za', 'rlms.rlms.co.za'; [System.IO.File]::WriteAllText($file.FullName, $newContent); $count++; Write-Host \"Updated: $($file.Name)\" } } catch { } }; Write-Host \"`nTotal files updated: $count\""

echo.
echo Done!
pause
