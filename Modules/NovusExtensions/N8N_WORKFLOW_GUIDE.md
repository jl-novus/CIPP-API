# n8n Workflow Setup Guide - CIPP Security Alert AI Analysis

**Last Updated**: 2026-01-23
**Status**: Week 2 Implementation - IN PROGRESS (n8n workflow building)

---

## Quick Start Checklist

Before you begin:
- [ ] n8n credentials configured (CIPP Webhook Secret, Anthropic API Key)
- [ ] Have your Anthropic API key ready
- [ ] Know your n8n instance URL
- [ ] 30-45 minutes to complete

---

## Overview

This guide provides **detailed step-by-step instructions** for building the "CIPP Security Alert AI Analysis" workflow in n8n. This workflow receives security alerts from CIPP, validates them with HMAC signatures, analyzes them with Claude AI, and routes decisions.

**Total Nodes**: 9
**Estimated Time**: 30-45 minutes
**Difficulty**: Intermediate

---

## Workflow Structure

```
Webhook Receiver → HMAC Validation → Event Router → Build Claude Prompt →
Claude API Call → Parse AI Response → Decision Router → Notify/Archive
```

---

## Creating the Workflow

### Step 1: Create New Workflow

1. **Log into your n8n instance** on Elestio
2. Click **"New workflow"** button (top-right, looks like "+ New")
3. **Name the workflow**: Click "My workflow" at the top and rename to:
   ```
   CIPP Security Alert AI Analysis
   ```
4. **Save** (Ctrl+S or click floppy disk icon)

---

## Node 1: Webhook Receiver

### Adding the Node

1. **Click the big "+" button** in the center of the canvas
2. **Search for**: `webhook`
3. **Select**: `Webhook` (under "Trigger nodes")

### Configuring the Webhook

1. **Parameters Panel** (right side):
   - **HTTP Method**: Click dropdown → Select `POST`
   - **Path**: Type `cipp-security-alert`
   - **Authentication**: Select `None` (we'll use HMAC instead)
   - **Response**:
     - Response Mode: `When Last Node Finishes`
     - Response Data: `Last Node`

2. **Getting Your Webhook URL**:
   - Look for **"Test URL"** and **"Production URL"** in the node
   - **Copy the Production URL** (looks like: `https://your-n8n.elestio.app/webhook/cipp-security-alert`)
   - **Save this URL** - you'll need it for Azure Key Vault

3. **Activate the Workflow**:
   - **Toggle** the switch in top-right corner (should turn blue/green)
   - This makes the Production URL live

### Update Azure Key Vault with Webhook URL

✅ **COMPLETED** - Production webhook URL already configured in Key Vault:
- URL: `https://n8n-nov-sb1-u65757.vm.elestio.app/webhook/cipp-security-alert`
- Secret: `81eaa7f5-e1f8-4452-9cc1-f91e78d561f6`

**Node Status**: ✅ Node 1 Complete - Webhook is now listening

---

## Node 2: HMAC Signature Validation

### Adding the Node

1. **Click the "+" on the right side** of the Webhook node
2. **Search for**: `Code`
3. **Select**: `Code` node (it's the newer version, replaces Function node)

### Configuring the Code Node

1. **Rename the node**: Click "Code" at top → Type `Validate HMAC Signature`

2. **Mode Settings**:
   - **Mode**: `Run Once for All Items` (default)
   - **Language**: `JavaScript`

3. **Insert the Code**:

Click in the code editor and paste this:

```javascript
// Get webhook secret from n8n credentials
const webhookSecret = $credentials.cippWebhookSecret;

// Get the first (and only) item from the webhook
const item = $input.first();

// Get the raw body and signature from headers
const payload = JSON.stringify(item.json);
const receivedSignature = item.headers['x-cipp-signature'];
const timestamp = item.headers['x-cipp-timestamp'];

// Validate timestamp (reject requests older than 5 minutes)
const requestTime = new Date(timestamp);
const now = new Date();
const ageMinutes = (now - requestTime) / 1000 / 60;

if (ageMinutes > 5) {
  throw new Error(`Webhook timestamp too old: ${ageMinutes.toFixed(2)} minutes (max: 5)`);
}

// Calculate expected HMAC signature
const crypto = require('crypto');
const hmac = crypto.createHmac('sha256', webhookSecret);
hmac.update(payload);
const expectedSignature = hmac.digest('base64');

// Compare signatures
if (receivedSignature !== expectedSignature) {
  throw new Error('Invalid webhook signature - authentication failed');
}

// Signature valid - return the payload
return {
  json: {
    ...(item.json),
    validatedAt: new Date().toISOString(),
    webhookAge: ageMinutes
  }
};
```

### 🔑 Connecting Credentials (IMPORTANT)

This is where most people get stuck. Here's how to link the credential:

1. **Scroll down in the node settings panel** (right side)
2. **Look for** section labeled **"Credentials"** or **"Node Credentials"**
3. **Click the dropdown** (says "Select credential...")
4. **Select**: `CIPP Webhook Secret` (the credential you created earlier)
   - If you don't see it, click **"+ Add credential"** and select your existing one
5. **Variable name in code**: The credential is accessed as `$credentials.cippWebhookSecret`
   - The part after the dot (`cippWebhookSecret`) should match how you named it

### Error Handling

1. **Click "Settings" tab** (at the top of the node panel)
2. **Continue On Fail**: Turn **OFF** (we want to reject invalid webhooks)
3. **Retry On Fail**: Turn **OFF**

**Node Status**: ✅ Node 2 Complete - HMAC validation configured

---

## Node 3: Event Router (Switch)

### Adding the Node

1. **Click the "+" on the right side** of the HMAC validation node
2. **Search for**: `switch`
3. **Select**: `Switch` node

### Configuring the Switch

1. **Rename**: `Route by Event Type`

2. **Mode**: Select `Rules`

3. **Add Rules** (click "+ Add Routing Rule" for each):

**Rule 0** (SecurityAlert):
- Condition: `{{ $json.eventType }}` **equals** `SecurityAlert`
- Keep this rule

**Rule 1** (DriftDetected):
- Condition: `{{ $json.eventType }}` **equals** `DriftDetected`
- Keep this rule

**Rule 2** (ComplianceReport):
- Condition: `{{ $json.eventType }}` **equals** `ComplianceReport`
- Keep this rule

**Rule 3** (Fallback):
- Automatically added as fallback

4. **For Week 2**: We'll only connect **Output 0** (SecurityAlert) to the next node

**Node Status**: ✅ Node 3 Complete - Event routing configured

---

## Node 4: Build Claude Prompt

### Adding the Node

1. **Click the "+" on the bottom-right of Switch node** (on Output 0 - SecurityAlert path)
2. **Search for**: `code`
3. **Select**: `Code` node

### Configuring the Code Node

1. **Rename**: `Build AI Analysis Prompt`

2. **Mode**: `Run Once for All Items`

3. **Insert the Code**:

```javascript
const alertData = $input.item.json;

// Extract key information
const tenant = alertData.tenant;
const alert = alertData.alert;
const context = alertData.context || {};

// Build compliance requirements string
const complianceReqs = tenant.complianceRequirements?.join(', ') || 'None';

// Build system prompt
const systemPrompt = `You are a senior Microsoft 365 security analyst working for Novus Technology Integration, a managed service provider (MSP) specializing in healthcare and compliance-focused clients.

Your role is to analyze security alerts and provide actionable recommendations while considering:
- Compliance requirements (HIPAA, HITECH, SOC2)
- Client risk profiles
- Severity and urgency
- Automation potential

Respond ONLY with valid JSON in this exact format:
{
  "severity": "critical|high|medium|low",
  "riskScore": 0-100,
  "analysis": "detailed analysis of the alert",
  "complianceImpact": {
    "HIPAA": {
      "riskLevel": "critical|high|medium|low|none",
      "violatedControls": [{"control": "164.xxx", "description": "...", "impact": "..."}],
      "breachNotificationRequired": "yes|potentially|no",
      "immediateActions": ["action1", "action2"]
    }
  },
  "recommendedActions": [
    {
      "action": "description of action",
      "automatable": true|false,
      "urgency": "immediate|within_24h|routine",
      "cippdEndpoint": "/api/ExecSomeAction",
      "cippdPayload": {},
      "rationale": "why this action is needed"
    }
  ],
  "requiresHumanReview": true|false,
  "humanReviewReason": "explanation if true",
  "confidence": 0-100
}`;

// Build user prompt with alert details
const userPrompt = `## Tenant Information
- **Name**: ${tenant.name}
- **Domain**: ${tenant.defaultDomain}
- **Compliance**: ${complianceReqs}
- **Risk Profile**: ${tenant.riskProfile}

## Alert Details
- **Type**: ${alert.type}
- **Severity**: ${alert.severity}
- **Title**: ${alert.title}

${alert.description ? `**Description**: ${alert.description}` : ''}

${alert.affectedResources ? `**Affected Resources**: ${JSON.stringify(alert.affectedResources, null, 2)}` : ''}

## Context
${context.secureScore ? `**Secure Score**: ${context.secureScore.current}/${context.secureScore.max} (${context.secureScore.percentage}%)` : ''}

${context.tenantHistory ? `**Similar Alerts (7 days)**: ${context.tenantHistory.similarAlertsLast7Days}` : ''}

${context.tenantHistory ? `**Similar Alerts (30 days)**: ${context.tenantHistory.similarAlertsLast30Days}` : ''}

${context.relatedAlerts?.length > 0 ? `**Related Recent Alerts**: ${context.relatedAlerts.length} found` : ''}

## Task
Analyze this security alert and provide recommendations. Consider the compliance requirements and provide specific, actionable guidance.`;

// Return structured payload for Claude API
return {
  json: {
    model: 'claude-sonnet-4-5-20250929',
    max_tokens: 4096,
    temperature: 0.3,
    system: systemPrompt,
    messages: [
      {
        role: 'user',
        content: userPrompt
      }
    ],
    // Pass through original data for later nodes
    _originalAlert: alertData,
    _correlationId: alertData.metadata?.correlationId
  }
};
```

**Node Status**: ✅ Node 4 Complete - Prompt builder configured

---

## Node 5: Claude API Call (HTTP Request)

### Adding the Node

1. **Click the "+" on the right side** of Build Prompt node
2. **Search for**: `http request`
3. **Select**: `HTTP Request` node

### Configuring the HTTP Request

1. **Rename**: `Claude AI Analysis`

2. **Authentication**:
   - Click **"Authentication"** dropdown
   - Select **"Generic Credential Type"**
   - Select **"Header Auth"**
   - Click **credential dropdown** → Select **"Anthropic API Key"**
     - If not there: **Create New** → Name: `Anthropic API Key` → Type: `Header Auth` → Header Name: `x-api-key` → Value: Your Anthropic API key

3. **Request Method**: `POST`

4. **URL**: `https://api.anthropic.com/v1/messages`

5. **Send Headers**: Turn **ON**

6. **Headers** (click "+ Add Header" for each):
   - Name: `anthropic-version` | Value: `2023-06-01`
   - Name: `content-type` | Value: `application/json`

7. **Send Body**: Turn **ON**

8. **Body Content Type**: `JSON`

9. **JSON Body** (click "JSON" and paste this):

```json
{
  "model": "={{ $json.model }}",
  "max_tokens": "={{ $json.max_tokens }}",
  "temperature": "={{ $json.temperature }}",
  "system": "={{ $json.system }}",
  "messages": "={{ $json.messages }}"
}
```

**Node Status**: ✅ Node 5 Complete - Claude API call configured

---

## Node 6: Parse Claude Response

### Adding the Node

1. **Click the "+" on the right side** of Claude API node
2. **Search for**: `code`
3. **Select**: `Code` node

### Configuring the Code Node

1. **Rename**: `Parse AI Decision`

2. **Insert the Code**:

```javascript
const claudeResponse = $input.item.json;
const originalAlert = $input.first().json._originalAlert;
const correlationId = $input.first().json._correlationId;

// Extract the AI response text from Claude's response format
const aiResponseText = claudeResponse.content[0].text;

// Parse the JSON response from Claude
let aiDecision;
try {
  aiDecision = JSON.parse(aiResponseText);
} catch (error) {
  // If JSON parsing fails, create a fallback structure
  aiDecision = {
    severity: 'high',
    riskScore: 75,
    analysis: aiResponseText,
    recommendedActions: [],
    requiresHumanReview: true,
    humanReviewReason: 'Failed to parse AI response as JSON',
    confidence: 50
  };
}

// Merge AI decision with original alert data
return {
  json: {
    correlationId: correlationId,
    timestamp: new Date().toISOString(),
    tenant: originalAlert.tenant,
    alert: originalAlert.alert,
    context: originalAlert.context,
    aiDecision: aiDecision,
    claudeMetadata: {
      model: claudeResponse.model,
      usage: claudeResponse.usage,
      stopReason: claudeResponse.stop_reason
    }
  }
};
```

**Node Status**: ✅ Node 6 Complete - Response parser configured

---

## Node 7: Decision Router (Switch)

### Adding the Node

1. **Click the "+" on the right side** of Parse AI node
2. **Search for**: `switch`
3. **Select**: `Switch` node

### Configuring the Switch

1. **Rename**: `Route by AI Decision`

2. **Mode**: `Rules`

3. **Add Rules**:

**Rule 0** (Critical Alerts):
- **Conditions** (click "+ Add Condition" twice):
  - `{{ $json.aiDecision.severity }}` **equals** `critical`
  - **AND**
  - `{{ $json.aiDecision.confidence }}` **>=** `90`

**Rule 1** (Human Review):
- `{{ $json.aiDecision.requiresHumanReview }}` **equals** `true`

**Rule 2** (Auto-Remediate - Future):
- **Conditions**:
  - `{{ $json.aiDecision.confidence }}` **>=** `85`
  - **AND**
  - `{{ $json.aiDecision.recommendedActions.length }}` **>** `0`

**Rule 3** (Fallback):
- Automatic

**For Week 2**: Connect Output 0 and Output 3 to notifications

**Node Status**: ✅ Node 7 Complete - Decision routing configured

---

## Node 8: Microsoft Teams Notification

### Adding the Node

1. **Click the "+" on Output 0** of Decision Router
2. **Search for**: `http request`
3. **Select**: `HTTP Request` node

### Configuring Teams Webhook

1. **Rename**: `Send Teams Alert`

2. **Method**: `POST`

3. **URL**: Your Teams webhook URL
   - Get from Teams: Channel → ⋯ → Connectors → Incoming Webhook

4. **Body Content Type**: `JSON`

5. **JSON Body** (simplified for Week 2):

```json
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "summary": "={{ $json.alert.title }}",
  "themeColor": "FF0000",
  "title": "🚨 CIPP Security Alert",
  "sections": [
    {
      "activityTitle": "={{ $json.tenant.name }}",
      "activitySubtitle": "={{ $json.alert.title }}",
      "text": "**Severity:** ={{ $json.aiDecision.severity }}\n\n**Analysis:** ={{ $json.aiDecision.analysis }}"
    }
  ]
}
```

**Node Status**: ✅ Node 8 Complete - Teams notification configured

---

## Node 9: Archive to Storage

### Adding the Node

1. **Click the "+" on Output 3** of Decision Router (fallback)
2. **Search for**: `code`
3. **Select**: `Code` node

### Configuring the Code Node

1. **Rename**: `Prepare Archive Data`

2. **Insert the Code**:

```javascript
// Prepare comprehensive archive record
const archiveRecord = {
  correlationId: $json.correlationId,
  timestamp: $json.timestamp,
  tenant: $json.tenant,
  alert: $json.alert,
  context: $json.context,
  aiDecision: $json.aiDecision,
  claudeMetadata: $json.claudeMetadata
};

// For Week 2, we'll just log this
// In Week 3, connect to Azure Blob Storage node
return {
  json: {
    archiveRecord: archiveRecord,
    fileName: `cipp-ai-decision-${archiveRecord.correlationId}.json`
  }
};
```

**Node Status**: ✅ Node 9 Complete - Archive prepared

---

## Testing the Workflow

### Before Testing

1. **Save the workflow** (Ctrl+S)
2. **Activate the workflow** (toggle in top-right)
3. **Copy your Production Webhook URL**

### Test 1: Basic Webhook with HMAC

Open PowerShell and run this test script:

```powershell
# Configuration
$webhookUrl = "https://n8n-nov-sb1-u65757.vm.elestio.app/webhook/cipp-security-alert"
$webhookSecret = "81eaa7f5-e1f8-4452-9cc1-f91e78d561f6"

# Build test payload
$testPayload = @{
    eventType = "SecurityAlert"
    eventSubType = "TestAlert"
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    source = "CIPP-Test"
    version = "1.0"
    tenant = @{
        id = "test-tenant-id"
        name = "Test Client"
        defaultDomain = "testclient.onmicrosoft.com"
        complianceRequirements = @("HIPAA")
        riskProfile = "high"
    }
    alert = @{
        id = "test-alert-123"
        type = "TestSecurityAlert"
        severity = "high"
        title = "Test Security Alert for n8n Validation"
        description = "Testing HMAC authentication and Claude AI analysis"
    }
    context = @{
        secureScore = @{
            current = 245
            max = 340
            percentage = 72.06
        }
    }
    metadata = @{
        cippdUrl = "https://cipp.novustek.io"
        correlationId = "test-" + [guid]::NewGuid().ToString()
    }
} | ConvertTo-Json -Depth 10

# Generate HMAC signature
$hmacsha = New-Object System.Security.Cryptography.HMACSHA256
$hmacsha.Key = [Text.Encoding]::UTF8.GetBytes($webhookSecret)
$hash = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($testPayload))
$signature = [Convert]::ToBase64String($hash)

# Send test webhook
$headers = @{
    'Content-Type' = 'application/json'
    'X-CIPP-Signature' = $signature
    'X-CIPP-Timestamp' = (Get-Date).ToUniversalTime().ToString('o')
    'X-CIPP-Event-Type' = 'SecurityAlert'
}

Write-Host "`n🧪 Testing n8n workflow..." -ForegroundColor Cyan
Write-Host "URL: $webhookUrl`n" -ForegroundColor Gray

try {
    $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $testPayload -Headers $headers
    Write-Host "✅ Test webhook sent successfully!" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json -Depth 5)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Test webhook failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
```

### Expected Results

1. **n8n Execution History** (click "Executions" in left sidebar):
   - Should show green checkmark ✓ for successful execution
   - Click on execution to see data flow through each node

2. **HMAC Validation**:
   - Node should show green (no errors)
   - Check output: should have `validatedAt` timestamp

3. **Claude AI Response**:
   - Check output from Claude API node
   - Should have JSON response with analysis

4. **Teams Notification** (if configured):
   - Check Teams channel for alert card

### Test 2: Invalid Signature (Security Test)

```powershell
# Test with wrong signature - SHOULD BE REJECTED
$headers['X-CIPP-Signature'] = 'ThisIsAnInvalidSignature=='

Write-Host "`n🔒 Testing security (invalid signature)..." -ForegroundColor Yellow

try {
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $testPayload -Headers $headers
    Write-Host "❌ SECURITY ISSUE: Invalid signature was accepted!" -ForegroundColor Red
} catch {
    Write-Host "✅ Invalid signature correctly rejected" -ForegroundColor Green
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Gray
}
```

---

## Troubleshooting Guide

### Issue: "Cannot read property 'cippWebhookSecret' of undefined"

**Cause**: Credential not attached to Code node

**Fix**:
1. Click the Code node (HMAC validation)
2. Scroll down to **"Credentials"** section
3. Select your **"CIPP Webhook Secret"** credential
4. Save and retry

### Issue: "Invalid webhook signature"

**Cause**: Secrets don't match

**Fix**:
```powershell
# Verify secrets match
az keyvault secret show --vault-name cippdxfje --name "N8N-Webhook-Secret"
# Compare with n8n credential value
```

### Issue: "Webhook timestamp too old"

**Cause**: Clock skew between systems

**Fix**:
- Check system clocks are synchronized (within 5 minutes)
- Test with: `Get-Date` in PowerShell and check n8n server time

### Issue: Claude API 401 Unauthorized

**Cause**: Invalid API key

**Fix**:
1. Go to n8n **Credentials**
2. Find **"Anthropic API Key"**
3. Verify the key starts with `sk-ant-api03-`
4. Test the key at https://console.anthropic.com

### Issue: Claude API 429 Rate Limit

**Cause**: Too many requests

**Fix**:
- Check your Anthropic tier limits
- Add delay between requests
- Consider upgrading API tier

### Viewing Execution Details

1. **Open Executions** (left sidebar)
2. **Click on any execution**
3. **View each node**:
   - Click node name to see input/output data
   - Check for red error indicators
   - Review execution time

---

## Week 2 Completion Checklist

- [ ] All 9 nodes created and connected
- [ ] Webhook URL copied to Azure Key Vault
- [ ] Credentials properly linked to nodes
- [ ] Test webhook sent successfully (valid signature)
- [ ] Security test passed (invalid signature rejected)
- [ ] Claude AI responded with analysis
- [ ] Workflow saved and activated
- [ ] Document webhook URL for CIPP backend integration

---

## Next Steps (Week 3)

1. **CIPP Backend Integration**:
   - Implement `Start-NovusAIAlertOrchestrator.ps1`
   - Implement `Invoke-NovusAIAlertProcessor.ps1`
   - Add timer to `CIPPTimers.json`

2. **Enhanced n8n Features**:
   - Auto-remediation workflow
   - Human approval with Teams cards
   - Azure Blob Storage archival

---

## Reference Resources

**Official Documentation**:
- [n8n Credentials Setup](https://docs.n8n.io/credentials/add-edit-credentials/)
- [n8n HTTP Request Node](https://docs.n8n.io/integrations/builtin/credentials/httprequest/)
- [Anthropic API Docs](https://docs.anthropic.com/)
- [HMAC Webhook Validation in n8n](https://n8n.io/workflows/3439-validate-seatable-webhooks-with-hmac-sha256-authentication/)

**Community Templates**:
- [n8n HMAC Validation Workflow](https://n8n.io/workflows/3439-validate-seatable-webhooks-with-hmac-sha256-authentication/)
- [Anthropic Claude Integration Examples](https://n8n.io/integrations/claude/)

**Troubleshooting**:
- [n8n Community Forums](https://community.n8n.io/)
- [Webhook Validation Issues](https://community.n8n.io/t/webhook-hmac-hash-cannot-be-verified/46100)

---

**Guide Version**: 2.0 (Enhanced)
**Last Updated**: 2026-01-22
**Next Review**: After Week 2 completion
