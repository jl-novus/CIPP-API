# NOVUS CUSTOM: Send webhook to n8n workflow automation
# Date: 2026-01-23
# Purpose: Example custom function for n8n integration

<#
.SYNOPSIS
    Sends a webhook notification to n8n workflow automation platform.

.DESCRIPTION
    This function sends structured event data to n8n via webhook for workflow automation.
    Protected from upstream merges via .gitattributes merge=ours strategy.

.PARAMETER EventType
    The type of event being triggered (e.g., TenantProvisioned, AlertRaised, ComplianceReport)

.PARAMETER EventData
    Hashtable containing event-specific data to send to n8n

.PARAMETER WebhookUrl
    The n8n webhook URL (defaults to environment variable N8N_WEBHOOK_URL)

.EXAMPLE
    Send-NovusWebhook -EventType "TenantProvisioned" -EventData @{
        TenantId = "12345"
        TenantName = "Arete Health"
        ProvisionedBy = "jon@novustek.net"
    }

.NOTES
    Author: Novus Technology Integration Inc.
    This is a proof-of-concept example. In production:
    - Webhook URL should be stored in Azure Key Vault
    - Implement retry logic for failed webhooks
    - Add HMAC signature for security
    - Queue webhooks if n8n is unavailable
#>

function Send-NovusWebhook {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('TenantProvisioned', 'AlertRaised', 'ComplianceReport', 'SecurityEvent')]
        [string]$EventType,

        [Parameter(Mandatory = $true)]
        [hashtable]$EventData,

        [Parameter(Mandatory = $false)]
        [string]$WebhookUrl = $env:N8N_WEBHOOK_URL
    )

    begin {
        Write-Verbose "Send-NovusWebhook: Starting webhook send for event type: $EventType"

        if ([string]::IsNullOrEmpty($WebhookUrl)) {
            Write-Error "Webhook URL not configured. Set N8N_WEBHOOK_URL environment variable."
            return
        }
    }

    process {
        try {
            # Build webhook payload
            $payload = @{
                eventType = $EventType
                timestamp = (Get-Date).ToUniversalTime().ToString('o')
                source    = 'CIPP-Novus'
                data      = $EventData
            }

            $jsonPayload = $payload | ConvertTo-Json -Depth 10

            if ($PSCmdlet.ShouldProcess($WebhookUrl, "Send $EventType webhook")) {
                Write-Verbose "Sending webhook to: $WebhookUrl"
                Write-Verbose "Payload: $jsonPayload"

                # Send webhook (in production, add retry logic and error handling)
                $response = Invoke-RestMethod -Uri $WebhookUrl `
                    -Method Post `
                    -Body $jsonPayload `
                    -ContentType 'application/json' `
                    -TimeoutSec 30

                Write-Verbose "Webhook sent successfully. Response: $($response | ConvertTo-Json -Compress)"
                return $response
            }
        }
        catch {
            Write-Error "Failed to send webhook: $_"
            Write-Verbose "Error details: $($_.Exception.Message)"

            # In production, implement:
            # - Queue failed webhooks for retry
            # - Log to Application Insights
            # - Alert on repeated failures

            throw
        }
    }

    end {
        Write-Verbose "Send-NovusWebhook: Completed"
    }
}
