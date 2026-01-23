$apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNGQ0ZDZjZi0xOGI3LTQ2YWItOTNlNy0wNzY3ZTRhNmJlMzYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTU5MDg5LCJleHAiOjE3NzE3MzY0MDB9.X7P9roWb06NFgwCUJIwFPgz4e1EmaZFLS9r0zKG4gEE"
$baseUrl = "https://n8n-nov-sb1-u65757.vm.elestio.app/api/v1"
$workflowId = "mdTN_6v9wWf4Tq51iLypv"

$headers = @{
    "X-N8N-API-KEY" = $apiKey
    "Accept" = "application/json"
    "Content-Type" = "application/json"
}

# Read the debug HMAC validation code
$hmacCode = Get-Content "hmac-validation-debug.js" -Raw

Write-Host "`nReading current workflow..." -ForegroundColor Cyan

try {
    # Get the current workflow
    $workflow = Invoke-RestMethod -Uri "$baseUrl/workflows/$workflowId" -Method Get -Headers $headers

    Write-Host "Found workflow: $($workflow.name)" -ForegroundColor Green

    # Find the HMAC validation node and update it
    $hmacNode = $workflow.nodes | Where-Object { $_.name -eq "Validate HMAC Signature" }

    if ($hmacNode) {
        Write-Host "Updating HMAC Signature validation code..." -ForegroundColor Yellow
        $hmacNode.parameters.jsCode = $hmacCode

        # Update the workflow
        $updatePayload = @{
            name = $workflow.name
            nodes = $workflow.nodes
            connections = $workflow.connections
            settings = $workflow.settings
            staticData = $workflow.staticData
        } | ConvertTo-Json -Depth 20

        $result = Invoke-RestMethod -Uri "$baseUrl/workflows/$workflowId" -Method Put -Headers $headers -Body $updatePayload

        Write-Host "`nWorkflow updated successfully!" -ForegroundColor Green
        Write-Host "Version: $($result.versionId)" -ForegroundColor Gray

    } else {
        Write-Host "Could not find 'Validate HMAC Signature' node" -ForegroundColor Red
    }

} catch {
    Write-Host "`nError updating workflow:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
    }
}
