# Deccan Asset Report - n8n Workflow Import Guide

**Created**: 2026-02-03
**Workflow File**: `workflows/deccan-asset-report-v2.json`
**Status**: Ready for Import and Testing

---

## Overview

This guide walks you through importing and configuring the Deccan Asset Report workflow in n8n. The workflow:
1. Runs weekly on Monday at 8:00 AM
2. Pulls Intune device data via Microsoft Graph API
3. Analyzes data with Claude AI for SOC2 compliance insights
4. Sends a formatted HTML email report with CSV attachment

---

## Prerequisites

Before importing, ensure you have:

1. **n8n Instance Access**: `https://n8n-nov-sb1-u65757.vm.elestio.app`
2. **Anthropic API Key**: Already configured from AI alert workflow
3. **SMTP Credentials**: For email delivery
4. **Azure AD Credentials**: Deccan tenant's CIPP SAM app registration

---

## Step 1: Import the Workflow (2 minutes)

1. **Log into n8n**: `https://n8n-nov-sb1-u65757.vm.elestio.app`

2. **Go to Workflows** (left sidebar)

3. **Click the dropdown** (top-right) → **"Import from File"**

4. **Select the file**:
   ```
   C:\Projects\novus-automation\novus-cipp-prd\CIPP-API\Modules\NovusExtensions\workflows\deccan-asset-report-v2.json
   ```

5. **Click "Import"**

✅ **Result**: Workflow "Deccan Asset Report v2" created with 10 nodes

---

## Step 2: Configure Credentials (5 minutes)

### A. Get Azure AD Credentials from Key Vault

Run this PowerShell to retrieve the values:

```powershell
# Get credentials from Azure Key Vault (cippdxfje)
az keyvault secret show --vault-name cippdxfje --name "ApplicationID" --query value -o tsv
az keyvault secret show --vault-name cippdxfje --name "ApplicationSecret" --query value -o tsv

# Note: TenantID for the partner tenant is stored, but we need Deccan's tenant ID
# Get Deccan's tenant ID from CIPP tenant list
```

### B. Update "Set Tenant Config" Node

1. **Click** the "Set Tenant Config" node
2. **Replace placeholders** in the code:

```javascript
return [{
  json: {
    tenantId: 'YOUR_DECCAN_TENANT_ID',     // Deccan's Azure AD tenant ID
    clientId: 'YOUR_CIPP_APP_CLIENT_ID',   // From ApplicationID in Key Vault
    clientSecret: 'YOUR_APP_SECRET'        // From ApplicationSecret in Key Vault
  }
}];
```

> **Note**: Use the CIPP SAM app registration that has delegated access to Deccan's tenant.

### C. Connect Anthropic API Key (Node 7)

1. **Click** "Claude AI Analysis" node
2. **Under "Credentials"**, select your existing **Anthropic API Key** credential
3. **Save**

### D. Configure SMTP (Node 10)

1. **Click** "Send Email" node
2. **Under "Credentials"**, select your SMTP credential
3. **Verify recipient**: `jlucky@novustek.io`
4. **Save**

---

## Step 3: Test the Workflow Manually

### Option A: Run from n8n UI

1. **Click "Execute Workflow"** (top-right play button)
2. **Watch execution** - each node will show success/failure
3. **Check email** for the report

### Option B: Run from PowerShell

Use the test script:

```powershell
cd C:\Projects\novus-automation\novus-cipp-prd\CIPP-API\Modules\NovusExtensions\Scripts
.\Test-DeccanAssetReport.ps1
```

This validates:
- CIPP API connectivity
- Device data retrieval
- Data transformation accuracy
- AI prompt generation

---

## Step 4: Activate Weekly Schedule

1. **Toggle the switch** (top-right) to activate
2. **Verify schedule**: Monday at 8:00 AM

The workflow will now run automatically every week.

---

## Workflow Node Reference

| # | Node Name | Type | Purpose |
|---|-----------|------|---------|
| 1 | Weekly Schedule (Mon 8am) | Schedule Trigger | Cron: Monday 8:00 AM |
| 2 | Set Tenant Config | Code | Azure AD credentials |
| 3 | Get OAuth Token | HTTP Request | Get Graph API bearer token |
| 4 | Get Intune Devices | HTTP Request | Fetch managed devices |
| 5 | Transform Data | Code | Calculate metrics |
| 6 | Build AI Prompt | Code | Create Claude prompt |
| 7 | Claude AI Analysis | HTTP Request | Get AI insights |
| 8 | Parse AI Response | Code | Extract analysis text |
| 9 | Format HTML Report | Code | Build email HTML + CSV |
| 10 | Send Email | Email Send | Deliver report |

---

## Troubleshooting

### Error: "Failed to get OAuth token"

**Cause**: Invalid credentials or tenant ID
**Fix**:
1. Verify tenantId is Deccan's actual Azure AD tenant ID
2. Check clientId/clientSecret are from CIPP SAM app
3. Ensure app has `DeviceManagementManagedDevices.Read.All` permission

### Error: "No devices found"

**Cause**: Intune not configured or no enrolled devices
**Fix**:
1. Verify Deccan has Intune license
2. Check CIPP can see Deccan devices in UI
3. Test the CIPP API endpoint directly

### Error: "Claude API failed"

**Cause**: Invalid API key or rate limit
**Fix**:
1. Verify Anthropic credential is connected
2. Check API key is valid in Key Vault
3. Check usage limits on Anthropic console

### Error: "Email send failed"

**Cause**: SMTP configuration issue
**Fix**:
1. Verify SMTP credential is connected
2. Test SMTP with a simple workflow
3. Check firewall allows outbound SMTP

---

## Expected Results

After successful execution:

1. **Email arrives** at jlucky@novustek.io
2. **Subject**: "Deccan Weekly Asset Report - [Date]"
3. **Content includes**:
   - Summary metrics (5 cards)
   - AI analysis section
   - Device inventory table (first 50)
   - Note if more devices exist
4. **Execution time**: < 2 minutes

---

## Expanding to Other Tenants

To create reports for other clients:

1. **Duplicate the workflow**
2. **Update tenant config** with new tenant credentials
3. **Update AI prompt** for compliance requirements:
   - HIPAA (Arete Health, IGOE Company)
   - SOC2 (Deccan)
   - Standard (CafeMoto, Plenum Plus)
4. **Update email recipient**

---

## Cost Estimate

| Component | Per Report | Monthly (4 reports) | Annual |
|-----------|-----------|---------------------|--------|
| Claude AI | ~$0.05 | ~$0.20 | ~$2.40 |
| Graph API | Free | Free | Free |
| SMTP | Free | Free | Free |

**Total Annual Cost**: ~$2.40

---

## Security Notes

1. **Credentials**: Never commit secrets to Git - use n8n credentials or Key Vault
2. **Data Handling**: Device inventory stays in n8n execution memory
3. **Email Security**: Report contains device names/users - send to authorized recipients only
4. **Audit Trail**: n8n keeps execution history for troubleshooting

---

## Related Files

- **Workflow JSON**: `workflows/deccan-asset-report-v2.json`
- **PowerShell Function**: `Public/Reporting/Get-NovusDeviceInventory.ps1`
- **Test Script**: `Scripts/Test-DeccanAssetReport.ps1`
- **Design Document**: `docs/DECCAN-ASSET-REPORT-DESIGN.md`

---

**Questions?** Contact JLucky (CIO/CTO, Novus Technology Integration)

**Last Updated**: 2026-02-03
