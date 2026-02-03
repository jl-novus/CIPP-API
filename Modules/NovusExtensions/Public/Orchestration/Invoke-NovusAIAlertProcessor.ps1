# NOVUS CUSTOM: Real-time alert processor for immediate AI analysis

function Invoke-NovusAIAlertProcessor {
    <#
    .SYNOPSIS
        Processes a single CIPP alert for immediate AI analysis.

    .DESCRIPTION
        Called directly from CIPP alert functions for real-time AI processing.
        Use this for high-priority alerts that need immediate analysis rather
        than waiting for the batch orchestrator (5-minute timer).

        Automatically:
        - Maps CIPP alert types to AI event types
        - Determines severity based on alert context
        - Includes compliance context for HIPAA/SOC2 clients
        - Sends to AI webhook with enrichment (optional)

    .PARAMETER AlertType
        CIPP alert type (DefenderMalware, MFAAlert, SecureScore, etc.)

    .PARAMETER TenantFilter
        Tenant's default domain name

    .PARAMETER Message
        Alert message/description

    .PARAMETER AlertDetails
        Hashtable with additional alert details (affectedResources, etc.)

    .PARAMETER Severity
        Override severity: critical, high, medium, low (default: auto-detect)

    .PARAMETER SkipEnrichment
        Skip contextual enrichment to speed up processing

    .EXAMPLE
        Invoke-NovusAIAlertProcessor -AlertType 'DefenderMalware' `
            -TenantFilter 'aretehealth.onmicrosoft.com' `
            -Message 'Malware detected on user device' `
            -AlertDetails @{ affectedUser = 'john@aretehealth.com'; malwareType = 'Trojan' }

    .EXAMPLE
        Invoke-NovusAIAlertProcessor -AlertType 'MFAAlert' `
            -TenantFilter 'cafemoto.onmicrosoft.com' `
            -Message 'Admin account without MFA detected' `
            -Severity 'critical' `
            -SkipEnrichment

    .NOTES
        Integration Point: Call this from existing CIPP alert functions to
        add AI analysis without modifying core CIPP code.

        Error Handling: Returns result hashtable with success status.
        Original CIPP alert flow continues regardless of AI webhook result.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AlertType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [hashtable]$AlertDetails = @{},

        [Parameter(Mandatory = $false)]
        [ValidateSet('critical', 'high', 'medium', 'low', 'auto')]
        [string]$Severity = 'auto',

        [Parameter(Mandatory = $false)]
        [switch]$SkipEnrichment
    )

    begin {
        Write-Verbose "Invoke-NovusAIAlertProcessor: Processing $AlertType for $TenantFilter"

        # Map CIPP alert types to AI event types
        $eventTypeMap = @{
            # Security Alerts
            'DefenderMalware'        = @{ EventType = 'SecurityAlert'; Severity = 'critical' }
            'DefenderIncident'       = @{ EventType = 'SecurityAlert'; Severity = 'critical' }
            'MFAAlert'               = @{ EventType = 'SecurityAlert'; Severity = 'high' }
            'MFAAdminAlert'          = @{ EventType = 'SecurityAlert'; Severity = 'critical' }
            'NewAppAlert'            = @{ EventType = 'SecurityAlert'; Severity = 'medium' }
            'AppSecretExpiry'        = @{ EventType = 'SecurityAlert'; Severity = 'high' }
            'NoCAConfig'             = @{ EventType = 'SecurityAlert'; Severity = 'high' }
            'AdminAuditLog'          = @{ EventType = 'SecurityAlert'; Severity = 'medium' }
            'SecureScore'            = @{ EventType = 'SecurityAlert'; Severity = 'medium' }
            'UnusedLicenses'         = @{ EventType = 'LicenseEvent'; Severity = 'low' }
            'OverusedLicenses'       = @{ EventType = 'LicenseEvent'; Severity = 'medium' }
            'NewRole'                = @{ EventType = 'SecurityAlert'; Severity = 'high' }
            'QuotaUsed'              = @{ EventType = 'AnomalyDetected'; Severity = 'medium' }
            'NewBreachPassword'      = @{ EventType = 'SecurityAlert'; Severity = 'critical' }

            # Compliance & Drift
            'DriftDetected'          = @{ EventType = 'DriftDetected'; Severity = 'high' }
            'StandardsNotApplied'    = @{ EventType = 'DriftDetected'; Severity = 'high' }
            'BPANotMet'              = @{ EventType = 'ComplianceReport'; Severity = 'medium' }

            # Domain & Email
            'DomainExpiring'         = @{ EventType = 'AnomalyDetected'; Severity = 'high' }
            'SPFNotValid'            = @{ EventType = 'SecurityAlert'; Severity = 'high' }
            'DKIMNotValid'           = @{ EventType = 'SecurityAlert'; Severity = 'high' }
            'DMARCNotValid'          = @{ EventType = 'SecurityAlert'; Severity = 'high' }
            'MXRecordChanged'        = @{ EventType = 'SecurityAlert'; Severity = 'high' }

            # Tenant Health
            'ExcludedTenants'        = @{ EventType = 'AnomalyDetected'; Severity = 'medium' }
            'TokenExpiring'          = @{ EventType = 'AnomalyDetected'; Severity = 'high' }
        }

        # Default mapping for unknown types
        $defaultMapping = @{ EventType = 'SecurityAlert'; Severity = 'medium' }
    }

    process {
        try {
            # 1. Get event type and default severity from mapping
            $mapping = $eventTypeMap[$AlertType] ?? $defaultMapping
            $eventType = $mapping.EventType
            $detectedSeverity = $mapping.Severity

            # 2. Override severity if specified
            if ($Severity -ne 'auto') {
                $detectedSeverity = $Severity
            }

            Write-Verbose "Mapped to EventType: $eventType, Severity: $detectedSeverity"

            # 3. Build alert data structure
            $alertData = @{
                id               = [guid]::NewGuid().ToString()
                type             = $AlertType
                severity         = $detectedSeverity
                title            = $Message
                description      = $Message
                timestamp        = (Get-Date).ToUniversalTime().ToString('o')
                affectedResources = @()
            }

            # Merge additional details
            foreach ($key in $AlertDetails.Keys) {
                if ($key -eq 'affectedResources') {
                    $alertData.affectedResources = $AlertDetails[$key]
                } else {
                    $alertData[$key] = $AlertDetails[$key]
                }
            }

            # 4. Prepare webhook parameters
            $webhookParams = @{
                EventType    = $eventType
                EventSubType = $AlertType
                AlertData    = $alertData
                TenantFilter = $TenantFilter
            }

            if (-not $SkipEnrichment) {
                $webhookParams.IncludeEnrichment = $true
            }

            # 5. Send to AI webhook
            if ($PSCmdlet.ShouldProcess("$TenantFilter - $AlertType", "Send to AI webhook for analysis")) {
                Write-Verbose "Sending to AI webhook..."
                $result = Send-NovusAIWebhook @webhookParams

                if ($result.success) {
                    Write-Verbose "AI webhook sent successfully: $($result.correlationId)"
                    Write-LogMessage -API 'NovusAIProcessor' `
                        -message "Processed $AlertType for $TenantFilter (correlation: $($result.correlationId))" `
                        -sev Info `
                        -tenant $TenantFilter

                    return @{
                        success       = $true
                        correlationId = $result.correlationId
                        eventType     = $eventType
                        severity      = $detectedSeverity
                        retryCount    = $result.retryCount
                    }
                } else {
                    Write-Warning "AI webhook failed: $($result.error)"
                    return @{
                        success = $false
                        error   = $result.error
                    }
                }
            } else {
                Write-Host "WhatIf: Would send $AlertType to AI webhook for $TenantFilter" -ForegroundColor Yellow
                return @{
                    success = $true
                    whatIf  = $true
                }
            }

        } catch {
            Write-Warning "Failed to process alert for AI analysis: $_"
            Write-LogMessage -API 'NovusAIProcessor' `
                -message "Failed to process $AlertType for $TenantFilter: $_" `
                -sev Warning `
                -tenant $TenantFilter

            return @{
                success = $false
                error   = $_.Exception.Message
            }
        }
    }
}
