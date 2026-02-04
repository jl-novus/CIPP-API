# Novus Extensions - Secrets Reference

## Overview
This document provides a quick reference for all secrets and API keys used by NovusExtensions.
**Last Updated:** 2026-02-03

---

## Azure Key Vaults

### Primary Key Vault: `cippdxfje`
**Location:** Azure Portal > Key Vaults > cippdxfje
**Resource Group:** nov-cipp-rg
**Region:** westus2

This is the main Key Vault for CIPP-related secrets and integrations.

| Secret Name | Purpose | Notes |
|-------------|---------|-------|
| `N8N-API-Key` | n8n REST API authentication | Used for workflow imports/updates |
| `N8N-AssetReport-Webhook-URL` | Asset report webhook endpoint | Triggers Deccan asset report workflow |
| `N8N-Webhook-Secret` | HMAC signature validation | Validates webhook authenticity |
| `N8N-Webhook-URL` | General n8n webhook endpoint | For CIPP alert forwarding |

### Secondary Key Vault: `novus-prod-wus2-kv-aiops`
**Location:** Azure Portal > Key Vaults > novus-prod-wus2-kv-aiops

This Key Vault is for AI operations and M365 app credentials.

| Secret Name | Purpose | Notes |
|-------------|---------|-------|
| `anthropic-api-key` | Claude API for AI analysis | Used by n8n AI workflows |
| `m365-app-client-id` | M365 App Registration | Service principal client ID |
| `m365-app-client-secret` | M365 App Registration | Service principal secret |
| `m365-tenant-id` | Novus M365 Tenant | Azure AD tenant identifier |

---

## External Services

### n8n (Workflow Automation)
- **URL:** `https://n8n-nov-sb1-u65757.vm.elestio.app`
- **Hosted On:** Elestio
- **API Key Location:** `cippdxfje` Key Vault → `N8N-API-Key`

#### Active Workflows
| Workflow ID | Name | Purpose |
|-------------|------|---------|
| `7qhfWgDV9OeuaszK` | CIPP Asset Report with AI Analysis | Weekly Deccan device compliance report |

### Claude-Flow (AI Orchestration)
- **VM:** vm-claude-flow-gpu (100.84.132.24)
- **Gateway Token Location:** `C:\Projects\claude-flow-msp-deployment\config\secrets\.env.production`
- **Secrets:**
  - `NOVUSFLOW_GATEWAY_TOKEN` - Gateway authentication
  - `ANTHROPIC_API_KEY` - Direct Claude API access

---

## Quick Access Commands

### List all secrets in cippdxfje Key Vault
```powershell
az keyvault secret list --vault-name cippdxfje --query "[].name" -o tsv
```

### Get a specific secret value
```powershell
az keyvault secret show --vault-name cippdxfje --name "N8N-API-Key" --query "value" -o tsv
```

### List all Key Vaults in CIPP resource group
```powershell
az keyvault list --resource-group nov-cipp-rg -o table
```

---

## Notes

1. **Never commit secrets to git** - Always use Key Vault references
2. **cippdxfje is the primary vault** for all CIPP and n8n integrations
3. **aiops vault** is specifically for AI/ML operations and M365 app credentials
4. When adding new secrets, document them here immediately
