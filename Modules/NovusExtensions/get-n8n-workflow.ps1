$apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNGQ0ZDZjZi0xOGI3LTQ2YWItOTNlNy0wNzY3ZTRhNmJlMzYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTU5MDg5LCJleHAiOjE3NzE3MzY0MDB9.X7P9roWb06NFgwCUJIwFPgz4e1EmaZFLS9r0zKG4gEE"
$baseUrl = "https://n8n-nov-sb1-u65757.vm.elestio.app/api/v1"

$headers = @{
    "X-N8N-API-KEY" = $apiKey
    "Accept" = "application/json"
}

Write-Host "`nFetching workflows..." -ForegroundColor Cyan

try {
    $workflows = Invoke-RestMethod -Uri "$baseUrl/workflows" -Method Get -Headers $headers

    if ($workflows.data.Count -gt 0) {
        Write-Host "`nFound $($workflows.data.Count) workflows:" -ForegroundColor Green

        foreach ($wf in $workflows.data) {
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "Workflow: $($wf.name)" -ForegroundColor Yellow
            Write-Host "  ID: $($wf.id)" -ForegroundColor Gray
            Write-Host "  Active: $($wf.active)" -ForegroundColor $(if ($wf.active) { "Green" } else { "Yellow" })
            Write-Host "  Created: $($wf.createdAt)" -ForegroundColor Gray
            Write-Host "  Updated: $($wf.updatedAt)" -ForegroundColor Gray

            # Get full workflow details
            if ($wf.name -like "*CIPP*" -or $wf.name -like "*Security*") {
                Write-Host "`n  Getting workflow details..." -ForegroundColor Yellow
                try {
                    $wfDetail = Invoke-RestMethod -Uri "$baseUrl/workflows/$($wf.id)" -Method Get -Headers $headers

                    Write-Host "`n  Nodes:" -ForegroundColor Cyan
                    foreach ($node in $wfDetail.nodes) {
                        Write-Host "    - $($node.name) ($($node.type))" -ForegroundColor Gray
                        if ($node.type -eq "n8n-nodes-base.webhook") {
                            Write-Host "      Webhook Path: $($node.parameters.path)" -ForegroundColor Yellow
                            Write-Host "      Method: $($node.parameters.httpMethod)" -ForegroundColor Yellow
                        }
                    }

                    # Save full workflow to file for inspection
                    $outputFile = "workflow-$($wf.id).json"
                    $wfDetail | ConvertTo-Json -Depth 20 | Set-Content -Path $outputFile
                    Write-Host "`n  Full workflow saved to: $outputFile" -ForegroundColor Green
                } catch {
                    Write-Host "  Could not get workflow details: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "No workflows found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
    }
}
