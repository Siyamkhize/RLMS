# PowerShell script to replace rlms.rlms.co.za with rlms.rlms.co.za
# This script will update all files in the project

$oldDomain = "rlms.rlms.co.za"
$newDomain = "rlms.rlms.co.za"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Domain Replacement Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Old Domain: $oldDomain" -ForegroundColor Yellow
Write-Host "New Domain: $newDomain" -ForegroundColor Green
Write-Host ""

# File extensions to search
$extensions = @("*.dart", "*.php", "*.md", "*.txt", "*.bat", "*.ps1", "*.js", "*.html")

$totalFiles = 0
$totalReplacements = 0

foreach ($ext in $extensions) {
    Write-Host "Searching $ext files..." -ForegroundColor Cyan
    
    $files = Get-ChildItem -Path . -Filter $ext -Recurse -File -ErrorAction SilentlyContinue | 
             Where-Object { $_.FullName -notmatch '\\(node_modules|vendor|\.git|\.dart_tool|build|venv)\\' }
    
    foreach ($file in $files) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction Stop
            
            if ($content -match [regex]::Escape($oldDomain)) {
                $newContent = $content -replace [regex]::Escape($oldDomain), $newDomain
                Set-Content -Path $file.FullName -Value $newContent -NoNewline
                
                $count = ([regex]::Matches($content, [regex]::Escape($oldDomain))).Count
                $totalReplacements += $count
                $totalFiles++
                
                Write-Host "  [OK] Updated: $($file.Name) - $count replacements" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "  [ERROR] Error processing: $($file.Name)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Replacement Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files Updated: $totalFiles" -ForegroundColor Green
Write-Host "Total Replacements: $totalReplacements" -ForegroundColor Green
Write-Host ""
Write-Host "Domain changed from: $oldDomain" -ForegroundColor Yellow
Write-Host "                 to: $newDomain" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Review the changes with: git diff" -ForegroundColor White
Write-Host "2. Rebuild the Flutter app: flutter clean" -ForegroundColor White
Write-Host "3. Then: flutter pub get" -ForegroundColor White
Write-Host "4. Then: flutter build apk" -ForegroundColor White
Write-Host "5. Test all API endpoints on the new domain" -ForegroundColor White
Write-Host ""
