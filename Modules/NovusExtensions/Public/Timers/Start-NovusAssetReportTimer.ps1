# NOVUS CUSTOM: Timer function wrapper for Deccan asset reports
# Called by CIPP Timer system based on CIPPTimers.json schedule

function Start-NovusAssetReportTimer {
    <#
    .SYNOPSIS
        Timer function to send weekly asset reports to n8n for AI analysis.

    .DESCRIPTION
        This function is called by the CIPP Timer system based on the cron schedule
        defined in CIPPTimers.json. It wraps Send-NovusAssetReport for scheduled execution.

    .PARAMETER TenantFilter
        The tenant domain to generate report for (default: deccanintl.onmicrosoft.com)

    .PARAMETER Recipients
        Email recipients for the report

    .EXAMPLE
        Start-NovusAssetReportTimer -TenantFilter 'deccanintl.onmicrosoft.com'

    .NOTES
        Author: Novus Technology Integration Inc.
        Created: 2026-02-03

        Schedule: Every Monday at 8:00 AM UTC (Cron: 0 0 8 * * 1)
        This is defined in CIPPTimers.json with Id: d3cc4n-4553-7r3p-0r7-n0vu5t3k10
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TenantFilter = 'deccanintl.onmicrosoft.com',

        [Parameter(Mandatory = $false)]
        [string[]]$Recipients = @('jon@novustek.net')
    )

    Write-LogMessage -API 'NovusAssetReportTimer' `
        -message "Starting scheduled asset report for $TenantFilter" `
        -sev Info

    try {
        # Call the main report function
        $result = Send-NovusAssetReport -TenantFilter $TenantFilter -Recipients $Recipients -Verbose

        if ($result.success) {
            Write-LogMessage -API 'NovusAssetReportTimer' `
                -message "Asset report completed successfully for $TenantFilter - $($result.deviceCount) devices (correlation: $($result.correlationId))" `
                -sev Info
        } else {
            Write-LogMessage -API 'NovusAssetReportTimer' `
                -message "Asset report failed for ${TenantFilter}: $($result.error)" `
                -sev Error
        }

        return $result

    } catch {
        Write-LogMessage -API 'NovusAssetReportTimer' `
            -message "Asset report timer failed: $_" `
            -sev Error `
            -LogData (Get-CippException -Exception $_)
        throw
    }
}
