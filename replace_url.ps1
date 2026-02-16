$count = 0
$extensions = @('*.dart', '*.php', '*.md', '*.txt', '*.js', '*.bat', '*.sql', '*.sh', '*.json', '*.yaml', '*.yml')

foreach ($ext in $extensions) {
    $files = Get-ChildItem -Path . -Filter $ext -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.FullName -notmatch '\\(build|linux|windows|\.dart_tool|android\\build|\.git)\\' }
    
    foreach ($file in $files) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction Stop
            if ($content -match 'rlms\.rlms\.co\.za') {
                $newContent = $content -replace 'rlms\.rlms\.co\.za', 'rlms.rlms.co.za'
                Set-Content -Path $file.FullName -Value $newContent -NoNewline
                $count++
                Write-Host "Updated: $($file.FullName)"
            }
        } catch {
            # Skip files that can't be read
        }
    }
}

Write-Host "`nTotal files updated: $count"
