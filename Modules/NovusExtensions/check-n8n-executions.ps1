$apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNGQ0ZDZjZi0xOGI3LTQ2YWItOTNlNy0wNzY3ZTRhNmJlMzYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTU5MDg5LCJleHAiOjE3NzE3MzY0MDB9.X7P9roWb06NFgwCUJIwFPgz4e1EmaZFLS9r0zKG4gEE"
$baseUrl = "https://n8n-nov-sb1-u65757.vm.elestio.app/api/v1"

$headers = @{
    "X-N8N-API-KEY" = $apiKey
    "Accept" = "application/json"
}

Write-Host "`nFetching recent workflow executions..." -ForegroundColor Cyan

try {
    # Get executions (most recent first)
    $executions = Invoke-RestMethod -Uri "$baseUrl/executions?limit=3" -Method Get -Headers $headers

    if ($executions.data.Count -gt 0) {
        Write-Host "`nFound $($executions.data.Count) recent executions:" -ForegroundColor Green

        foreach ($exec in $executions.data) {
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "Execution ID: $($exec.id)" -ForegroundColor Yellow
            Write-Host "  Status: $($exec.status)" -ForegroundColor $(if ($exec.status -eq "error") { "Red" } else { "Green" })
            Write-Host "  Mode: $($exec.mode)" -ForegroundColor Gray
            Write-Host "  Workflow: $($exec.workflowId)" -ForegroundColor Gray
            Write-Host "  Started: $($exec.startedAt)" -ForegroundColor Gray
            Write-Host "  Stopped: $($exec.stoppedAt)" -ForegroundColor Gray

            # If error, get detailed execution data
            if ($exec.status -eq "error") {
                Write-Host "`n  Getting detailed error info..." -ForegroundColor Yellow
                try {
                    $executionDetail = Invoke-RestMethod -Uri "$baseUrl/executions/$($exec.id)" -Method Get -Headers $headers

                    # Look for error in execution data
                    if ($executionDetail.data.resultData) {
                        $resultData = $executionDetail.data.resultData
                        Write-Host "`n  Error Details:" -ForegroundColor Red
                        Write-Host ($resultData | ConvertTo-Json -Depth 10) -ForegroundColor Gray
                    }
                } catch {
                    Write-Host "  Could not get detailed error: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "No executions found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
    }
}
