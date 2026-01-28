# NOVUS CUSTOM: Enable CafeMoto pilot alerts for AI integration
<#
.SYNOPSIS
    Creates scheduled CIPP alerts for CafeMoto tenant to enable AI-driven security monitoring.

.DESCRIPTION
    This script creates a starter set of CIPP scheduled alerts for CafeMoto as part of the
    Claude-Flow AI integration pilot. Each alert is configured to trigger webhook notifications
    that flow through the AI analysis pipeline.

    Authentication:
    - When run inside CIPP (Azure Functions): Uses internal functions directly
    - When run externally: Uses Az module with existing Azure authentication

    Alerts Created:
    - DefenderStatus (4h) - Overall Defender health check
    - DefenderMalware (4h) - Malware detection alerts
    - MFAAdmins (1d) - Admin MFA compliance
    - SecureScore (1d) - Security posture tracking
    - AdminPassword (30m) - Admin password changes

.PARAMETER TenantDomain
    The tenant's default domain. Default: cafemoto.onmicrosoft.com

.PARAMETER TenantLabel
    Display label for the tenant. Default: CafeMoto

.PARAMETER WhatIf
    Shows what alerts would be created without actually creating them.

.EXAMPLE
    .\Enable-CafeMotoAlerts.ps1
    # Uses existing Azure auth to create alerts

.EXAMPLE
    .\Enable-CafeMotoAlerts.ps1 -WhatIf
    # Shows what alerts would be created without making changes

.NOTES
    Author: Novus Technology Integration
    Date: 2026-01-27
    Purpose: CafeMoto pilot - Claude-Flow AI integration

    Prerequisites:
    - Azure PowerShell logged in (Connect-AzAccount) OR running inside CIPP Azure Functions
    - Global webhook configured in CIPP to forward alerts
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantDomain = "cafemoto.onmicrosoft.com",

    [Parameter(Mandatory = $false)]
    [string]$TenantLabel = "CafeMoto"
)

# Color output helpers
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Define alerts to create
$AlertsToCreate = @(
    @{
        Name       = "DefenderStatus"
        Recurrence = "4h"
        Purpose    = "Overall Defender health check"
    },
    @{
        Name       = "DefenderMalware"
        Recurrence = "4h"
        Purpose    = "Malware detection alerts"
    },
    @{
        Name       = "MFAAdmins"
        Recurrence = "1d"
        Purpose    = "Admin MFA compliance"
    },
    @{
        Name       = "SecureScore"
        Recurrence = "1d"
        Purpose    = "Security posture tracking"
    },
    @{
        Name       = "AdminPassword"
        Recurrence = "30m"
        Purpose    = "Admin password changes"
    }
)

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     CafeMoto Alert Configuration - Claude-Flow AI Pilot        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Info "Target Tenant: $TenantLabel ($TenantDomain)"
Write-Host ""

# Display alerts to be created
Write-Host "Alerts to create:" -ForegroundColor White
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
foreach ($alert in $AlertsToCreate) {
    Write-Host "  • $($alert.Name.PadRight(20)) | $($alert.Recurrence.PadRight(5)) | $($alert.Purpose)" -ForegroundColor White
}
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

# Determine execution context
$insideCIPP = $false
$useDirectAPI = $false

# Check if CIPP modules are available (running inside Azure Functions)
if (Get-Command -Name 'Add-CIPPScheduledTask' -ErrorAction SilentlyContinue) {
    Write-Info "Running inside CIPP context - using internal functions"
    $insideCIPP = $true
} else {
    Write-Info "Running externally - will use Azure Table Storage directly"

    # Check for Az module
    if (-not (Get-Module -ListAvailable -Name 'Az.Storage')) {
        Write-Err "Az.Storage module not found. Install with: Install-Module Az.Storage"
        exit 1
    }

    # Import Az modules
    Import-Module Az.Accounts -ErrorAction SilentlyContinue
    Import-Module Az.Storage -ErrorAction SilentlyContinue

    # Check Azure authentication (not affected by -WhatIf)
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azContext) {
        Write-Warn "Not logged into Azure. Please run 'Connect-AzAccount' first."
        Write-Host ""
        Write-Host "  Connect-AzAccount" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    Write-Info "Azure context: $($azContext.Account.Id) / $($azContext.Subscription.Name)"
    $useDirectAPI = $true
}

Write-Host ""
Write-Info "Creating alerts..."
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($alert in $AlertsToCreate) {
    $alertDisplayName = "$TenantLabel`: $($alert.Name)"

    if ($PSCmdlet.ShouldProcess($alertDisplayName, "Create scheduled alert")) {
        try {
            Write-Host "  Creating: $alertDisplayName..." -ForegroundColor White -NoNewline

            if ($insideCIPP) {
                # Running inside CIPP - use internal function directly
                $task = [PSCustomObject]@{
                    TenantFilter = [PSCustomObject]@{
                        value = $TenantDomain
                        label = $TenantLabel
                    }
                    Name = $alertDisplayName
                    Command = [PSCustomObject]@{
                        value = $alert.Name
                    }
                    Parameters = @{}
                    Recurrence = [PSCustomObject]@{
                        value = $alert.Recurrence
                    }
                    PostExecution = @(
                        [PSCustomObject]@{
                            value = "Webhook"
                            label = "Webhook"
                        }
                    )
                    AlertComment = "CafeMoto pilot - AI integration enabled - $($alert.Purpose)"
                }

                $result = Add-CIPPScheduledTask -Task $task -Hidden $true
                Write-Host " ✓" -ForegroundColor Green
                Write-Host "    $result" -ForegroundColor Gray
                $successCount++
            }
            elseif ($useDirectAPI) {
                # Running externally - write directly to Azure Table Storage
                # Get storage account (CIPP uses cippstgXXXXX naming)
                $storageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -like 'cippstg*' } | Select-Object -First 1

                if (-not $storageAccount) {
                    throw "Could not find CIPP storage account (cippstg*)"
                }

                $ctx = $storageAccount.Context
                $table = Get-AzStorageTable -Name 'ScheduledTasks' -Context $ctx -ErrorAction Stop
                $cloudTable = $table.CloudTable

                # Build entity
                $rowKey = [guid]::NewGuid().ToString()
                $scheduledTime = [int64](([datetime]::UtcNow) - (Get-Date '1/1/1970')).TotalSeconds

                $entity = New-Object Microsoft.Azure.Cosmos.Table.DynamicTableEntity
                $entity.PartitionKey = 'ScheduledTask'
                $entity.RowKey = $rowKey
                $entity.Properties.Add('Tenant', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString($TenantDomain))
                $entity.Properties.Add('Name', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString($alertDisplayName))
                $entity.Properties.Add('Command', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString($alert.Name))
                $entity.Properties.Add('Parameters', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString('{}'))
                $entity.Properties.Add('ScheduledTime', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString($scheduledTime.ToString()))
                $entity.Properties.Add('Recurrence', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString($alert.Recurrence))
                $entity.Properties.Add('PostExecution', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString('Webhook'))
                $entity.Properties.Add('TaskState', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString('Planned'))
                $entity.Properties.Add('Hidden', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForBool($true))
                $entity.Properties.Add('Results', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString('Planned'))
                $entity.Properties.Add('AlertComment', [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString("CafeMoto pilot - AI integration enabled - $($alert.Purpose)"))

                $operation = [Microsoft.Azure.Cosmos.Table.TableOperation]::InsertOrReplace($entity)
                $null = $cloudTable.Execute($operation)

                Write-Host " ✓" -ForegroundColor Green
                Write-Host "    Created with RowKey: $rowKey" -ForegroundColor Gray
                $successCount++
            }

            # Small delay to avoid rate limiting
            Start-Sleep -Milliseconds 300

        } catch {
            Write-Host " ✗" -ForegroundColor Red
            Write-Err "    Failed: $($_.Exception.Message)"
            $failCount++
        }
    } else {
        Write-Host "  [WhatIf] Would create: $alertDisplayName" -ForegroundColor Yellow
        $successCount++
    }
}

Write-Host ""
Write-Host "═════════════════════════════════════════════════════════════════" -ForegroundColor Gray

if ($WhatIfPreference) {
    Write-Info "WhatIf mode - no changes made"
    Write-Info "Run without -WhatIf to create alerts"
} else {
    if ($failCount -eq 0) {
        Write-Success "All $successCount alerts created successfully!"
    } else {
        Write-Warn "Created: $successCount | Failed: $failCount"
    }
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. Verify alerts in CIPP UI:" -ForegroundColor Gray
Write-Host "     https://cipp.novustek.io → Tenant Admin → Alert Configuration" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Monitor Teams #cipp-alerts for notifications" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Check pending actions:" -ForegroundColor Gray
Write-Host "     curl http://20.9.193.65:8082/api/actions/pending" -ForegroundColor Gray
Write-Host ""
