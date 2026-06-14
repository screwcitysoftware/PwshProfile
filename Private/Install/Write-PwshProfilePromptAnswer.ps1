function Write-PwshProfilePromptAnswer {
    <#
    .SYNOPSIS
        Echoes the chosen value of an install-wizard selection prompt as a compact confirmation line.

    .DESCRIPTION
        The PwshSpectreConsole text prompts (Read-SpectreText) leave a "question: answer" line on
        screen after you submit, but the selection prompts (Read-SpectreSelection) wrap Spectre's
        interactive SelectionPrompt, which CLEARS itself on submit — so the chosen Theme / alignment /
        font / step icon would otherwise vanish with no record. There is no persist toggle, so the
        Install-PwshProfile wizard calls this helper immediately after each selection to print a small
        confirmation line: an accent check mark followed by the value in soft grey ("  ✓ Center").

        The value is escaped (so it is safe even if it contains Spectre markup characters like '[' or
        ']') but NOT run through Format-PwshProfileHelpMarkup — it is a literal chosen value, so its
        backticks / asterisks must not be reinterpreted as highlighting tokens. Guarded on
        Write-SpectreHost, so it silently no-ops in the non-interactive / Spectre-unavailable path,
        matching the wizard's other rendering helpers.

    .PARAMETER Value
        The chosen value to echo (e.g. 'Center', 'ANSIShadow', a theme label, or a step-icon label).

    .PARAMETER Accent
        The accent color for the leading check mark, as a Spectre color name or hex value. Defaults to
        the module's signature purple (#c9aaff).

    .EXAMPLE
        $alignment = Read-SpectreSelection -Message 'Banner alignment' -Choices @('Left', 'Center', 'Right')
        Write-PwshProfilePromptAnswer $alignment

        Prints "  ✓ Center" beneath the (now-collapsed) selection menu.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Value,

        [Parameter()]
        [string]$Accent = '#c9aaff'
    )

    if (-not (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue)) { return }

    $safe = Get-SpectreEscapedTextSafe -Text "$Value"
    Write-SpectreHost "  [$Accent]✓[/] [grey]$safe[/]"
}
