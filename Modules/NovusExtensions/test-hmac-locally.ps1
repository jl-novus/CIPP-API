# Test HMAC signature calculation to match what n8n should receive
$webhookSecret = "81eaa7f5-e1f8-4452-9cc1-f91e78d561f6"

# This is the exact body structure from the pinData in the workflow
$testPayload = @{
    eventType = "SecurityAlert"
    eventSubType = "TestAlert"
    timestamp = "2026-01-23T09:28:15.1677428Z"  # Use fixed timestamp for testing
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
        correlationId = "test-234da113-0726-4b05-bff5-6e2304ae045d"
    }
}

Write-Host "`n=== PowerShell Signature Calculation ===" -ForegroundColor Cyan

# Convert to JSON (PowerShell style)
$jsonPayload = $testPayload | ConvertTo-Json -Depth 10 -Compress
Write-Host "`nPayload length: $($jsonPayload.Length)" -ForegroundColor Gray
Write-Host "Payload preview:" -ForegroundColor Gray
Write-Host $jsonPayload.Substring(0, [Math]::Min(200, $jsonPayload.Length)) -ForegroundColor Gray

# Calculate HMAC
$hmacsha = New-Object System.Security.Cryptography.HMACSHA256
$hmacsha.Key = [Text.Encoding]::UTF8.GetBytes($webhookSecret)
$hash = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($jsonPayload))
$signature = [Convert]::ToBase64String($hash)

Write-Host "`nPowerShell HMAC Signature:" -ForegroundColor Yellow
Write-Host $signature -ForegroundColor Green

Write-Host "`n=== JavaScript Signature Calculation (JSON.stringify) ===" -ForegroundColor Cyan

# Simulate what JavaScript JSON.stringify does
$jsPayload = $testPayload | ConvertTo-Json -Depth 10 -Compress
Write-Host "`nJS Payload length: $($jsPayload.Length)" -ForegroundColor Gray

# Calculate what JS would produce
$hmacsha2 = New-Object System.Security.Cryptography.HMACSHA256
$hmacsha2.Key = [Text.Encoding]::UTF8.GetBytes($webhookSecret)
$hash2 = $hmacsha2.ComputeHash([Text.Encoding]::UTF8.GetBytes($jsPayload))
$jsSignature = [Convert]::ToBase64String($hash2)

Write-Host "`nJavaScript HMAC Signature:" -ForegroundColor Yellow
Write-Host $jsSignature -ForegroundColor Green

if ($signature -eq $jsSignature) {
    Write-Host "`n✅ Signatures MATCH!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Signatures DO NOT MATCH!" -ForegroundColor Red
    Write-Host "This indicates a JSON formatting difference." -ForegroundColor Yellow
}

Write-Host "`n=== Key Differences to Check ===" -ForegroundColor Cyan
Write-Host "1. Property order (PowerShell vs JS)" -ForegroundColor Gray
Write-Host "2. Number formatting (72.06 vs 72.060000)" -ForegroundColor Gray
Write-Host "3. Array formatting" -ForegroundColor Gray
Write-Host "4. Whitespace (should be none with -Compress)" -ForegroundColor Gray
