# Novus Extensions Module

All Novus-specific PowerShell functions go here.

## Purpose
This module contains custom PowerShell functions and extensions specific to Novus Technology Integration Inc.

## Structure
- **Public/** - Exported functions (available to other modules)
- **Private/** - Internal helper functions (not exported)

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

## Merge Protection
This directory is configured in .gitattributes to use 'ours' merge strategy during upstream syncs.

