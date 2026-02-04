# NOVUS CUSTOM: Scheduled asset report sender for Deccan International
# Sends device inventory data to n8n for AI analysis and email delivery

function Send-NovusAssetReport {
    <#
    .SYNOPSIS
        Collects Intune device inventory and sends to n8n for AI analysis and reporting.

    .DESCRIPTION
        This function is designed to be called by CIPP's scheduler or a Timer Function.
        It pulls device data from Intune via CIPP's internal Graph API helper (no external auth needed),
        calculates compliance metrics, and sends the data to an n8n webhook for AI analysis
        and formatted email delivery.

    .PARAMETER TenantFilter
        Tenant's default domain name (e.g., 'deccanintl.onmicrosoft.com')

    .PARAMETER WebhookUrl
        The n8n webhook URL. If not specified, retrieves from Key Vault 'N8N-AssetReport-Webhook-URL'

    .PARAMETER StaleDays
        Number of days without sync to consider a device stale (default: 7)

    .PARAMETER Recipients
        Email recipients for the report (passed to n8n for delivery)

    .EXAMPLE
        Send-NovusAssetReport -TenantFilter 'deccanintl.onmicrosoft.com'

    .EXAMPLE
        Send-NovusAssetReport -TenantFilter 'deccanintl.onmicrosoft.com' -Recipients @('jlucky@novustek.io', 'it@deccanintl.com')

    .NOTES
        Author: Novus Technology Integration Inc.
        Created: 2026-02-03

        This function uses CIPP's internal Graph API access - no external authentication needed.
        n8n handles AI analysis (Claude) and email delivery (SMTP).
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantFilter,

        [Parameter(Mandatory = $false)]
        [string]$WebhookUrl,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 30)]
        [int]$StaleDays = 7,

        [Parameter(Mandatory = $false)]
        [string[]]$Recipients = @('jon@novustek.net')
    )

    begin {
        Write-Verbose "Send-NovusAssetReport: Starting for tenant $TenantFilter"

        # Get webhook URL from Key Vault if not specified
        if ([string]::IsNullOrEmpty($WebhookUrl)) {
            try {
                $WebhookUrl = Get-ExtensionAPIKey -Extension 'N8N-AssetReport-Webhook-URL'

                if ([string]::IsNullOrEmpty($WebhookUrl)) {
                    throw "N8N-AssetReport-Webhook-URL not configured in Key Vault"
                }
            } catch {
                Write-Error "Failed to get webhook URL: $_"
                throw
            }
        }

        # Get webhook secret for HMAC signing
        try {
            $WebhookSecret = Get-ExtensionAPIKey -Extension 'N8N-Webhook-Secret'
        } catch {
            Write-Warning "Webhook secret not found, sending without HMAC signature"
            $WebhookSecret = $null
        }
    }

    process {
        try {
            # 1. Pull device inventory from Intune via CIPP's Graph API
            Write-Verbose "Fetching device inventory from Intune..."

            $devices = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/deviceManagement/managedDevices' -Tenantid $TenantFilter

            if (-not $devices -or $devices.Count -eq 0) {
                Write-Warning "No devices found for tenant $TenantFilter"
                $devices = @()
            }

            Write-Verbose "Retrieved $($devices.Count) devices"

            # 2. Calculate metrics
            $now = Get-Date
            $staleThreshold = $now.AddDays(-$StaleDays)

            $compliantCount = 0
            $nonCompliantCount = 0
            $encryptedCount = 0
            $staleDevices = @()
            $osCounts = @{}

            foreach ($device in $devices) {
                # Compliance
                if ($device.complianceState -eq 'compliant') { $compliantCount++ }
                if ($device.complianceState -eq 'noncompliant') { $nonCompliantCount++ }

                # Encryption
                if ($device.isEncrypted) { $encryptedCount++ }

                # Stale check
                if ($device.lastSyncDateTime) {
                    $lastSync = [datetime]$device.lastSyncDateTime
                    if ($lastSync -lt $staleThreshold) {
                        $staleDevices += @{
                            deviceName        = $device.deviceName
                            userPrincipalName = $device.userPrincipalName
                            lastSyncDateTime  = $device.lastSyncDateTime
                            daysSinceSync     = [math]::Floor(($now - $lastSync).TotalDays)
                        }
                    }
                }

                # OS distribution
                $os = if ($device.operatingSystem) { $device.operatingSystem } else { 'Unknown' }
                if ($osCounts.ContainsKey($os)) {
                    $osCounts[$os]++
                } else {
                    $osCounts[$os] = 1
                }
            }

            $totalDevices = $devices.Count

            # Build summary
            $summary = @{
                totalDevices = $totalDevices
                compliant    = @{
                    count   = $compliantCount
                    percent = if ($totalDevices -gt 0) { [math]::Round(($compliantCount / $totalDevices) * 100, 1) } else { 0 }
                }
                nonCompliant = @{
                    count   = $nonCompliantCount
                    percent = if ($totalDevices -gt 0) { [math]::Round(($nonCompliantCount / $totalDevices) * 100, 1) } else { 0 }
                }
                encrypted    = @{
                    count   = $encryptedCount
                    percent = if ($totalDevices -gt 0) { [math]::Round(($encryptedCount / $totalDevices) * 100, 1) } else { 0 }
                }
                stale        = @{
                    count     = $staleDevices.Count
                    threshold = $StaleDays
                    devices   = $staleDevices
                }
                osDistribution = $osCounts
            }

            # 3. Build device table (limited fields for report)
            $deviceTable = foreach ($d in $devices) {
                @{
                    deviceName      = $d.deviceName
                    serialNumber    = if ($d.serialNumber) { $d.serialNumber } else { 'N/A' }
                    model           = if ($d.model) { $d.model } else { 'N/A' }
                    os              = $d.operatingSystem
                    osVersion       = if ($d.osVersion) { $d.osVersion } else { 'N/A' }
                    user            = if ($d.userPrincipalName) { $d.userPrincipalName } else { 'N/A' }
                    complianceState = $d.complianceState
                    isEncrypted     = if ($d.isEncrypted) { 'Yes' } else { 'No' }
                    lastSync        = $d.lastSyncDateTime
                }
            }

            # 4. Get tenant context for compliance info
            $tenantContext = $null
            try {
                $tenantContext = Get-NovusTenantContext -TenantFilter $TenantFilter
            } catch {
                Write-Warning "Could not get tenant context: $_"
                $tenantContext = @{
                    name          = $TenantFilter
                    defaultDomain = $TenantFilter
                }
            }

            # 5. Build payload for n8n
            $correlationId = [guid]::NewGuid().ToString()
            $timestamp = $now.ToUniversalTime().ToString('o')

            $payload = @{
                eventType   = 'AssetReport'
                timestamp   = $timestamp
                source      = 'CIPP-Novus'
                version     = '1.0'
                correlationId = $correlationId
                tenant      = $tenantContext
                report      = @{
                    reportDate = $timestamp
                    summary    = $summary
                    devices    = $deviceTable
                }
                delivery    = @{
                    recipients = $Recipients
                    subject    = "Weekly Asset Report - $($tenantContext.name ?? $TenantFilter)"
                }
                metadata    = @{
                    cippUrl     = $env:CIPP_URL ?? 'https://cipp.novustek.io'
                    generatedAt = $timestamp
                    staleDays   = $StaleDays
                }
            }

            # 6. Convert to JSON
            $jsonPayload = $payload | ConvertTo-Json -Depth 20 -Compress
            Write-Verbose "Payload size: $($jsonPayload.Length) bytes"

            # 7. Generate HMAC signature if secret available
            $headers = @{
                'Content-Type'      = 'application/json'
                'X-CIPP-Event-Type' = 'AssetReport'
                'X-CIPP-Timestamp'  = $timestamp
                'User-Agent'        = 'CIPP-Novus-AssetReport/1.0'
            }

            if ($WebhookSecret) {
                $signature = Get-NovusHMACSignature -Message $jsonPayload -Secret $WebhookSecret
                $headers['X-CIPP-Signature'] = $signature
            }

            # 8. Send to n8n webhook
            if ($PSCmdlet.ShouldProcess($WebhookUrl, "Send asset report webhook")) {
                Write-Verbose "Sending asset report to n8n webhook..."

                $response = Invoke-RestMethod -Uri $WebhookUrl `
                    -Method Post `
                    -Body $jsonPayload `
                    -Headers $headers `
                    -TimeoutSec 60 `
                    -ErrorAction Stop

                Write-LogMessage -API 'NovusAssetReport' `
                    -message "Asset report sent successfully for $TenantFilter ($totalDevices devices, correlation: $correlationId)" `
                    -sev Info

                Write-Verbose "Asset report delivered successfully"

                return @{
                    success       = $true
                    correlationId = $correlationId
                    deviceCount   = $totalDevices
                    response      = $response
                }
            }

        } catch {
            Write-Error "Failed to send asset report: $_"
            Write-LogMessage -API 'NovusAssetReport' `
                -message "Asset report failed for ${TenantFilter}: $_" `
                -sev Error `
                -LogData (Get-CippException -Exception $_)

            return @{
                success = $false
                error   = $_.Exception.Message
            }
        }
    }

    end {
        Write-Verbose "Send-NovusAssetReport: Completed"
    }
}
