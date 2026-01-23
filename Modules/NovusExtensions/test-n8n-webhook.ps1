$webhookUrl = "https://n8n-nov-sb1-u65757.vm.elestio.app/webhook/cipp-security-alert"
$webhookSecret = "81eaa7f5-e1f8-4452-9cc1-f91e78d561f6"

# Build test payload
$testPayload = @{
    eventType = "SecurityAlert"
    eventSubType = "TestAlert"
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    source = "CIPP-Test"
    version = "1.0"
    tenant = @{
        id = "test-tenant-id"
        name = "Test Client"
        defaultDomain = "testclient.onmicrosoft.com"
        complianceRequirements = @("HIPAA")
        riskProfile = "high"
    }
    alert = @{
        id = "test-alert-123"
        type = "TestSecurityAlert"
        severity = "high"
        title = "Test Security Alert for n8n Validation"
        description = "Testing HMAC authentication and Claude AI analysis"
    }
    context = @{
        secureScore = @{
            current = 245
            max = 340
            percentage = 72.06
        }
    }
    metadata = @{
        cippdUrl = "https://cipp.novustek.io"
        correlationId = "test-" + [guid]::NewGuid().ToString()
    }
} | ConvertTo-Json -Depth 10 -Compress

# Generate HMAC signature
$hmacsha = New-Object System.Security.Cryptography.HMACSHA256
$hmacsha.Key = [Text.Encoding]::UTF8.GetBytes($webhookSecret)
$hash = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($testPayload))
$signature = [Convert]::ToBase64String($hash)

# Send test webhook
$headers = @{
    'Content-Type' = 'application/json'
    'X-CIPP-Signature' = $signature
    'X-CIPP-Timestamp' = (Get-Date).ToUniversalTime().ToString('o')
    'X-CIPP-Event-Type' = 'SecurityAlert'
}

Write-Host "`n🧪 Testing n8n workflow..." -ForegroundColor Cyan
Write-Host "URL: $webhookUrl`n" -ForegroundColor Gray

try {
    $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $testPayload -Headers $headers
    Write-Host "✅ Test webhook sent successfully!" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Cyan
    Write-Host ($response | ConvertTo-Json -Depth 5) -ForegroundColor Cyan
} catch {
    Write-Host "❌ Test webhook failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "`nError Details:" -ForegroundColor Yellow
        Write-Host $_.ErrorDetails.Message -ForegroundColor Yellow
    }
}
