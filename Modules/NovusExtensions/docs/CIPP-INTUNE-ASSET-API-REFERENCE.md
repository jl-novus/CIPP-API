# CIPP/Intune Asset Management API Reference

**Created**: 2026-02-03
**Purpose**: Document available CIPP endpoints for asset management reporting
**Target Use Cases**: Client asset reports, compliance audits, inventory management

---

## Overview

CIPP provides access to Microsoft Intune device data via Graph API. This document catalogs available endpoints, data fields, and implementation patterns for building custom asset management reports.

---

## Available CIPP API Endpoints

### 1. Managed Devices (Intune)

**Endpoint**: `/api/ListDevices?TenantFilter={domain}`
**Source File**: `Modules/CIPPCore/Public/Entrypoints/HTTP Functions/Endpoint/Reports/Invoke-ListDevices.ps1`
**Graph API**: `https://graph.microsoft.com/beta/deviceManagement/managedDevices`

**Fields Available**:
| Field | Type | Description |
|-------|------|-------------|
| id | string | Intune device ID |
| deviceName | string | Device hostname |
| operatingSystem | string | OS type (Windows, iOS, Android, macOS) |
| osVersion | string | OS version number |
| complianceState | string | compliant, noncompliant, conflict, error, inGracePeriod |
| managedDeviceOwnerType | string | company, personal |
| enrolledDateTime | datetime | When device was enrolled |
| lastSyncDateTime | datetime | Last Intune check-in |
| serialNumber | string | Hardware serial number |
| model | string | Device model |
| manufacturer | string | Device manufacturer |
| userPrincipalName | string | Primary user |
| deviceRegistrationState | string | Registration status |
| managementAgent | string | mdm, easMdm, configManagerMdm |
| aadRegistered | boolean | Azure AD registered |
| azureADDeviceId | string | Azure AD device ID |
| deviceEnrollmentType | string | Enrollment method |
| deviceCategoryDisplayName | string | Assigned category |
| isEncrypted | boolean | BitLocker/FileVault status |
| isSupervised | boolean | Supervised mode (iOS) |
| jailBroken | string | Jailbreak detection |
| totalStorageSpaceInBytes | long | Total storage |
| freeStorageSpaceInBytes | long | Free storage |

---

### 2. Device Details (Extended)

**Endpoint**: `/api/ListDeviceDetails?TenantFilter={domain}&DeviceID={id}`
**Source File**: `Modules/CIPPCore/Public/Entrypoints/Invoke-ListDeviceDetails.ps1`

**Additional Fields** (via bulk Graph requests):
| Field | Type | Description |
|-------|------|-------------|
| DetectedApps | array | Installed applications (id, displayName, version) |
| CompliancePolicies | array | Policy states (id, displayName, UserPrincipalName, state) |
| DeviceGroups | array | Group memberships (id, displayName, description) |

**Query Options**:
- By DeviceID: `?DeviceID={intune-device-id}`
- By Serial: `?DeviceSerial={serial-number}`
- By Name: `?DeviceName={device-name}`

---

### 3. Azure AD Devices

**Cached Data**: `CIPPDBCache` - Type: `Devices`
**Source File**: `Modules/CIPPCore/Public/Set-CIPPDBCacheDevices.ps1`
**Graph API**: `https://graph.microsoft.com/beta/devices`

**Fields Available**:
| Field | Type | Description |
|-------|------|-------------|
| id | string | Azure AD device ID |
| displayName | string | Device display name |
| operatingSystem | string | OS type |
| operatingSystemVersion | string | OS version |
| trustType | string | AzureAd, ServerAd, Workplace |
| accountEnabled | boolean | Device enabled status |
| approximateLastSignInDateTime | datetime | Last sign-in |

---

### 4. Autopilot Devices

**Endpoint**: `/api/ListAPDevices?TenantFilter={domain}`
**Source File**: `Modules/CIPPCore/Public/Entrypoints/HTTP Functions/Endpoint/Autopilot/Invoke-ListAPDevices.ps1`
**Graph API**: `https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities`

**Fields Available**:
| Field | Type | Description |
|-------|------|-------------|
| id | string | Autopilot ID |
| serialNumber | string | Hardware serial |
| model | string | Device model |
| manufacturer | string | Manufacturer |
| groupTag | string | Autopilot group tag |
| purchaseOrderIdentifier | string | PO number |
| addressableUserName | string | Assigned user |
| userPrincipalName | string | User UPN |
| deploymentProfileAssignmentStatus | string | Profile status |
| enrollmentState | string | Enrollment status |

---

### 5. Device Compliance

**Endpoint**: Included in Device Details
**Cached Data**: Part of device queries
**Alert Function**: `Modules/CIPPCore/Public/Alerts/Get-CIPPAlertDeviceCompliance.ps1`

**Compliance States**:
- `compliant` - Meets all policies
- `noncompliant` - Fails one or more policies
- `conflict` - Conflicting policy settings
- `error` - Evaluation error
- `inGracePeriod` - Non-compliant but in grace period
- `configManager` - Managed by ConfigMgr

---

### 6. Encryption States

**Cached Data**: `CIPPDBCache` - Type: `ManagedDeviceEncryptionStates`
**Source File**: `Modules/CIPPCore/Public/Set-CIPPDBCacheManagedDeviceEncryptionStates.ps1`
**Graph API**: `https://graph.microsoft.com/beta/deviceManagement/managedDeviceEncryptionStates`

**Encryption Status Types**:
- BitLocker (Windows)
- FileVault (macOS)
- Device encryption status
- Recovery key availability

---

## Report Templates

### Template 1: Basic Asset Inventory

**Use Case**: Hardware inventory, basic asset tracking

| Column | Source Field | Notes |
|--------|--------------|-------|
| Device Name | deviceName | |
| Serial Number | serialNumber | |
| Model | model | |
| Manufacturer | manufacturer | |
| OS | operatingSystem | |
| OS Version | osVersion | |
| Primary User | userPrincipalName | |
| Enrolled Date | enrolledDateTime | Format as date |
| Last Sync | lastSyncDateTime | Format as date |

---

### Template 2: Compliance-Focused (SOC2)

**Use Case**: Compliance audits, security reviews

| Column | Source Field | Notes |
|--------|--------------|-------|
| Device Name | deviceName | |
| Serial Number | serialNumber | |
| Compliance State | complianceState | Flag non-compliant |
| Encryption Status | isEncrypted | Critical for SOC2 |
| Last Sync | lastSyncDateTime | Flag if >7 days |
| Owner Type | managedDeviceOwnerType | company vs personal |
| Compliance Policies | CompliancePolicies[] | From device details |

**SOC2 Relevant Checks**:
- All devices encrypted (CC6.1)
- No stale devices (>30 days no sync)
- Corporate ownership verified
- Compliance policies assigned

---

### Template 3: Full Asset Report

**Use Case**: Complete asset documentation

| Column | Source Field | Notes |
|--------|--------------|-------|
| All Basic Fields | (see Template 1) | |
| All Compliance Fields | (see Template 2) | |
| Installed Apps | DetectedApps[] | App inventory |
| Group Memberships | DeviceGroups[] | |
| Storage Total | totalStorageSpaceInBytes | Format as GB |
| Storage Free | freeStorageSpaceInBytes | Format as GB |
| Jailbreak Status | jailBroken | iOS only |
| Supervised | isSupervised | iOS only |

---

## Implementation Patterns

### Pattern 1: Direct API Call

```powershell
# Get all managed devices for a tenant
$devices = Invoke-RestMethod -Uri "$CIPPUrl/api/ListDevices?TenantFilter=$tenant" -Headers $authHeaders
```

### Pattern 2: Cached Data

```powershell
# Access cached device data (faster, refreshed daily)
$cachedDevices = Get-CIPPDbItem -TenantFilter $tenant -Type 'ManagedDevices'
```

### Pattern 3: n8n Workflow

```
Webhook Trigger (scheduled) → CIPP API Call → Data Transform → AI Analysis → Email/Export
```

---

## Client-Specific Notes

### Deccan International
- **Compliance**: SOC2
- **Focus**: Encryption status, compliance state, stale devices
- **Report Frequency**: Monthly recommended
- **Key Metrics**: % compliant, % encrypted, avg last sync age

### Arete Health
- **Compliance**: HIPAA, HITECH
- **Focus**: PHI access devices, encryption mandatory
- **Report Frequency**: Monthly + on-demand for audits
- **Key Metrics**: 100% encryption required, no personal devices

### IGOE Company
- **Compliance**: HIPAA
- **Focus**: Mixed environment (legacy + modern)
- **Report Frequency**: Monthly
- **Key Metrics**: Enrollment coverage, compliance rate

### CafeMoto & Plenum Plus
- **Compliance**: None
- **Focus**: Basic inventory, maintenance
- **Report Frequency**: Quarterly
- **Key Metrics**: Device count, age distribution

---

## API Rate Limits & Best Practices

1. **Batch Requests**: Use Graph batch API for multiple queries
2. **Caching**: Leverage CIPP's daily cache for large datasets
3. **Pagination**: Handle `@odata.nextLink` for large tenants
4. **Selective Fields**: Use `$select` to reduce payload size
5. **Delta Queries**: Consider for incremental updates

---

## Related Documentation

- [n8n AI Integration](../N8N_WORKFLOW_GUIDE.md)
- [Tenant Context Mapping](../Public/Enrichment/Get-NovusTenantContext.ps1)
- [Alert Enrichment](../Public/Enrichment/Get-NovusAlertEnrichment.ps1)
- [CIPP Official Docs](https://docs.cipp.app/)

---

**Document Version**: 1.0
**Last Updated**: 2026-02-03
**Maintainer**: Novus Technology Integration
