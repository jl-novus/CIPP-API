# NOVUS CUSTOM: Device inventory wrapper for asset management reporting

function Get-NovusDeviceInventory {
    <#
    .SYNOPSIS
        Retrieves Intune device inventory with compliance summary for asset reporting.

    .DESCRIPTION
        Wraps the CIPP/Graph API device listing endpoint and adds:
        - Compliance status calculations (compliant %, encrypted %, stale devices)
        - Filtered results by tenant
        - Summary metrics for AI analysis
        - SOC2-relevant metrics extraction

    .PARAMETER TenantFilter
        The tenant's default domain name (e.g., 'deccanintl.onmicrosoft.com').

    .PARAMETER StaleDays
        Number of days without sync to consider a device stale. Default: 7

    .PARAMETER IncludeRaw
        If specified, includes the raw device data array in the output.

    .EXAMPLE
        $inventory = Get-NovusDeviceInventory -TenantFilter 'deccanintl.onmicrosoft.com'
        # Returns summary metrics and device list

    .EXAMPLE
        $inventory = Get-NovusDeviceInventory -TenantFilter 'deccanintl.onmicrosoft.com' -StaleDays 14
        # Returns with 14-day stale threshold

    .NOTES
        Used by n8n "Deccan Asset Report" workflow for automated weekly reporting.

        SOC2 Compliance Metrics:
        - Encryption coverage (BitLocker/FileVault)
        - Device compliance state
        - Stale device tracking (last sync age)
        - Operating system version distribution

        Client: Deccan International (SOC2)
        Author: Claude Opus 4.5 with JLucky
        Date: 2026-02-03
    #>

    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantFilter,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 90)]
        [int]$StaleDays = 7,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeRaw
    )

    begin {
        Write-Verbose "Get-NovusDeviceInventory: Starting for tenant $TenantFilter (stale threshold: $StaleDays days)"
        $now = Get-Date
    }

    process {
        try {
            # 1. Fetch device inventory from Graph API via CIPP
            Write-Verbose "Fetching Intune managed devices from Graph API..."

            $devices = New-GraphGetRequest `
                -uri 'https://graph.microsoft.com/beta/deviceManagement/managedDevices' `
                -Tenantid $TenantFilter

            if (-not $devices -or $devices.Count -eq 0) {
                Write-Warning "No devices found for tenant $TenantFilter"
                return @{
                    success       = $false
                    tenantFilter  = $TenantFilter
                    error         = 'No devices found'
                    timestamp     = $now.ToUniversalTime().ToString('o')
                }
            }

            Write-Verbose "Found $($devices.Count) devices"

            # 2. Calculate compliance metrics
            $totalDevices = $devices.Count
            $compliantDevices = @($devices | Where-Object { $_.complianceState -eq 'compliant' })
            $nonCompliantDevices = @($devices | Where-Object { $_.complianceState -eq 'noncompliant' })
            $encryptedDevices = @($devices | Where-Object { $_.isEncrypted -eq $true })

            # Calculate stale devices (no sync in X days)
            $staleThreshold = $now.AddDays(-$StaleDays)
            $staleDevices = @($devices | Where-Object {
                $lastSync = [datetime]::Parse($_.lastSyncDateTime)
                $lastSync -lt $staleThreshold
            })

            # OS distribution
            $osCounts = $devices | Group-Object -Property operatingSystem |
                Select-Object @{N='OS';E={$_.Name}}, @{N='Count';E={$_.Count}}

            # Build summary metrics
            $summary = @{
                totalDevices     = $totalDevices
                compliant        = @{
                    count   = $compliantDevices.Count
                    percent = [math]::Round(($compliantDevices.Count / $totalDevices) * 100, 1)
                }
                nonCompliant     = @{
                    count   = $nonCompliantDevices.Count
                    percent = [math]::Round(($nonCompliantDevices.Count / $totalDevices) * 100, 1)
                }
                encrypted        = @{
                    count   = $encryptedDevices.Count
                    percent = [math]::Round(($encryptedDevices.Count / $totalDevices) * 100, 1)
                }
                stale            = @{
                    count     = $staleDevices.Count
                    threshold = $StaleDays
                    devices   = $staleDevices | Select-Object deviceName, userPrincipalName, lastSyncDateTime
                }
                osDistribution   = $osCounts
            }

            # 3. Build device list for report (sorted by compliance status)
            $deviceList = $devices | Sort-Object complianceState, deviceName | ForEach-Object {
                @{
                    deviceName         = $_.deviceName
                    serialNumber       = $_.serialNumber
                    model              = $_.model
                    manufacturer       = $_.manufacturer
                    operatingSystem    = $_.operatingSystem
                    osVersion          = $_.osVersion
                    complianceState    = $_.complianceState
                    isEncrypted        = $_.isEncrypted
                    lastSyncDateTime   = $_.lastSyncDateTime
                    userPrincipalName  = $_.userPrincipalName
                    managementAgent    = $_.managementAgent
                    enrolledDateTime   = $_.enrolledDateTime
                }
            }

            # 4. Build result object
            $result = @{
                success      = $true
                tenantFilter = $TenantFilter
                timestamp    = $now.ToUniversalTime().ToString('o')
                staleDays    = $StaleDays
                summary      = $summary
                devices      = $deviceList
            }

            # Include raw data if requested
            if ($IncludeRaw) {
                $result.rawDevices = $devices
            }

            Write-Verbose "Device inventory complete: $totalDevices devices, $($compliantDevices.Count) compliant, $($staleDevices.Count) stale"
            Write-LogMessage -API 'NovusDeviceInventory' -message "Retrieved $totalDevices devices for $TenantFilter" -sev Info

            return $result

        } catch {
            Write-Error "Failed to get device inventory for $TenantFilter : $_"
            Write-LogMessage -API 'NovusDeviceInventory' -message "Error: $_" -sev Error -LogData (Get-CippException -Exception $_)

            return @{
                success      = $false
                tenantFilter = $TenantFilter
                error        = $_.Exception.Message
                timestamp    = $now.ToUniversalTime().ToString('o')
            }
        }
    }
}
