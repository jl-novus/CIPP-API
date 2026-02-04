# NOVUS CUSTOM: PowerShell module loader for Novus custom extensions
# Date: 2026-01-23
# Purpose: Automatically imports all Public and Private functions

# Get public and private function definition files (recursively to include subdirectories)
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        Write-Verbose "Importing: $($import.FullName)"
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName

# Module initialization
Write-Verbose "NovusExtensions module loaded successfully."
Write-Verbose "Available functions: $($Public.BaseName -join ', ')"
