# API Testing Script for LearnerID 11560
# This script tests both POE endpoints on the live server

$learnerID = "11560"
# Using the correct domain from the user input
$baseUrl = "https://www.rlms.rlms.co.za/mobile"
$endpoints = @("/poe.php", "/get_poe.php")

Write-Host "--------------------------------------------------"
Write-Host "Starting API Test for LearnerID: $learnerID"
Write-Host "Server: $baseUrl"
Write-Host "--------------------------------------------------`n"

foreach ($endpoint in $endpoints) {
    $fullUrl = "$baseUrl$endpoint"
    Write-Host "Testing Endpoint: $endpoint"
    Write-Host "URL: $fullUrl"
    
    try {
        # Using curl to avoid PowerShell's web request overhead and potential URI parsing issues
        $result = curl.exe -G -s -L "$fullUrl" --data-urlencode "learnerID=$learnerID"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "CURL FAILED with exit code $LASTEXITCODE" -ForegroundColor Red
            continue
        }

        if ([string]::IsNullOrWhiteSpace($result)) {
            Write-Host "ERROR: Empty response from server." -ForegroundColor Red
        } else {
            Write-Host "Raw Response: $result" -ForegroundColor Gray
            
            try {
                $json = $result | ConvertFrom-Json -ErrorAction Stop
                
                if ($json.error) {
                    Write-Host "SERVER ERROR: $($json.error)" -ForegroundColor Red
                    if ($json.debug) {
                        Write-Host "DEBUG INFO:" -ForegroundColor Yellow
                        $json.debug | Out-String | Write-Host -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "SUCCESS: Data received successfully." -ForegroundColor Green
                }
            } catch {
                Write-Host "ERROR: Could not parse response as JSON." -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "REQUEST FAILED!" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    Write-Host "`n--------------------------------------------------"
}

Write-Host "Test Complete."
