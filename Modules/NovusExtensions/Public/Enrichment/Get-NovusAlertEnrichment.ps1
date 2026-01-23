# NOVUS CUSTOM: Enrich alert data with context for AI analysis

function Get-NovusAlertEnrichment {
    <#
    .SYNOPSIS
        Enriches alert data with contextual information for Claude AI analysis.

    .DESCRIPTION
        Fetches related alerts, tenant history, Microsoft Secure Score, and compliance
        context to provide Claude AI with comprehensive data for security analysis and
        remediation recommendations.

        Enrichment includes:
        - Related alerts from past 7 days (pattern detection)
        - Tenant alert history statistics (30-day trends)
        - Microsoft Secure Score (security posture)
        - Last security incident timestamp

    .PARAMETER TenantFilter
        The tenant's default domain name.

    .PARAMETER AlertData
        The current alert data hashtable containing alert type and details.

    .EXAMPLE
        $enrichment = Get-NovusAlertEnrichment -TenantFilter 'aretehealth.onmicrosoft.com' -AlertData $alert
        # Returns enriched context for AI analysis

    .NOTES
        Performance: This function makes multiple API calls and table queries. Consider
        caching enrichment data for high-frequency alerts.

        Error Handling: Enrichment failures are non-fatal - returns partial data rather
        than blocking webhook delivery.
    #>

    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$AlertData
    )

    begin {
        Write-Verbose "Enriching alert data for tenant: $TenantFilter, alert type: $($AlertData.type)"
    }

    process {
        # Initialize enrichment object with empty defaults (non-fatal if enrichment fails)
        $enrichment = @{
            relatedAlerts     = @()
            tenantHistory     = @{
                similarAlertsLast7Days  = 0
                similarAlertsLast30Days = 0
                lastSecurityIncident    = $null
            }
            complianceContext = @{}
            secureScore       = @{}
        }

        try {
            # 1. Get related alerts from last 7 days
            try {
                $alertTable = Get-CIPPTable -tablename 'CippAlerts'
                $sevenDaysAgo = (Get-Date).AddDays(-7).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                $filter = "PartitionKey eq '$TenantFilter' and Timestamp ge datetime'$sevenDaysAgo'"

                $recentAlerts = Get-CIPPAzDataTableEntity @alertTable -Filter $filter

                if ($recentAlerts) {
                    $enrichment.relatedAlerts = $recentAlerts | Select-Object -First 10 | ForEach-Object {
                        @{
                            type      = $_.AlertType ?? $_.Type
                            timestamp = $_.Timestamp
                            message   = $_.Title ?? $_.Message
                            severity  = $_.Severity
                        }
                    }

                    Write-Verbose "Found $($enrichment.relatedAlerts.Count) related alerts in last 7 days"
                } else {
                    Write-Verbose "No related alerts found in last 7 days"
                }
            } catch {
                Write-Warning "Failed to retrieve related alerts: $_"
                # Non-fatal - continue with empty related alerts
            }

            # 2. Get tenant alert history statistics
            try {
                if ($AlertData.type) {
                    # Count similar alerts in last 7 days
                    $enrichment.tenantHistory.similarAlertsLast7Days = (
                        $recentAlerts | Where-Object {
                            $_.AlertType -eq $AlertData.type -or $_.Type -eq $AlertData.type
                        }
                    ).Count

                    # Count similar alerts in last 30 days
                    $thirtyDaysAgo = (Get-Date).AddDays(-30).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $filter30 = "PartitionKey eq '$TenantFilter' and Timestamp ge datetime'$thirtyDaysAgo'"
                    $alerts30Days = Get-CIPPAzDataTableEntity @alertTable -Filter $filter30

                    $enrichment.tenantHistory.similarAlertsLast30Days = (
                        $alerts30Days | Where-Object {
                            $_.AlertType -eq $AlertData.type -or $_.Type -eq $AlertData.type
                        }
                    ).Count

                    # Find last high/critical security incident
                    $lastIncident = $recentAlerts |
                        Where-Object { $_.Severity -in @('High', 'Critical') } |
                        Sort-Object -Property Timestamp -Descending |
                        Select-Object -First 1

                    if ($lastIncident) {
                        $enrichment.tenantHistory.lastSecurityIncident = $lastIncident.Timestamp
                    }

                    Write-Verbose "Alert history: $($enrichment.tenantHistory.similarAlertsLast7Days) similar in 7d, $($enrichment.tenantHistory.similarAlertsLast30Days) in 30d"
                }
            } catch {
                Write-Warning "Failed to retrieve tenant alert history: $_"
                # Non-fatal - continue with zero counts
            }

            # 3. Get Microsoft Secure Score
            try {
                $secureScoreUri = 'https://graph.microsoft.com/v1.0/security/secureScores?$top=1'
                $secureScoreData = New-GraphGetRequest -uri $secureScoreUri -tenantid $TenantFilter -noPagination $true

                if ($secureScoreData -and $secureScoreData[0]) {
                    $score = $secureScoreData[0]
                    $enrichment.secureScore = @{
                        current        = $score.currentScore
                        max            = $score.maxScore
                        percentage     = [math]::Round(($score.currentScore / $score.maxScore) * 100, 2)
                        lastUpdated    = $score.createdDateTime
                        controlScores  = $score.controlScores.Count
                    }

                    Write-Verbose "Secure Score: $($enrichment.secureScore.current)/$($enrichment.secureScore.max) ($($enrichment.secureScore.percentage)%)"
                } else {
                    Write-Verbose "No Secure Score data available"
                }
            } catch {
                Write-Warning "Failed to retrieve Secure Score: $_"
                # Non-fatal - continue without secure score
            }

            # 4. Get compliance context (from BPA or standards reports)
            # TODO: Implement compliance context enrichment from BPA/standards tables
            # This could include:
            # - Latest BPA test results
            # - Standards alignment scores
            # - Recent drift detections
            # - Compliance violation history

            Write-Verbose "Alert enrichment completed successfully"
            return $enrichment

        } catch {
            # If enrichment completely fails, return empty structure rather than blocking webhook
            Write-Error "Alert enrichment failed: $_"
            Write-Warning "Returning minimal enrichment data to prevent webhook failure"

            return @{
                relatedAlerts     = @()
                tenantHistory     = @{
                    similarAlertsLast7Days  = 0
                    similarAlertsLast30Days = 0
                    lastSecurityIncident    = $null
                }
                complianceContext = @{}
                secureScore       = @{}
                enrichmentError   = $_.Exception.Message
            }
        }
    }
}