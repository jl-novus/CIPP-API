# Deccan Asset Report - n8n Workflow Setup Guide

**Date:** 2026-02-03
**Author:** Claude Opus 4.5 with JLucky
**Status:** IMPLEMENTATION GUIDE

---

## Quick Start

### Prerequisites Checklist

- [ ] n8n instance running (Elestio: `n8n-nov-sb1-u65757.vm.elestio.app`)
- [ ] CIPP SAM credentials (from Azure Key Vault)
- [ ] Deccan tenant ID (from CIPP tenant list)
- [ ] Anthropic API key (already in n8n credentials)
- [ ] SMTP or Microsoft 365 email sending configured
- [ ] ~15 minutes to complete setup

### Required Credentials (from Azure Key Vault `cippdxfje`)

| Secret Name | Purpose | Value |
|-------------|---------|-------|
| `applicationid` | CIPP SAM App ID | `31387374-81b3-44d8-a6bc-eacb8d38d895` |
| `applicationsecret` | CIPP SAM App Secret | (retrieve from Key Vault) |
| `tenantid` | Partner Tenant ID | `d1d6f631-0609-4f89-b104-2cf64f0c95c5` |

**Note:** You also need Deccan's customer tenant ID, which can be found in CIPP under Tenant Administration → List Tenants.

---

## Available Workflows

### deccan-asset-report-v2.json (Recommended)

Uses Microsoft Graph API directly with OAuth2 authentication. More reliable for automated reporting.

**Flow:**
1. Schedule Trigger (Mon 8am)
2. Set Tenant Config (configure with Deccan credentials)
3. Get OAuth Token from Azure AD
4. Get Intune Devices via Graph API
5. Transform Data (calculate metrics)
6. Build AI Prompt → Claude Analysis
7. Format HTML Report → Send Email

### deccan-asset-report.json (Original)

Uses CIPP API endpoint. Requires CIPP API key configuration.

---

## Import Workflow

### Step 1: Import JSON

1. **Log into n8n**: `https://n8n-nov-sb1-u65757.vm.elestio.app`

2. **Import Workflow**:
   - Click **"Workflows"** in the left sidebar
   - Click **"+"** to create new workflow, or use three dots menu → **"Import from file"**
   - Select: `workflows/deccan-asset-report-v2.json`
   - Click **"Import"**

### Step 2: Configure Tenant Credentials

1. **Open the "Set Tenant Config" node**
2. **Replace placeholders** with actual values:

```javascript
// Replace these values:
tenantId: 'DECCAN_TENANT_ID',        // Get from CIPP tenant list
clientId: '31387374-81b3-44d8-a6bc-eacb8d38d895',  // CIPP SAM App ID
clientSecret: 'YOUR_APP_SECRET'       // From Key Vault: applicationsecret
```

### Step 3: Configure Anthropic API Key

Already configured from AI alert workflow. Verify it's selected in the "Claude AI Analysis" node.

### Step 4: Configure Email Credentials

**Option A: Microsoft 365 OAuth (Recommended)**
1. Go to Credentials → Add Credential → Microsoft OAuth2 API
2. Configure with your Azure AD app registration
3. Select in the Send Email node

**Option B: SMTP**
1. Go to Credentials → Add Credential → SMTP
2. Configure:
   - **Host**: `smtp.office365.com`
   - **Port**: 587
   - **TLS**: true
   - **User**: Your sending email
   - **Password**: App password

---

## Workflow Nodes Detail

### Node 1: Weekly Schedule (Mon 8am)

**Type**: Schedule Trigger

**Settings**:
- **Trigger Interval**: Weeks
- **Day of Week**: Monday (1)
- **Hour**: 8
- **Minute**: 0

**Manual Trigger**:
- Click **"Execute"** button to test without waiting for schedule

### Node 2: Set Tenant Config

**Type**: Code (JavaScript)

**Purpose**: Configures credentials for Deccan tenant

**Configuration Required**: Update with actual tenant credentials

### Node 3: Get OAuth Token

**Type**: HTTP Request

**Settings**:
- **Method**: POST
- **URL**: Azure AD token endpoint
- **Body**: Client credentials grant flow

### Node 4: Get Intune Devices

**Type**: HTTP Request

**Settings**:
- **Method**: GET
- **URL**: `https://graph.microsoft.com/beta/deviceManagement/managedDevices`
- **Authorization**: Bearer token from previous node
- **Timeout**: 60000ms

### Node 5: Transform Data

**Type**: Code (JavaScript)

**Purpose**: Calculates compliance metrics from raw device data

**Key Metrics Calculated**:
- Total device count
- Compliant vs non-compliant devices
- Encryption status
- Stale devices (>7 days no sync)
- OS distribution

### Node 6: Build AI Prompt

**Type**: Code (JavaScript)

**Purpose**: Constructs the Claude API prompt with device summary

**Prompt Structure**:
- SOC2 analyst persona
- Device inventory summary
- OS distribution
- Stale device list
- Non-compliant device list

### Node 7: Claude AI Analysis

**Type**: HTTP Request

**Settings**:
- **Method**: POST
- **URL**: `https://api.anthropic.com/v1/messages`
- **Model**: `claude-sonnet-4-5-20250929`
- **Max Tokens**: 2048
- **Temperature**: 0.3 (focused, consistent output)

### Node 8: Parse AI Response

**Type**: Code (JavaScript)

**Purpose**: Extracts the AI analysis text from Claude's response format

### Node 9: Format HTML Report

**Type**: Code (JavaScript)

**Purpose**: Builds a professional HTML email with:
- Summary metrics dashboard
- AI analysis section
- Device inventory table
- CSV data for attachment

### Node 10: Send Email

**Type**: Email Send

**Settings**:
- **To**: `jlucky@novustek.io` (initial recipient)
- **Subject**: Dynamic with date
- **Format**: HTML
- **Attachments**: CSV file with full device inventory

---

## Testing Procedure

### Test 1: Manual Execution

1. **Disable the schedule trigger temporarily** (click the toggle)
2. **Click "Execute Workflow"** in the top toolbar
3. **Watch execution progress** through each node
4. **Check for errors** (red nodes indicate failures)

### Test 2: Verify Each Node

1. **Set Tenant Config**: Should output tenant credentials
2. **Get OAuth Token**: Should return `access_token`
3. **Get Intune Devices**: Should return `value` array with devices
4. **Transform Data**: Should show summary metrics
5. **Build AI Prompt**: Should have formatted prompt text
6. **Claude AI Analysis**: Should return JSON with analysis
7. **Format HTML Report**: Should have HTML and CSV in output
8. **Send Email**: Should deliver successfully

### Test 3: Email Verification

1. Check the recipient inbox (`jlucky@novustek.io`)
2. Verify:
   - Subject line includes current date
   - Metrics dashboard renders correctly
   - AI analysis is coherent and actionable
   - CSV attachment is present and opens correctly
   - All device data is accurate

---

## Troubleshooting

### Issue: OAuth Token Request Fails (401)

**Cause**: Invalid client credentials

**Fix**:
1. Verify `applicationid` in Key Vault matches workflow
2. Regenerate `applicationsecret` if expired
3. Ensure Deccan tenant ID is correct (not partner tenant)

### Issue: Graph API Returns 403

**Cause**: Missing permissions for Intune/Device Management

**Fix**:
1. Check CIPP SAM app has `DeviceManagementManagedDevices.Read.All` permission
2. Verify consent is granted in Deccan tenant
3. Check CIPP → Tenant Administration → Relationship Status

### Issue: Claude API Returns 400

**Cause**: Malformed JSON body

**Fix**:
1. Check the Build AI Prompt node output
2. Ensure special characters are escaped
3. Verify JSON structure in request body

### Issue: No Devices Returned

**Cause**: Wrong tenant or no Intune enrollment

**Fix**:
1. Verify Deccan tenant has Intune configured
2. Check CIPP can access tenant devices
3. Test directly in Azure Portal → Intune

### Issue: Email Not Sending

**Cause**: SMTP misconfiguration

**Fix**:
1. Test SMTP credentials independently
2. For Microsoft 365, ensure modern auth is enabled
3. Check firewall allows outbound SMTP (port 587)

### Issue: Workflow Times Out

**Cause**: Large device count or slow API

**Fix**:
1. Increase timeout on HTTP Request nodes (60000ms → 120000ms)
2. Add pagination for large device inventories
3. Check Azure Function App performance

---

## Production Checklist

Before enabling the weekly schedule:

- [ ] Test execution completed successfully
- [ ] Email delivered and renders correctly
- [ ] AI analysis provides useful insights
- [ ] CSV attachment is accurate
- [ ] Execution time < 2 minutes
- [ ] Recipient list finalized

### Enable Production Schedule

1. **Click the Schedule Trigger node**
2. **Toggle it ON** (should turn blue/green)
3. **Save workflow** (Ctrl+S)
4. **Confirm activation** in workflow list

---

## Expanding to Other Tenants

This workflow can be templated for other clients:

### CafeMoto (No compliance)
```
TenantId: (CafeMoto's tenant ID)
AI Prompt: Remove SOC2-specific language, focus on general IT health
Email: Update recipient list
```

### Arete Health (HIPAA)
```
TenantId: (Arete's tenant ID)
AI Prompt: Add HIPAA compliance focus, PHI device protection
Email: Update recipient list
```

### Creating Multi-Tenant Report

1. Clone workflow for each tenant, OR
2. Modify to loop through tenant list with Merge node

---

## Monitoring & Alerting

### n8n Execution History

- Click **"Executions"** in left sidebar
- Filter by workflow name
- Review failed executions weekly

### Success Metrics

| Metric | Target |
|--------|--------|
| Weekly execution success | 100% |
| Email delivery rate | 100% |
| Report generation time | < 2 min |
| AI analysis quality | Actionable insights |

### Alert on Failure

1. Add error handling node after Send Email
2. Configure notification on workflow failure
3. Consider Teams/Slack alert for critical failures

---

## Security Considerations

### Credential Storage

- Store client secrets in n8n credentials (encrypted)
- Never hardcode secrets in workflow nodes
- Rotate secrets annually or on compromise

### Data Handling

- Device data is processed in memory only
- No persistent storage of device inventory
- Email contains device names/users (consider data classification)

### Access Control

- Limit n8n access to authorized administrators
- Use RBAC for workflow editing
- Audit workflow changes

---

## Changelog

| Date | Version | Change |
|------|---------|--------|
| 2026-02-03 | 1.0 | Initial implementation |
| 2026-02-03 | 2.0 | Added direct Graph API workflow (v2) |

---

## Support

**Technical Issues**: Check n8n execution logs and Azure AD app permissions

**Feature Requests**: Add to PROJECT_STATUS.md under Future Enhancements

**Questions**: Contact JLucky (CIO/CTO, Novus Technology Integration)
