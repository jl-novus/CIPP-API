# NOVUS CUSTOM: Alert orchestrator for AI processing pipeline

function Start-NovusAIAlertOrchestrator {
    <#
    .SYNOPSIS
        Orchestrates CIPP alerts for AI processing via n8n/Claude-Flow.

    .DESCRIPTION
        Runs on a timer (every 5 minutes) to:
        1. Read unprocessed alerts from CippLogs table (Severity = 'Alert')
        2. Filter to supported alert types (security, compliance, drift)
        3. Enrich with tenant context and compliance requirements
        4. Send to AI webhook for Claude analysis
        5. Mark as processed to avoid duplicates

        This is the main entry point for the AI automation pipeline.

    .PARAMETER MaxAlerts
        Maximum number of alerts to process per run (default: 50)

    .PARAMETER LookbackHours
        How far back to look for unprocessed alerts (default: 24 hours)

    .PARAMETER IncludeEnrichment
        Include contextual enrichment (related alerts, secure score)

    .PARAMETER WhatIf
        Show what would be processed without actually sending webhooks

    .EXAMPLE
        Start-NovusAIAlertOrchestrator -MaxAlerts 10 -Verbose
        Process up to 10 unprocessed alerts with verbose logging

    .EXAMPLE
        Start-NovusAIAlertOrchestrator -LookbackHours 1 -IncludeEnrichment
        Process alerts from last hour with full enrichment

    .NOTES
        Timer Configuration: Add to CIPPTimers.json with 5-minute interval
        Error Handling: Continues processing if individual alerts fail
        Idempotency: Uses NovusAIProcessedAlerts table to track processed IDs
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$MaxAlerts = 50,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 168)]  # Max 1 week
        [int]$LookbackHours = 24,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeEnrichment
    )

    begin {
        Write-Verbose "Start-NovusAIAlertOrchestrator: Starting run at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

        $stats = @{
            alertsFound      = 0
            alertsProcessed  = 0
            alertsSkipped    = 0
            alertsFailed     = 0
            webhooksSent     = 0
            startTime        = Get-Date
        }

        # Supported alert types for AI processing
        $supportedAPIs = @(
            'Alerts',
            'BestPracticeAnalyser',
            'Standards',
            'DomainAnalyser',
            'Scheduler_Alert',
            'Scheduler_Billing',
            'Push_CIPPAlert'
        )
    }

    process {
        try {
            # 1. Get CippLogs table
            $logsTable = Get-CIPPTable -tablename 'CippLogs'

            # 2. Get processed alerts tracking table
            $processedTable = Get-CIPPTable -tablename 'NovusAIProcessedAlerts'

            # 3. Calculate date range for query
            $lookbackDate = (Get-Date).AddHours(-$LookbackHours)
            $partitionKeys = @()

            # Build list of partition keys to check (YYYYMMDD format)
            $currentDate = $lookbackDate.Date
            while ($currentDate -le (Get-Date).Date) {
                $partitionKeys += $currentDate.ToString('yyyyMMdd')
                $currentDate = $currentDate.AddDays(1)
            }

            Write-Verbose "Checking partitions: $($partitionKeys -join ', ')"

            # 4. Query for alert-level logs
            $allAlerts = @()
            foreach ($pk in $partitionKeys) {
                $filter = "PartitionKey eq '$pk' and Severity eq 'Alert'"
                try {
                    $partitionAlerts = Get-CIPPAzDataTableEntity @logsTable -Filter $filter
                    if ($partitionAlerts) {
                        $allAlerts += $partitionAlerts
                    }
                } catch {
                    Write-Warning "Failed to query partition $pk : $_"
                }
            }

            Write-Verbose "Found $($allAlerts.Count) total alerts in date range"
            $stats.alertsFound = $allAlerts.Count

            if ($allAlerts.Count -eq 0) {
                Write-Verbose "No alerts found in the specified date range"
                return $stats
            }

            # 5. Filter to supported APIs and get already-processed IDs
            $filteredAlerts = $allAlerts | Where-Object { $_.API -in $supportedAPIs }
            Write-Verbose "Filtered to $($filteredAlerts.Count) alerts from supported APIs"

            # 6. Get already-processed alert IDs
            $processedIds = @()
            try {
                $processedEntities = Get-CIPPAzDataTableEntity @processedTable -Filter "PartitionKey ge '$($partitionKeys[0])'"
                $processedIds = $processedEntities | ForEach-Object { $_.RowKey }
                Write-Verbose "Found $($processedIds.Count) already-processed alerts"
            } catch {
                Write-Verbose "No processed alerts table or empty: $_"
            }

            # 7. Filter to unprocessed only
            $unprocessedAlerts = $filteredAlerts | Where-Object { $_.RowKey -notin $processedIds }
            Write-Verbose "Found $($unprocessedAlerts.Count) unprocessed alerts"

            # 8. Limit to MaxAlerts
            $alertsToProcess = $unprocessedAlerts | Select-Object -First $MaxAlerts

            if ($alertsToProcess.Count -eq 0) {
                Write-Verbose "No new alerts to process"
                return $stats
            }

            Write-Host "Processing $($alertsToProcess.Count) alerts..." -ForegroundColor Cyan

            # 9. Process each alert
            foreach ($alert in $alertsToProcess) {
                try {
                    Write-Verbose "Processing alert: $($alert.RowKey) - $($alert.Tenant) - $($alert.API)"

                    # Determine event type based on API
                    $eventType = switch ($alert.API) {
                        'Alerts' { 'SecurityAlert' }
                        'BestPracticeAnalyser' { 'ComplianceReport' }
                        'Standards' { 'DriftDetected' }
                        'DomainAnalyser' { 'SecurityAlert' }
                        'Scheduler_Alert' { 'SecurityAlert' }
                        'Scheduler_Billing' { 'LicenseEvent' }
                        'Push_CIPPAlert' { 'SecurityAlert' }
                        default { 'SecurityAlert' }
                    }

                    # Parse LogData if present
                    $logData = @{}
                    if ($alert.LogData) {
                        try {
                            $logData = $alert.LogData | ConvertFrom-Json -AsHashtable
                        } catch {
                            Write-Verbose "Could not parse LogData as JSON"
                        }
                    }

                    # Build alert data structure
                    $alertData = @{
                        id              = $alert.RowKey
                        type            = $alert.API
                        severity        = 'high'  # CIPP alerts are important by definition
                        title           = $alert.Message
                        description     = $alert.Message
                        timestamp       = $alert.Timestamp ?? (Get-Date).ToUniversalTime().ToString('o')
                        affectedResources = @()
                        rawLogData      = $logData
                    }

                    # Add standard info if present
                    if ($alert.Standard) {
                        $alertData.standard = $alert.Standard
                        $alertData.standardTemplateId = $alert.StandardTemplateId
                    }

                    # Get tenant filter (domain name)
                    $tenantFilter = $alert.Tenant
                    if ($tenantFilter -eq 'None' -or [string]::IsNullOrEmpty($tenantFilter)) {
                        Write-Verbose "Skipping alert with no tenant: $($alert.RowKey)"
                        $stats.alertsSkipped++
                        continue
                    }

                    # Send to AI webhook
                    if ($PSCmdlet.ShouldProcess("$tenantFilter - $($alert.Message)", "Send to AI webhook")) {
                        $webhookParams = @{
                            EventType     = $eventType
                            EventSubType  = $alert.API
                            AlertData     = $alertData
                            TenantFilter  = $tenantFilter
                        }

                        if ($IncludeEnrichment) {
                            $webhookParams.IncludeEnrichment = $true
                        }

                        $result = Send-NovusAIWebhook @webhookParams

                        if ($result.success) {
                            $stats.webhooksSent++
                            Write-Verbose "Webhook sent successfully: $($result.correlationId)"

                            # Mark as processed
                            $processedEntity = @{
                                PartitionKey  = $alert.PartitionKey
                                RowKey        = $alert.RowKey
                                ProcessedAt   = (Get-Date).ToUniversalTime().ToString('o')
                                CorrelationId = $result.correlationId
                                EventType     = $eventType
                                Tenant        = $tenantFilter
                            }
                            Add-CIPPAzDataTableEntity @processedTable -Entity $processedEntity -Force

                            $stats.alertsProcessed++
                        } else {
                            Write-Warning "Webhook failed for alert $($alert.RowKey): $($result.error)"
                            $stats.alertsFailed++
                        }
                    } else {
                        Write-Host "WhatIf: Would send alert $($alert.RowKey) to AI webhook" -ForegroundColor Yellow
                        $stats.alertsProcessed++
                    }

                } catch {
                    Write-Warning "Failed to process alert $($alert.RowKey): $_"
                    $stats.alertsFailed++
                }
            }

        } catch {
            Write-Error "Orchestrator failed: $_"
            throw
        }
    }

    end {
        $stats.endTime = Get-Date
        $stats.duration = ($stats.endTime - $stats.startTime).TotalSeconds

        Write-Host "`n=== Orchestrator Run Complete ===" -ForegroundColor Green
        Write-Host "Alerts Found: $($stats.alertsFound)" -ForegroundColor Gray
        Write-Host "Alerts Processed: $($stats.alertsProcessed)" -ForegroundColor Gray
        Write-Host "Alerts Skipped: $($stats.alertsSkipped)" -ForegroundColor Gray
        Write-Host "Alerts Failed: $($stats.alertsFailed)" -ForegroundColor $(if ($stats.alertsFailed -gt 0) { 'Yellow' } else { 'Gray' })
        Write-Host "Webhooks Sent: $($stats.webhooksSent)" -ForegroundColor Cyan
        Write-Host "Duration: $($stats.duration.ToString('F2'))s" -ForegroundColor Gray

        Write-LogMessage -API 'NovusAIOrchestrator' `
            -message "Orchestrator run: $($stats.alertsProcessed) processed, $($stats.webhooksSent) webhooks sent, $($stats.alertsFailed) failed" `
            -sev Info

        return $stats
    }
}