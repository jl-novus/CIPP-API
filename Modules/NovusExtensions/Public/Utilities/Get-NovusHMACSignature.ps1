# NOVUS CUSTOM: Generate HMAC-SHA256 signature for webhook authentication

function Get-NovusHMACSignature {
    <#
    .SYNOPSIS
        Generates an HMAC-SHA256 signature for webhook payload authentication.

    .DESCRIPTION
        Creates a cryptographic signature using HMAC-SHA256 algorithm to verify webhook
        authenticity between CIPP and n8n. This prevents unauthorized webhook injection
        and tampering attacks.

    .PARAMETER Message
        The message/payload to sign. Typically JSON-serialized alert data.

    .PARAMETER Secret
        The shared secret key used for HMAC generation. Should be retrieved from
        Azure Key Vault using Get-ExtensionAPIKey.

    .EXAMPLE
        $signature = Get-NovusHMACSignature -Message $jsonPayload -Secret $webhookSecret
        # Returns Base64-encoded HMAC-SHA256 signature

    .NOTES
        Security: The secret should never be hardcoded or logged. Always retrieve from
        Azure Key Vault and use in memory only.

        Validation: n8n should generate the same signature from the received payload
        and compare it to the signature in the X-CIPP-Signature header.
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Secret
    )

    begin {
        Write-Verbose "Generating HMAC-SHA256 signature for message (length: $($Message.Length) bytes)"
    }

    process {
        try {
            # Create HMAC-SHA256 object
            $hmacsha = New-Object System.Security.Cryptography.HMACSHA256

            # Convert secret to byte array and set as key
            $hmacsha.Key = [Text.Encoding]::UTF8.GetBytes($Secret)

            # Compute hash of message
            $hash = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Message))

            # Convert hash to Base64 for transmission in HTTP headers
            $signature = [Convert]::ToBase64String($hash)

            Write-Verbose "HMAC signature generated successfully (length: $($signature.Length) chars)"

            return $signature

        } catch {
            Write-Error "Failed to generate HMAC signature: $_"
            throw
        } finally {
            # Dispose of HMAC object to clear sensitive data from memory
            if ($hmacsha) {
                $hmacsha.Dispose()
            }
        }
    }
}