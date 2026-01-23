# n8n Workflow Import Instructions - QUICK START

**File**: `n8n-workflow-cipp-security-alert.json`
**Status**: Ready to import (5-minute setup)

---

## Step 1: Import the Workflow (2 minutes)

1. **Log into your n8n instance**: `https://n8n-nov-sb1-u65757.vm.elestio.app`

2. **Go to Workflows** (left sidebar)

3. **Click "Import from File"** (top-right dropdown)

4. **Select the file**:
   ```
   C:\Projects\novus-automation\novus-cipp-prd\CIPP-API\Modules\NovusExtensions\n8n-workflow-cipp-security-alert.json
   ```

5. **Click "Import"**

✅ **Result**: Workflow "CIPP Security Alert AI Analysis" created with all 9 nodes

---

## Step 2: Connect Credentials (3 minutes)

The workflow has **2 placeholders** you need to connect:

### A. Node 2: "Validate HMAC Signature"

1. **Click the node** in the canvas
2. **Scroll down** to "Credentials" section
3. **Click the dropdown**
4. **Select**: `CIPP Webhook Secret` (the credential you created earlier)
5. **Save**

### B. Node 5: "Claude AI Analysis"

1. **Click the node** in the canvas
2. **Click "Credentials"** dropdown (top of the settings panel)
3. **Select**: `Anthropic API Key` (or whatever you named it)
4. **Save**

---

## Step 3: Optional Configuration

### Teams Webhook URL (Node 8)

If you want Teams notifications now:

1. **Click** "Send Teams Alert" node
2. **Replace** `YOUR_TEAMS_WEBHOOK_URL_HERE` with your actual Teams webhook
3. **Save**

**Or skip for now** - you can add this in Week 3

---

## Step 4: Activate the Workflow

1. **Toggle the switch** in the top-right corner (should turn blue/green)
2. **Production webhook URL** is now live:
   ```
   https://n8n-nov-sb1-u65757.vm.elestio.app/webhook/cipp-security-alert
   ```

---

## Step 5: Test the Workflow

Run the test script from [N8N_WORKFLOW_GUIDE.md](N8N_WORKFLOW_GUIDE.md):

```powershell
# Test script is at line 572 of N8N_WORKFLOW_GUIDE.md
# Copy and run in PowerShell
```

**Expected Results**:
- ✅ Webhook received
- ✅ HMAC validation passed
- ✅ Event routed to "SecurityAlert" path
- ✅ Claude prompt built
- ✅ Claude AI analysis returned
- ✅ Decision routed based on confidence
- ✅ (Optional) Teams notification sent

---

## Troubleshooting

### Issue: "Credentials not found"

**Fix**: Make sure you created the credentials first:
- Go to: **Credentials** (left sidebar)
- Check for: `CIPP Webhook Secret` and `Anthropic API Key`
- If missing, create them using the guide

### Issue: "Workflow execution failed"

**Fix**:
1. Click on the failed node
2. Check the error message
3. Common fixes:
   - HMAC node: Check credential is connected
   - Claude node: Check API key is valid
   - Teams node: Check webhook URL is correct

---

## What This Workflow Does

```
1. Webhook Receiver → Receives POST from CIPP
2. HMAC Validation → Verifies signature (security)
3. Event Router → Routes by alert type (SecurityAlert/Drift/Compliance)
4. Build Prompt → Creates Claude AI prompt with tenant context
5. Claude AI Call → Sends to Anthropic API for analysis
6. Parse Response → Extracts AI decision JSON
7. Decision Router → Routes by confidence (Critical/Human Review/Archive)
8. Send Teams Alert → Notifies Teams channel
9. Prepare Archive → Prepares data for storage
```

---

## Next Steps (After Import)

1. ✅ Import workflow (you're doing this now)
2. ✅ Connect 2 credentials
3. ✅ Activate workflow
4. ✅ Test with PowerShell script
5. 🔜 Implement CIPP backend orchestrator (Week 2 remaining tasks)

---

**Total Time**: ~5 minutes to get workflow running
**Status**: Week 2 - 50% complete after this step
