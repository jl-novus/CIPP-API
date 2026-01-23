# n8n API Test and Workflow Creation Script

$apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNGQ0ZDZjZi0xOGI3LTQ2YWItOTNlNy0wNzY3ZTRhNmJlMzYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTU5MDg5LCJleHAiOjE3NzE3MzY0MDB9.X7P9roWb06NFgwCUJIwFPgz4e1EmaZFLS9r0zKG4gEE"
$baseUrl = "https://n8n-nov-sb1-u65757.vm.elestio.app/api/v1"

$headers = @{
    "X-N8N-API-KEY" = $apiKey
    "Accept" = "application/json"
    "Content-Type" = "application/json"
}

Write-Host "`n🔍 Checking existing credentials..." -ForegroundColor Cyan
try {
    $creds = Invoke-RestMethod -Uri "$baseUrl/credentials" -Method Get -Headers $headers
    Write-Host "✅ Found $($creds.data.Count) credentials:" -ForegroundColor Green

    $webhookSecretId = $null
    $anthropicKeyId = $null

    foreach ($cred in $creds.data) {
        Write-Host "  - Name: $($cred.name) | Type: $($cred.type) | ID: $($cred.id)" -ForegroundColor Gray

        if ($cred.name -like "*CIPP*" -or $cred.name -like "*Webhook*") {
            $webhookSecretId = $cred.id
            Write-Host "    → Will use for HMAC validation" -ForegroundColor Yellow
        }
        if ($cred.name -like "*Anthropic*" -or $cred.name -like "*Claude*") {
            $anthropicKeyId = $cred.id
            Write-Host "    → Will use for Claude AI" -ForegroundColor Yellow
        }
    }

    Write-Host "`n📊 Credential IDs identified:" -ForegroundColor Cyan
    Write-Host "  Webhook Secret ID: $webhookSecretId" -ForegroundColor Gray
    Write-Host "  Anthropic API Key ID: $anthropicKeyId" -ForegroundColor Gray

} catch {
    Write-Host "❌ Failed to fetch credentials:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ Script complete. Ready to generate workflow JSON." -ForegroundColor Green
