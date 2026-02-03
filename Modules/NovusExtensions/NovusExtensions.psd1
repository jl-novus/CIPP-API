# NOVUS CUSTOM: PowerShell module manifest for Novus custom extensions
# Date: 2026-01-23

@{
    # Script module or binary module file associated with this manifest
    RootModule        = 'NovusExtensions.psm1'

    # Version number of this module
    ModuleVersion     = '1.0.0'

    # ID used to uniquely identify this module
    GUID              = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'

    # Author of this module
    Author            = 'Novus Technology Integration Inc.'

    # Company or vendor of this module
    CompanyName       = 'Novus Technology Integration Inc.'

    # Copyright statement for this module
    Copyright         = '(c) 2026 Novus Technology Integration Inc. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Custom extensions for CIPP - Novus specific integrations including n8n webhooks, SuperOps RMM, and Wazuh SIEM forwarding.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.4'

    # Functions to export from this module
    FunctionsToExport = @(
        # Core webhook functions
        'Send-NovusWebhook'
        'Send-NovusAIWebhook'

        # AI Integration
        'Get-NovusHMACSignature'
        'Get-NovusTenantContext'
        'Get-NovusAlertEnrichment'

        # Reporting
        'Send-NovusAssetReport'
        'Get-NovusDeviceInventory'

        # Timer functions
        'Start-NovusAssetReportTimer'
        'Start-NovusAIAlertOrchestrator'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{
        PSData = @{
            Tags       = @('CIPP', 'Novus', 'Automation', 'n8n', 'Webhooks')
            ProjectUri = 'https://github.com/jl-novus/CIPP-API'
        }
    }
}
