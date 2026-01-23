# NOVUS CUSTOM: Get tenant context for AI analysis

function Get-NovusTenantContext {
    <#
    .SYNOPSIS
        Retrieves tenant context including compliance requirements and risk profile for AI analysis.

    .DESCRIPTION
        Maps Novus MSP client tenants to their compliance requirements (HIPAA, SOC2) and risk
        profiles. This context is crucial for Claude AI to make compliance-aware security
        recommendations and determine appropriate remediation confidence thresholds.

    .PARAMETER TenantFilter
        The tenant's default domain name (e.g., 'aretehealth.onmicrosoft.com').

    .EXAMPLE
        $context = Get-NovusTenantContext -TenantFilter 'aretehealth.onmicrosoft.com'
        # Returns: @{ name = 'Arete Health'; complianceRequirements = @('HIPAA', 'HITECH'); riskProfile = 'high' }

    .NOTES
        Client Compliance Requirements (as of 2026-01-22):
        - Arete Health: HIPAA, HITECH (Healthcare, includes Brunswick Therapy)
        - Deccan International: SOC2 (Public safety software)
        - IGOE Company: HIPAA (Legacy AD, heavy server infrastructure)
        - CafeMoto: None (Retail/food service, coffee roaster)
        - Plenum Plus: None (Sheet metal fabrication)

        Risk Profile Determination:
        - High: HIPAA or SOC2 compliance required
        - Medium: No formal compliance, production environment
        - Low: Development/test environments only

        TODO: Move compliance mapping to database table for easier updates without code changes
    #>

    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantFilter
    )

    begin {
        Write-Verbose "Getting tenant context for: $TenantFilter"
    }

    process {
        try {
            # Retrieve tenant information from CIPP
            $tenant = Get-Tenants | Where-Object { $_.defaultDomainName -eq $TenantFilter }

            if (!$tenant) {
                throw "Tenant not found: $TenantFilter"
            }

            # Compliance requirements mapping (Novus Technology Integration clients)
            # TODO: Move this to a database table (NovusTenantConfig) for easier management
            $complianceMap = @{
                # HIPAA Clients
                'aretehealth.onmicrosoft.com'    = @{
                    Compliance = @('HIPAA', 'HITECH')
                    Notes      = 'Healthcare provider - includes Brunswick Therapy'
                }
                'igoecompany.onmicrosoft.com'    = @{
                    Compliance = @('HIPAA')
                    Notes      = 'Legacy AD environment, heavy server infrastructure'
                }

                # SOC2 Clients
                'deccanintl.onmicrosoft.com'     = @{
                    Compliance = @('SOC2')
                    Notes      = 'Public safety software vendor'
                }

                # Standard Clients (no formal compliance)
                'cafemoto.onmicrosoft.com'       = @{
                    Compliance = @()
                    Notes      = 'Retail/food service - Coffee roaster'
                }
                'plenumplus.onmicrosoft.com'     = @{
                    Compliance = @()
                    Notes      = 'Sheet metal fabrication and distribution'
                }
            }

            # Get compliance config for this tenant
            $config = $complianceMap[$TenantFilter]
            if (!$config) {
                Write-Warning "No compliance configuration found for $TenantFilter - using defaults"
                $config = @{
                    Compliance = @()
                    Notes      = 'Unknown tenant - using default configuration'
                }
            }

            # Determine risk profile based on compliance requirements
            $riskProfile = if ($config.Compliance -contains 'HIPAA') {
                'high'
            } elseif ($config.Compliance -contains 'SOC2') {
                'high'
            } else {
                'medium'
            }

            # Build context object for AI analysis
            $context = @{
                id                     = $tenant.customerId
                name                   = $tenant.displayName
                defaultDomain          = $tenant.defaultDomainName
                complianceRequirements = $config.Compliance
                riskProfile            = $riskProfile
                criticality            = 'production'  # All Novus clients are production
                notes                  = $config.Notes
            }

            Write-Verbose "Tenant context retrieved: $($context.name) - Risk: $riskProfile - Compliance: $($config.Compliance -join ', ')"

            return $context

        } catch {
            Write-Error "Failed to get tenant context for $TenantFilter : $_"
            throw
        }
    }
}