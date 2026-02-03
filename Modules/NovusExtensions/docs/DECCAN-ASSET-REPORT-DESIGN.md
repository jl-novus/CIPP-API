# Deccan Asset Management Report - Design Document

**Date:** 2026-02-03
**Author:** JLucky (CIO/CTO) with Claude Opus 4.5
**Status:** DRAFT - Pending Approval
**Scope:** NEW FEATURE

---

## Executive Summary

Implement an automated asset management reporting system for Deccan International that:
1. Pulls device inventory from CIPP/Intune on a schedule
2. Analyzes data with Claude AI for insights and recommendations
3. Delivers formatted report via email
4. Supports SOC2 compliance requirements

This leverages existing n8n infrastructure (Week 2 complete) and extends it with a new "Asset Report Agent" workflow.

---

## Problem Statement

Deccan International needs regular asset management reports for:
- SOC2 compliance audits (device inventory, encryption status)
- IT operations planning (device health, stale devices)
- Management visibility (asset counts, compliance metrics)

Currently, this requires manual CIPP queries and Excel manipulation.

---

## Proposed Solution

Create an n8n workflow that:
1. **Scheduled Trigger**: Runs weekly (configurable)
2. **CIPP Data Pull**: Fetches Intune managed devices
3. **Data Transform**: Formats into report structure
4. **AI Analysis**: Claude reviews data and generates insights
5. **Email Delivery**: Sends formatted report with AI commentary

---

## Impact Analysis

### System Impact
| Question | Answer |
|----------|--------|
| Systems affected | CIPP, n8n, Email (SMTP/Graph) |
| Breaking changes | None - new feature |
| Integration points | CIPP API, Anthropic API, SMTP |
| Deployment impact | n8n workflow update only |

### User Impact
| Question | Answer |
|----------|--------|
| Who uses this | JLucky (review), Deccan IT (consumption) |
| Behavior change | New automated report (currently manual) |
| Training required | None - email delivery |
| Rollout strategy | Enable for JLucky first, then Deccan |

### Cost & Effort
| Phase | Effort | Resources |
|-------|--------|-----------|
| Design | 2 hours | Complete (this doc) |
| Implementation | 4 hours | n8n workflow, PowerShell function |
| Testing | 2 hours | Test runs, email validation |
| Deployment | 1 hour | Activate workflow, configure schedule |

**API Cost Estimate**:
- Claude AI: ~$0.05/report (1000 input + 500 output tokens)
- Monthly (4 reports): ~$0.20
- Annual: ~$2.40

---

## Technical Design

### Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  n8n Workflow: "Deccan Asset Report"                                  │
│                                                                       │
│  ┌─────────────┐   ┌──────────────┐   ┌────────────────┐             │
│  │  Schedule   │   │  CIPP API    │   │  Transform     │             │
│  │  Trigger    ├──►│  Get Devices ├──►│  to Report     │             │
│  │  (Weekly)   │   │              │   │  Format        │             │
│  └─────────────┘   └──────────────┘   └───────┬────────┘             │
│                                               │                       │
│                                               ▼                       │
│  ┌─────────────┐   ┌──────────────┐   ┌────────────────┐             │
│  │  Send       │   │  Format      │   │  Claude AI     │             │
│  │  Email      │◄──┤  HTML        │◄──┤  Analysis      │             │
│  │             │   │  Report      │   │  & Insights    │             │
│  └─────────────┘   └──────────────┘   └────────────────┘             │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

### Workflow Nodes

| Node | Type | Purpose |
|------|------|---------|
| 1. Schedule Trigger | Cron | Weekly on Monday 8:00 AM |
| 2. Get CIPP Token | HTTP Request | Authenticate to CIPP |
| 3. List Devices | HTTP Request | Call CIPP ListDevices API |
| 4. Transform Data | Code | Shape data for report |
| 5. Build AI Prompt | Code | Create analysis prompt |
| 6. Claude Analysis | HTTP Request | Get AI insights |
| 7. Parse AI Response | Code | Extract insights |
| 8. Format HTML | Code | Build email HTML |
| 9. Send Email | SMTP/Graph | Deliver report |

### Data Flow

**Input** (from CIPP):
```json
{
  "devices": [
    {
      "deviceName": "DESKTOP-ABC123",
      "serialNumber": "SN12345",
      "model": "ThinkPad T14",
      "operatingSystem": "Windows",
      "osVersion": "10.0.19045",
      "complianceState": "compliant",
      "isEncrypted": true,
      "lastSyncDateTime": "2026-02-01T10:30:00Z",
      "userPrincipalName": "john@deccan.com"
    }
  ]
}
```

**AI Analysis Prompt**:
```
You are an IT asset analyst for Deccan International, a SOC2-compliant organization.

Analyze this device inventory and provide:
1. Executive Summary (2-3 sentences)
2. SOC2 Compliance Status
   - Encryption coverage %
   - Stale device count (>7 days no sync)
   - Non-compliant device count
3. Key Findings (bullet points)
4. Recommendations (prioritized list)

Focus on security and compliance implications.
```

**Output** (Email):
```
Subject: Deccan Weekly Asset Report - Feb 3, 2026

[HTML Report with:]
- Summary Statistics Table
- AI Executive Summary
- Device Inventory Table
- Compliance Metrics
- AI Recommendations
- Raw Data Attachment (CSV)
```

### Report Structure

#### Section 1: Summary Metrics
| Metric | Value |
|--------|-------|
| Total Devices | {count} |
| Compliant | {count} ({%}) |
| Non-Compliant | {count} ({%}) |
| Encrypted | {count} ({%}) |
| Stale (>7 days) | {count} |

#### Section 2: AI Analysis
- Executive Summary (2-3 sentences)
- Key Findings (bullets)
- Recommendations (numbered)

#### Section 3: Device Inventory
| Device | Serial | Model | OS | User | Compliance | Encrypted | Last Sync |
|--------|--------|-------|-----|------|------------|-----------|-----------|
| ... | ... | ... | ... | ... | ... | ... | ... |

#### Section 4: Attachments
- Full device list as CSV

---

## Implementation Plan

### Phase 1: CIPP API Function (Optional Enhancement)
- [ ] Create `Get-NovusDeviceInventory.ps1` wrapper function
- [ ] Add tenant-specific filtering
- [ ] Include compliance summary calculation

### Phase 2: n8n Workflow
- [ ] Create new workflow "Deccan Asset Report"
- [ ] Node 1: Schedule Trigger (Cron: `0 8 * * 1`)
- [ ] Node 2-3: CIPP API authentication and device fetch
- [ ] Node 4-5: Data transformation and AI prompt building
- [ ] Node 6-7: Claude API call and response parsing
- [ ] Node 8-9: HTML formatting and email delivery

### Phase 3: Testing
- [ ] Test with Deccan tenant data
- [ ] Validate AI analysis quality
- [ ] Confirm email delivery to JLucky
- [ ] Verify CSV attachment

### Phase 4: Production Enable
- [ ] Activate weekly schedule
- [ ] Configure recipient list (JLucky first, then expand)
- [ ] Document in IMPLEMENTATION_STATUS.md

---

## Execution Resources

### Agent Assignments (n8n nodes)
| Phase | Agent | Task |
|-------|-------|------|
| Data Pull | HTTP Request node | CIPP API call |
| Transform | Code node | Data shaping |
| AI Analysis | HTTP Request node | Claude API |
| Delivery | SMTP node | Email send |

### Human Decisions Required
| Decision | Owner | When Needed |
|----------|-------|-------------|
| Approve design | JLucky | Before implementation |
| Email recipients | JLucky | Before production |
| Schedule timing | JLucky | Before production |

---

## Success Criteria

- [ ] Report generates automatically on schedule
- [ ] Device data is accurate and complete
- [ ] AI provides actionable insights
- [ ] Email delivers successfully
- [ ] SOC2 metrics are clearly visible
- [ ] Report takes <2 minutes to generate

---

## Rollback Plan

1. Disable schedule trigger in n8n
2. Previous reports remain in email history
3. No data is modified - read-only operation
4. Can revert to manual CIPP exports

---

## Verification Gates

### Pre-Implementation
- [ ] Design approved
- [ ] CIPP API access confirmed
- [ ] Email delivery method decided (SMTP vs Graph)
- [ ] AI prompt reviewed

### Pre-Deployment
- [ ] Test run successful
- [ ] Email format acceptable
- [ ] AI insights are useful
- [ ] No PII in logs

### Post-Deployment
- [ ] First automated report delivered
- [ ] JLucky confirms quality
- [ ] Monitoring for failures enabled

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| CIPP API unavailable | Low | Medium | Retry logic, alert on failure |
| Claude API rate limit | Low | Low | Single report, low volume |
| Email delivery failure | Low | Medium | Use reliable SMTP/Graph, retry |
| Stale cached data | Medium | Low | Pull fresh data each run |
| AI hallucination | Medium | Low | Review first few reports manually |

---

## Future Enhancements

1. **Dashboard View**: Add to CIPP frontend
2. **Multiple Clients**: Parameterize for other tenants
3. **Trend Analysis**: Compare with previous reports
4. **Alert Integration**: Flag critical findings to Teams
5. **SuperOps Correlation**: Merge with RMM asset data

---

## Configuration

### Environment Variables / Secrets Needed
| Secret | Storage | Purpose |
|--------|---------|---------|
| CIPP API URL | n8n Credential | CIPP endpoint |
| CIPP Auth | n8n Credential | API authentication |
| Anthropic API Key | n8n Credential | Already configured |
| SMTP Settings | n8n Credential | Email delivery |

### Schedule Options
| Frequency | Cron | Use Case |
|-----------|------|----------|
| Weekly (Mon 8am) | `0 8 * * 1` | Default - SOC2 review |
| Bi-weekly | `0 8 1,15 * *` | Reduced frequency |
| Monthly | `0 8 1 * *` | Quarterly reports |

---

## Approval

- [ ] Technical review complete (JLucky)
- [ ] Impact accepted
- [ ] Resources allocated
- [ ] Ready for `/execute`

---

*This design document is ready for execution. When approved, implementation can begin.*

---

**Document Version**: 1.0
**Created**: 2026-02-03
**Status**: DRAFT - Pending Approval
