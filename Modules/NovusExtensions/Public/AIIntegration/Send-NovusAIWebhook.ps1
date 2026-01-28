# NOVUS CUSTOM: Enhanced webhook sender for Claude-Flow AI integration

function Send-NovusAIWebhook {
    <#
    .SYNOPSIS
        Sends enriched alert data to Claude-Flow AI brain with retry logic and HMAC authentication.

    .DESCRIPTION
        Core webhook sender that packages CIPP alerts with tenant context and enrichment data,
        then sends to Claude-Flow for intelligent AI analysis. Claude-Flow provides:
        - Expert agent routing (8 specialized agents)
        - Pattern learning via SONA + EWC++
        - Cross-client pattern sharing (anonymized)
        - Intelligent model routing (75% cost savings)

        Implements:
        - Exponential backoff retry (3 attempts: 2s, 4s, 8s delays)
        - HMAC-SHA256 signature authentication
        - Failure logging to NovusWebhookFailures table
        - Structured payload with event types and metadata

    .PARAMETER EventType
        Type of event being sent: SecurityAlert, DriftDetected, ComplianceReport, AnomalyDetected, LicenseEvent

    .PARAMETER EventSubType
        Specific subtype (e.g., DefenderMalware, MFACompliance, SecureScore)

    .PARAMETER AlertData
        Hashtable containing alert details (type, severity, title, affectedResources, etc.)

    .PARAMETER TenantFilter
        Tenant's default domain name

    .PARAMETER MaxRetries
        Maximum retry attempts (default: 3)

    .PARAMETER IncludeEnrichment
        If specified, adds contextual enrichment data (related alerts, secure score, tenant history)

    .EXAMPLE
        Send-NovusAIWebhook -EventType 'SecurityAlert' -EventSubType 'DefenderMalware' `
                            -AlertData $alert -TenantFilter 'aretehealth.onmicrosoft.com' `
                            -IncludeEnrichment

    .NOTES
        Error Handling: Webhook failures are logged to NovusWebhookFailures table for manual review.
        Alerts continue to flow through existing CIPP channels even if Claude-Flow webhook fails.

        Security: Webhook URL and secret are retrieved from Azure Key Vault, never hardcoded.
        HMAC signature ensures payload integrity and authenticity.

        Performance: Enrichment adds ~2-3 seconds due to API calls. Use -IncludeEnrichment only
        when AI analysis benefits from context (skip for low-priority alerts).

        Architecture: Claude-Flow processes alerts asynchronously, returns correlation ID immediately.
        Actions are queued for n8n executor (simplified - no AI logic in n8n).
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('SecurityAlert', 'DriftDetected', 'ComplianceReport', 'AnomalyDetected', 'LicenseEvent')]
        [string]$EventType,

        [Parameter(Mandatory = $false)]
        [string]$EventSubType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$AlertData,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantFilter,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 5)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeEnrichment
    )

    begin {
        Write-Verbose "Send-NovusAIWebhook: Starting for $EventType ($EventSubType) - Tenant: $TenantFilter"

        # Get Claude-Flow webhook URL and secret from Azure Key Vault
        try {
            # Primary: Claude-Flow webhook endpoint
            $WebhookUrl = Get-ExtensionAPIKey -Extension 'ClaudeFlow-Webhook-URL'
            $WebhookSecret = Get-ExtensionAPIKey -Extension 'ClaudeFlow-Webhook-Secret'

            # Fallback to legacy n8n config if Claude-Flow not configured
            if ([string]::IsNullOrEmpty($WebhookUrl)) {
                Write-Verbose "Claude-Flow URL not found, checking legacy n8n config..."
                $WebhookUrl = Get-ExtensionAPIKey -Extension 'N8N-Webhook-URL'
                $WebhookSecret = Get-ExtensionAPIKey -Extension 'N8N-Webhook-Secret'

                if (![string]::IsNullOrEmpty($WebhookUrl)) {
                    Write-Warning "Using legacy n8n webhook URL. Please configure 'ClaudeFlow-Webhook-URL' for Claude-Flow integration."
                }
            }

            if ([string]::IsNullOrEmpty($WebhookUrl)) {
                throw "Webhook URL not configured in Key Vault. Please add 'ClaudeFlow-Webhook-URL' secret."
            }

            if ([string]::IsNullOrEmpty($WebhookSecret)) {
                throw "Webhook secret not configured in Key Vault. Please add 'ClaudeFlow-Webhook-Secret' secret."
            }

            Write-Verbose "Webhook configuration retrieved successfully: $($WebhookUrl.Substring(0, [Math]::Min(50, $WebhookUrl.Length)))..."
        } catch {
            Write-Error "Failed to retrieve webhook configuration from Key Vault: $_"
            Write-LogMessage -API 'NovusAIWebhook' -message "Webhook configuration error: $_" -sev Error
            throw
        }
    }

    process {
        try {
            # 1. Get tenant context (compliance requirements, risk profile)
            $tenantContext = Get-NovusTenantContext -TenantFilter $TenantFilter

            # 2. Build base payload
            $correlationId = [guid]::NewGuid().ToString()
            $timestamp = (Get-Date).ToUniversalTime().ToString('o')

            $payload = @{
                eventType    = $EventType
                eventSubType = $EventSubType
                timestamp    = $timestamp
                source       = 'CIPP-Novus'
                version      = '2.0'  # Claude-Flow integration version
                tenant       = $tenantContext
                alert        = $AlertData
                metadata     = @{
                    cippUrl           = $env:CIPP_URL ?? 'https://cipp.novustek.io'
                    correlationId     = $correlationId
                    webhookRetryCount = 0
                    integration       = 'claude-flow'  # Target system identifier
                }
            }

            # 3. Add enrichment if requested
            if ($IncludeEnrichment) {
                Write-Verbose "Including alert enrichment data"
                try {
                    $payload.context = Get-NovusAlertEnrichment -TenantFilter $TenantFilter -AlertData $AlertData
                } catch {
                    Write-Warning "Alert enrichment failed, continuing without enrichment: $_"
                    $payload.context = @{ enrichmentError = $_.Exception.Message }
                }
            }

            # 4. Convert to JSON
            $jsonPayload = $payload | ConvertTo-Json -Depth 20 -Compress

            Write-Verbose "Payload size: $($jsonPayload.Length) bytes"

            # 5. Generate HMAC signature
            $signature = Get-NovusHMACSignature -Message $jsonPayload -Secret $WebhookSecret

            # 6. Send webhook with retry logic (exponential backoff)
            $retryCount = 0
            $success = $false
            $lastError = $null

            while ($retryCount -lt $MaxRetries -and -not $success) {
                try {
                    if ($PSCmdlet.ShouldProcess($WebhookUrl, "Send $EventType webhook (attempt $($retryCount + 1)/$MaxRetries)")) {
                        $headers = @{
                            'Content-Type'      = 'application/json'
                            'X-CIPP-Signature'  = $signature
                            'X-CIPP-Timestamp'  = $timestamp
                            'X-CIPP-Event-Type' = $EventType
                            'User-Agent'        = 'CIPP-Novus-AI/1.0'
                        }

                        Write-Verbose "Sending webhook to $WebhookUrl (attempt $($retryCount + 1))"

                        $response = Invoke-RestMethod -Uri $WebhookUrl `
                            -Method Post `
                            -Body $jsonPayload `
                            -Headers $headers `
                            -TimeoutSec 30 `
                            -ErrorAction Stop

                        $success = $true
                        Write-LogMessage -API 'NovusAIWebhook' `
                            -message "Successfully sent $EventType webhook for $TenantFilter (correlation: $correlationId)" `
                            -sev Info

                        Write-Verbose "Webhook delivered successfully. Response: $($response | ConvertTo-Json -Compress)"

                        return @{
                            success       = $true
                            correlationId = $correlationId
                            response      = $response
                            retryCount    = $retryCount
                        }
                    }
                } catch {
                    $retryCount++
                    $lastError = $_
                    $waitTime = [math]::Pow(2, $retryCount) # Exponential backoff: 2s, 4s, 8s

                    if ($retryCount -lt $MaxRetries) {
                        Write-Warning "Webhook send failed (attempt $retryCount/$MaxRetries), retrying in ${waitTime}s: $($_.Exception.Message)"
                        Start-Sleep -Seconds $waitTime

                        # Update retry count in metadata for next attempt
                        $payload.metadata.webhookRetryCount = $retryCount
                        $jsonPayload = $payload | ConvertTo-Json -Depth 20 -Compress
                        $signature = Get-NovusHMACSignature -Message $jsonPayload -Secret $WebhookSecret
                    } else {
                        Write-Error "Webhook send failed after $MaxRetries attempts: $($_.Exception.Message)"

                        Write-LogMessage -API 'NovusAIWebhook' `
                            -message "Failed to send webhook after $MaxRetries attempts: $($_.Exception.Message)" `
                            -sev Error `
                            -LogData (Get-CippException -Exception $_)

                        # Log to failure table for manual investigation
                        try {
                            $failureTable = Get-CIPPTable -tablename 'NovusWebhookFailures'
                            $failureEntity = @{
                                PartitionKey  = $TenantFilter
                                RowKey        = $correlationId
                                EventType     = $EventType
                                EventSubType  = $EventSubType
                                Timestamp     = $timestamp
                                PayloadSize   = $jsonPayload.Length
                                Error         = $_.Exception.Message
                                RetryCount    = $retryCount
                                PayloadPreview = $jsonPayload.Substring(0, [math]::Min(1000, $jsonPayload.Length))
                            }
                            Add-CIPPAzDataTableEntity @failureTable -Entity $failureEntity -Force

                            Write-Verbose "Failure logged to NovusWebhookFailures table for manual review"
                        } catch {
                            Write-Warning "Failed to log webhook failure to table: $_"
                        }

                        return @{
                            success       = $false
                            correlationId = $correlationId
                            error         = $lastError.Exception.Message
                            retryCount    = $retryCount
                        }
                    }
                }
            }

        } catch {
            Write-Error "Failed to send AI webhook: $_"
            Write-LogMessage -API 'NovusAIWebhook' `
                -message "Webhook send error: $_" `
                -sev Error `
                -LogData (Get-CippException -Exception $_)
            throw
        }
    }
}