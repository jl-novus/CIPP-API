# Novus Extensions Module

All Novus-specific PowerShell functions go here.

## Purpose
This module contains custom PowerShell functions and extensions specific to Novus Technology Integration Inc.

## Structure
- **Public/** - Exported functions (available to other modules)
- **Private/** - Internal helper functions (not exported)
- **Scripts/** - Standalone utility scripts (not part of module)

## Coding Guidelines
- Use approved PowerShell verbs (Get-, Set-, New-, Remove-, etc.)
- Include comment-based help for all public functions
- Tag all custom code with '# NOVUS CUSTOM:' comments
- Always use try/catch for error handling
- Never hardcode credentials - use environment variables or Azure Key Vault

## Planned Integrations
- n8n webhook functions
- SuperOps RMM integration
- Wazuh SIEM forwarding
- HIPAA/SOC2 compliance functions

## Scripts

### Enable-CafeMotoAlerts.ps1
Creates scheduled CIPP alerts for CafeMoto tenant (AI integration pilot).

**Usage:**
```powershell
# First, login to Azure (if not already)
Connect-AzAccount

# Preview what would be created
.\Scripts\Enable-CafeMotoAlerts.ps1 -WhatIf

# Create alerts
.\Scripts\Enable-CafeMotoAlerts.ps1
```

**Alerts Created:**
| Alert | Recurrence | Purpose |
|-------|------------|---------|
| DefenderStatus | 4h | Overall Defender health check |
| DefenderMalware | 4h | Malware detection alerts |
| MFAAdmins | 1d | Admin MFA compliance |
| SecureScore | 1d | Security posture tracking |
| AdminPassword | 30m | Admin password changes |

**Authentication:** Uses existing Azure login via Az PowerShell module (Connect-AzAccount). Writes directly to CIPP's Azure Table Storage.

## Merge Protection
This directory is configured in .gitattributes to use 'ours' merge strategy during upstream syncs.

