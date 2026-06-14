function Get-SpectreEscapedTextSafe {
    <#
    .SYNOPSIS
        Escapes Spectre markup in a string, with a fallback when PwshSpectreConsole isn't loaded.

    .DESCRIPTION
        Centralizes the "escape this text before it flows into Spectre markup" step used across the
        install wizard's rendering helpers. When PwshSpectreConsole is available it defers to its
        Get-SpectreEscapedText; otherwise it falls back to doubling the only two markup-significant
        characters ('[' -> '[[', ']' -> ']]'), so brackets in user/theme values render literally
        either way. This keeps one source of truth for the fallback and prevents callers from
        drifting (one wizard site previously skipped the doubling).

    .PARAMETER Text
        The text to escape. Defaults to an empty string.

    .EXAMPLE
        Get-SpectreEscapedTextSafe -Text 'value [with] brackets'

        Returns 'value [[with]] brackets' (or the Get-SpectreEscapedText equivalent when Spectre is
        loaded).

    .NOTES
        Private helper for the install-wizard chrome (Format-PwshProfileHelpMarkup,
        Write-PwshProfilePromptAnswer, Invoke-PwshProfileWizard). Not a general renderer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Text = ''
    )

    if (Get-Command Get-SpectreEscapedText -ErrorAction SilentlyContinue) {
        Get-SpectreEscapedText -Text "$Text"
    }
    else {
        ("$Text" -replace '\[', '[[') -replace '\]', ']]'
    }
}
