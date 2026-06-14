function Read-PwshProfileSettingChange {
    <#
    .SYNOPSIS
        Shows a step's current values, then asks whether to change them — returning the decision.

    .DESCRIPTION
        A render-and-return helper for the Install-PwshProfile wizard steps that prefer a "review, then
        opt in to editing" flow (Banner, Winget). It prints each supplied row as a current-value line
        and, for any row whose current value differs from its recommended value, appends a dim
        "(recommended: …)" note — so the user can see at a glance what is non-standard. It then asks a
        single confirm that defaults to No and returns the answer as a bool; the caller wraps its
        per-setting prompts in `if (Read-PwshProfileSettingChange …) { … }`.

        Centralizing the default-No here keeps both callers consistent. Guarded on the Spectre prompt
        cmdlets, so it degrades to $false (keep current values, no prompts) when they're unavailable —
        matching the wizard's degraded-mode fallback elsewhere.

    .PARAMETER Message
        The confirm question shown after the summary, e.g. 'Change these winget settings?'.

    .PARAMETER Row
        The settings to summarize. Each item is an object with Label, Value, and Recommended members
        (Value/Recommended are display strings). A row whose Value differs from Recommended is flagged.
        A row may carry an optional Color member set to $true to mark its Value/Recommended as color
        values — those are then rendered as a colored swatch (via Format-PwshProfileColorValue) instead
        of plain escaped text.

    .PARAMETER Accent
        Accent color for the row glyph and the confirm, as a Spectre color name or hex. Defaults to the
        module's signature purple (#c9aaff).

    .EXAMPLE
        $rows = @(
            [pscustomobject]@{ Label = 'Default scope'; Value = 'machine'; Recommended = 'user' }
            [pscustomobject]@{ Label = 'Progress bar';  Value = 'rainbow'; Recommended = 'rainbow' }
        )
        if (Read-PwshProfileSettingChange -Message 'Change these winget settings?' -Row $rows) {
            # …prompt for each setting…
        }

        Lists the two values (flagging 'Default scope' as differing from the recommended 'user'), then
        asks to change — defaulting to No.

    .NOTES
        Mirrors the render-and-return shape of Read-PwshProfileFeatureTree.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [object[]]$Row = @(),

        [Parameter()]
        [string]$Accent = '#c9aaff'
    )

    if (-not (Get-Command Read-SpectreConfirm -ErrorAction SilentlyContinue)) { return $false }

    # Escape a display value for markup; render an empty value as a plain "(none)" placeholder
    # (Get-SpectreEscapedTextSafe rejects empty input, and a blank value reads better named).
    $fmt = {
        param($v)
        if ([string]::IsNullOrEmpty("$v")) { return '(none)' }
        Get-SpectreEscapedTextSafe -Text "$v"
    }

    # Render a row's display value — a colored swatch when the row is flagged as a color, otherwise the
    # escaped value (or the "(none)" placeholder for an empty one).
    $render = {
        param($r, $v)
        if ($r.Color -and -not [string]::IsNullOrEmpty("$v")) { return Format-PwshProfileColorValue "$v" }
        & $fmt $v
    }

    if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) {
        foreach ($r in $Row) {
            $line = "  [$Accent]•[/] [bold]$($r.Label):[/] $(& $render $r $r.Value)"
            if ("$($r.Value)" -ne "$($r.Recommended)") {
                $line += " [grey](recommended: $(& $render $r $r.Recommended))[/]"
            }
            Write-SpectreHost $line
        }
    }

    [bool](Read-SpectreConfirm -Message $Message -Color $Accent -DefaultAnswer 'n')
}
