# Azure Key Vault Configuration for n8n AI Integration

## Overview

The n8n AI integration requires storing sensitive credentials in Azure Key Vault to maintain security and avoid hardcoding secrets in code. This document provides step-by-step instructions for configuring the required secrets.

## Required Secrets

| Secret Name | Purpose | Where to Get It |
|-------------|---------|-----------------|
| `N8N-Webhook-URL` | n8n webhook receiver endpoint | n8n workflow webhook URL (see below) |
| `N8N-Webhook-Secret` | Shared secret for HMAC authentication | Generate new GUID (see below) |
| `Anthropic-API-Key` | Claude API access key | Anthropic Console (console.anthropic.com) |

---

## Prerequisites

- Azure CLI installed ([Install Guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli))
- Access to CIPP Azure subscription with Key Vault permissions
- n8n instance deployed on Elestio

---

## Step 1: Identify Your CIPP Key Vault

Your CIPP Key Vault name is likely derived from your deployment ID. Find it using:

```powershell
# Option 1: Check environment variable (if set)
$env:WEBSITE_DEPLOYMENT_ID

# Option 2: List all Key Vaults in subscription
az keyvault list --query "[].name" -o table

# Option 3: Check CIPP Function App configuration
# The Key Vault name is typically: "cipp<deployment-id>"
# Example: cippdxfje
```

**Your CIPP Key Vault**: `cippdxfje` (based on your Function App name)

---

## Step 2: Set Up n8n Webhook URL

### 2.1 Create n8n Workflow (if not already created)

1. Log in to your n8n instance on Elestio
2. Create a new workflow: "CIPP Security Alert AI Analysis"
3. Add a **Webhook node** with these settings:
   - **HTTP Method**: POST
   - **Path**: `/cipp-security-alert`
   - **Response Mode**: "When Last Node Finishes"
   - **Response Data**: "Last Node"

4. **Copy the Production Webhook URL**
   - Example: `https://your-n8n-instance.elestio.app/webhook/cipp-security-alert`
   - **Save this URL** - you'll add it to Key Vault in Step 4

### 2.2 Note the Webhook URL Format

```
https://<your-n8n-domain>/webhook/cipp-security-alert
```

---

## Step 3: Generate Webhook Secret

The webhook secret is a shared key used for HMAC-SHA256 signature validation. Generate a strong random secret:

```powershell
# PowerShell (Recommended)
$webhookSecret = [guid]::NewGuid().ToString()
Write-Host "Generated Webhook Secret: $webhookSecret"

# Alternative: OpenSSL
openssl rand -base64 32
```

**Important**: Save this secret securely - you'll need it for both:
1. Azure Key Vault (CIPP side)
2. n8n environment variable (n8n side)

---

## Step 4: Add Secrets to Azure Key Vault

### Option A: Using Azure CLI (Recommended)

```powershell
# Set variables
$keyVaultName = "cippdxfje"  # Your CIPP Key Vault name
$n8nWebhookUrl = "https://your-n8n-instance.elestio.app/webhook/cipp-security-alert"
$webhookSecret = "<YOUR-GENERATED-SECRET-FROM-STEP-3>"
$anthropicApiKey = "sk-ant-api03-..."  # From Anthropic Console

# Add secrets to Key Vault
az keyvault secret set --vault-name $keyVaultName --name "N8N-Webhook-URL" --value $n8nWebhookUrl
az keyvault secret set --vault-name $keyVaultName --name "N8N-Webhook-Secret" --value $webhookSecret
az keyvault secret set --vault-name $keyVaultName --name "Anthropic-API-Key" --value $anthropicApiKey

# Verify secrets were added
az keyvault secret list --vault-name $keyVaultName --query "[?starts_with(name, 'N8N') || starts_with(name, 'Anthropic')].name" -o table
```

### Option B: Using Azure Portal

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Search for your Key Vault: `cippdxfje`
3. Go to **Settings** → **Secrets**
4. Click **+ Generate/Import** for each secret:

**Secret 1: N8N-Webhook-URL**
- Name: `N8N-Webhook-URL`
- Value: `https://your-n8n-instance.elestio.app/webhook/cipp-security-alert`
- Click **Create**

**Secret 2: N8N-Webhook-Secret**
- Name: `N8N-Webhook-Secret`
- Value: `<your-generated-secret-from-step-3>`
- Click **Create**

**Secret 3: Anthropic-API-Key**
- Name: `Anthropic-API-Key`
- Value: `sk-ant-api03-...` (from Anthropic Console)
- Click **Create**

---

## Step 5: Configure n8n Environment Variables

n8n needs the webhook secret to validate incoming requests from CIPP.

### 5.1 Access Elestio Dashboard

1. Log in to your Elestio account
2. Navigate to your n8n instance
3. Go to **Settings** → **Environment Variables** (or **Software Config**)

### 5.2 Add Environment Variables

Add the following environment variables:

| Variable Name | Value | Description |
|---------------|-------|-------------|
| `CIPP_WEBHOOK_SECRET` | `<same-secret-as-key-vault>` | Shared secret for HMAC validation |
| `ANTHROPIC_API_KEY` | `sk-ant-api03-...` | Claude API key |
| `CIPP_API_URL` | `https://cippdxfje.azurewebsites.net` | CIPP backend URL for callbacks |
| `CIPP_API_KEY` | `<cipp-api-key>` | CIPP API key for n8n → CIPP callbacks (optional for Phase 1) |

### 5.3 Restart n8n

After adding environment variables, restart your n8n instance to apply changes.

---

## Step 6: Verify Configuration

### 6.1 Verify Key Vault Secrets

```powershell
# Check if secrets exist
az keyvault secret show --vault-name cippdxfje --name "N8N-Webhook-URL" --query "value" -o tsv
az keyvault secret show --vault-name cippdxfje --name "N8N-Webhook-Secret" --query "value" -o tsv
az keyvault secret show --vault-name cippdxfje --name "Anthropic-API-Key" --query "value" -o tsv
```

**Expected Output**: Should return the values you set (webhook URL, secret, API key)

### 6.2 Verify CIPP Can Access Secrets

Test from PowerShell using CIPP's function:

```powershell
# This will be tested after deploying the code
# For now, verify Key Vault access permissions are correct
```

### 6.3 Test Webhook Connectivity

```powershell
# Test that n8n webhook is accessible
$testPayload = @{
    test = $true
    timestamp = (Get-Date).ToString('o')
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://your-n8n-instance.elestio.app/webhook/cipp-security-alert" `
    -Method Post `
    -Body $testPayload `
    -ContentType "application/json"
```

**Expected**: n8n should receive the test payload (check n8n execution history)

---

## Step 7: Get Anthropic API Key

If you don't have an Anthropic API key yet:

1. Go to [Anthropic Console](https://console.anthropic.com)
2. Sign up or log in
3. Navigate to **API Keys**
4. Click **Create Key**
5. Name it: "CIPP-n8n-AI-Integration"
6. Copy the key (starts with `sk-ant-api03-`)
7. **Save securely** - you cannot view it again
8. Add to Key Vault (see Step 4)

### API Key Tier Verification

Check your API tier and rate limits:

| Tier | Rate Limit | Monthly Spend | Best For |
|------|------------|---------------|----------|
| Free | 5 req/min | $0 | Testing only |
| Build Tier 1 | 50 req/min | $100/month | Production (100 alerts/day) |
| Build Tier 2 | 1000 req/min | $500/month | High-volume production |

**For Novus (5 clients, ~100 alerts/day)**: Build Tier 1 is sufficient (~$87/month usage)

---

## Security Best Practices

### Secret Rotation

Rotate secrets every 90 days:

1. Generate new webhook secret
2. Update in Key Vault AND n8n environment variables
3. Restart n8n and CIPP Function App

### Access Control

Verify Key Vault access policies:

```powershell
# List Key Vault access policies
az keyvault show --name cippdxfje --query "properties.accessPolicies" -o table
```

**CIPP Function App should have**:
- Secret: Get, List

**Your Admin Account should have**:
- Secret: Get, List, Set, Delete

### Monitoring

Enable Key Vault logging:

```powershell
# Enable diagnostic settings (sends to Log Analytics)
az monitor diagnostic-settings create \
    --resource /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/cippdxfje \
    --name "KeyVault-Diagnostics" \
    --logs '[{"category": "AuditEvent", "enabled": true}]' \
    --workspace <log-analytics-workspace-id>
```

---

## Troubleshooting

### Issue: "N8N webhook URL not configured in Key Vault"

**Cause**: Secret not found or incorrect name

**Solution**:
```powershell
# Verify secret exists and name is exact (case-sensitive)
az keyvault secret list --vault-name cippdxfje --query "[].name" -o table

# Correct name must be: N8N-Webhook-URL (with hyphens, exact capitalization)
```

### Issue: "Failed to retrieve webhook configuration from Key Vault"

**Cause**: CIPP Function App doesn't have Key Vault access permissions

**Solution**:
```powershell
# Grant CIPP Function App access to Key Vault
az keyvault set-policy --name cippdxfje \
    --object-id <function-app-managed-identity-object-id> \
    --secret-permissions get list
```

To find Function App Managed Identity Object ID:
```powershell
az functionapp identity show --name cippdxfje --resource-group <your-rg> --query principalId -o tsv
```

### Issue: n8n webhook returns 401 Unauthorized

**Cause**: HMAC signature mismatch

**Check**:
1. Webhook secret matches between Key Vault and n8n environment variable
2. n8n workflow has HMAC validation function node
3. Timestamp in X-CIPP-Timestamp header is recent (<5 minutes)

---

## Next Steps

After Key Vault configuration:

1. ✅ Deploy custom functions to CIPP-API
2. ✅ Build n8n workflow with HMAC validation
3. ✅ Test end-to-end webhook delivery
4. ✅ Proceed to Week 2 tasks (alert orchestrator implementation)

---

## Reference Commands

```powershell
# Quick setup script (PowerShell)
$keyVaultName = "cippdxfje"
$webhookSecret = [guid]::NewGuid().ToString()

Write-Host "Generated Webhook Secret: $webhookSecret" -ForegroundColor Green
Write-Host "Add this to both Azure Key Vault AND n8n environment variables" -ForegroundColor Yellow

# Prompt for values
$n8nUrl = Read-Host "Enter your n8n webhook URL"
$anthropicKey = Read-Host "Enter your Anthropic API key"

# Add to Key Vault
az keyvault secret set --vault-name $keyVaultName --name "N8N-Webhook-URL" --value $n8nUrl
az keyvault secret set --vault-name $keyVaultName --name "N8N-Webhook-Secret" --value $webhookSecret
az keyvault secret set --vault-name $keyVaultName --name "Anthropic-API-Key" --value $anthropicKey

Write-Host "✓ Secrets added to Key Vault" -ForegroundColor Green
Write-Host "Remember to add CIPP_WEBHOOK_SECRET=$webhookSecret to n8n environment variables" -ForegroundColor Yellow
```